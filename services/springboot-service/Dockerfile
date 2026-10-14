FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY target/springboot-service-1.0.0.jar app.jar
EXPOSE 8081
USER nobody
ENTRYPOINT ["java", "-jar", "app.jar"]
