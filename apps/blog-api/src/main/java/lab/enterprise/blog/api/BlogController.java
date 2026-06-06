package lab.enterprise.blog.api;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class BlogController {

  private final String appVersion;
  private final Instant startedAt;
  private final List<PostResponse> posts;

  public BlogController(@Value("${app.version:dev}") String appVersion) {
    this.appVersion = appVersion;
    this.startedAt = Instant.now();
    this.posts = List.of(
        new PostResponse(
            "welcome",
            "Enterprise Delivery Lab",
            "A tiny Spring Boot API used to exercise CI, GitOps, canary release, and rollback."),
        new PostResponse(
            "observability",
            "Observable By Default",
            "Actuator and Micrometer make health, metrics, and tracing agent demos straightforward."));
  }

  @GetMapping("/api/posts")
  public ApiResponse<List<PostResponse>> posts() {
    return ApiResponse.success(posts, Map.of("version", appVersion));
  }

  @GetMapping("/api/info")
  public ApiResponse<Map<String, String>> info() {
    return ApiResponse.success(
        Map.of(
            "service", "blog-api",
            "version", appVersion,
            "startedAt", startedAt.toString()),
        Map.of());
  }
}
