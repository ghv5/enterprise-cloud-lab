FROM eclipse-temurin:17-jre

WORKDIR /app

ARG JAR_FILE
COPY ${JAR_FILE} app.jar

ENV JAVA_OPTS=""

EXPOSE 18080
EXPOSE 18081
EXPOSE 18082
EXPOSE 19090

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
