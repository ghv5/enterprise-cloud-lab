#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

echo "[0/7] wait for rate-limit window reset"
for _ in $(seq 1 70); do
  code="$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/api/posts || true)"
  if [[ "${code}" == "200" ]]; then
    break
  fi
  sleep 1
done

if [[ "${code:-}" != "200" ]]; then
  echo "gateway did not return 200 within 70 seconds; current code=${code:-unknown}" >&2
  exit 1
fi

echo "[1/7] business api"
curl -fsS http://127.0.0.1:8080/api/posts >/tmp/enterprise-cloud-lab-posts.json
jq -e '.success == true and (.meta.version | length > 0)' /tmp/enterprise-cloud-lab-posts.json >/dev/null

echo "[2/7] rate limit"
RATE_RESULT="$(
  for i in $(seq 1 40); do
    curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080/api/posts
  done | sort | uniq -c
)"
echo "${RATE_RESULT}"
echo "${RATE_RESULT}" | rg '429' >/dev/null

echo "[3/7] rollout"
kubectl get rollout blog-api-blog-api -n demo >/dev/null

echo "[4/7] prometheus targets"
PROM_TARGETS="$(
  curl -fsS "http://prometheus.localhost:8080/api/v1/targets" \
    | jq '.data.activeTargets[] | {job: .labels.job, health: .health, scrapeUrl: .scrapeUrl}
      | select((.job|test("blog-api|apisix-prometheus-metrics|alloy")) or (.scrapeUrl|test("blog-api|apisix")))'
)"
echo "${PROM_TARGETS}"
echo "${PROM_TARGETS}" | rg 'apisix-prometheus-metrics' >/dev/null
echo "${PROM_TARGETS}" | rg 'blog-api-blog-api' >/dev/null

echo "[5/7] prometheus app metric"
curl -fsS "http://prometheus.localhost:8080/api/v1/query?query=http_server_requests_seconds_count%7Bapplication%3D%22blog-api%22%2Curi%3D%22%2Fapi%2Fposts%22%7D" \
  | jq -e '.data.result | length > 0' >/dev/null

echo "[6/7] loki logs"
curl -fsS "http://loki.localhost:8080/loki/api/v1/query_range?query=%7Bnamespace%3D%22demo%22,app%3D%22blog-api%22%7D&limit=5" \
  | jq -e '.data.result | length > 0' >/dev/null

echo "[7/7] skywalking traces"
START="$(date '+%Y-%m-%d %H00')"
END="$(date '+%Y-%m-%d %H59')"
SERVICE_ID="$(
  curl -fsS "http://skywalking.localhost:8080/graphql" \
    -H 'Content-Type: application/json' \
    -d "{\"query\":\"query { getAllServices(duration: {start: \\\"${START}\\\", end: \\\"${END}\\\", step: MINUTE}) { id name } }\"}" \
    | jq -r '.data.getAllServices[] | select(.name=="blog-api|demo|") | .id'
)"

if [[ -z "${SERVICE_ID}" ]]; then
  echo "skywalking service blog-api|demo| not found" >&2
  exit 1
fi

curl -fsS "http://skywalking.localhost:8080/graphql" \
  -H 'Content-Type: application/json' \
  -d "{\"query\":\"query { queryBasicTraces(condition: { serviceId: \\\"${SERVICE_ID}\\\", queryDuration: {start: \\\"${START}\\\", end: \\\"${END}\\\", step: MINUTE}, traceState: ALL, queryOrder: BY_START_TIME, paging: { pageNum: 1, pageSize: 100 } }) { traces { endpointNames } } }\"}" \
  | jq -e '.data.queryBasicTraces.traces | map(.endpointNames | join(",")) | any(. == "GET:/api/posts")' >/dev/null

echo "self-test passed"
