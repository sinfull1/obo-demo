FROM openjdk:17-jdk-slim

WORKDIR /app

COPY target/api-service-1-0.0.1-SNAPSHOT.jar app.jar

EXPOSE 8083

CMD ["java", "-jar", "app.jar"]