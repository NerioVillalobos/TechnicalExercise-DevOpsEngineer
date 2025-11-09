# Imagen base con Java 17
FROM eclipse-temurin:17-jre-alpine

# Directorio de trabajo dentro del contenedor
WORKDIR /app

COPY target/simplemicroservice-0.0.1-SNAPSHOT.jar app.jar

# Exponemos el puerto que usa Spring Boot
EXPOSE 8080

# Comando de arranque
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
