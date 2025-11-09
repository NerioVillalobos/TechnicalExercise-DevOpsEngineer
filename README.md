# TechnicalExercise-DevOpsEngineer
Design and implement a minimal yet complete workflow for deploying a microservice


## Como se realizo la solucion

Para realizar el microservicio se decidio escoger una solucion basada en Java Spring Boot, debido a que es el standard para implementaciones empresariales y por la robustes en automatizacion del despliegue, fiabilidad, escalabilidad, monitoreo y seguridad.

Se decidio utilizaran las siguientes dependencias:
1. Spring Boot Starter Web
2. Spring Boot Starter Test
3. Spring Boot Actuator

Con estas dependencia vamos a poder lograr implementar lo requerido la respuesta de:
1. implementacion de endpoint `/health`
2. ejecucion de pruebas unitarias
3. posibilidad de capturar las metricas `GET /actuator/metrics` y `GET /actuator/health`
4. se crea archivo logback para que emita un json por defecto y se pueda capturar con ELK o CloudWatch
5. se le crea una capa de metricas `/actuator/prometheus` esto permite integrarlo con Prometheus o Grafana

## Especificaciones de la APP

Se configura para que solo responda un `OK` al visitar /health sobre el puerto 8080 del localhost
```Bash
public class HealthController {

    @GetMapping("/health")
    public String health() {
        return "OK";
    }
}
```

Se configura tambien para que devuelva un status para su monitoreo y una ruta que devuelven los valores requeridos para obtener mas informacion del microservicio

## Metodología y Automatización CI/CD

El modelo de ramas (branch model) se basa en un flujo Git estándar, manteniendo una estructura clara de versiones y responsabilidades:

- **master** : rama principal de producción.
- **sprints** : rama de seguimiento de desarrollo en equipo.
- **features** : ramas individuales para desarrollo de historias de usuario.
- **hotfix** : ramas dedicadas a correcciones urgentes en ambientes productivos.

![Branch Model](imagen/brach-model.png "Branch Model")

Fueron creados dos archivos YAML dentro del directorio de workflows de GitHub Actions que automatizan las validaciones y despliegues:

- **PushOn.yml** :  
  Se ejecuta automáticamente al realizar un `git push` hacia ramas `feature/*` o `hotfix/*`.  
  Este pipeline realiza compilación y ejecución de pruebas unitarias (`mvn clean verify`).  
  Si las pruebas pasan exitosamente, el push se completa; en caso contrario, el flujo se detiene marcando el error en GitHub.

## Dockerización
Se incluye un `Dockerfile` en la raíz del proyecto que construye una imagen a partir del JAR generado por Maven:

1. `mvn clean package`
2. `docker build -t simplemicroservice:local .`
3. `docker run -p 8080:8080 simplemicroservice:local`

Esto permite ejecutar el microservicio en un contenedor.

## Entorno de ejecución (Producción)
Se eligió **Kubernetes** como plataforma de ejecución porque:
- soporta múltiples microservicios Java como los descritos en el enunciado,
- permite health checks nativos usando `/actuator/health`,
- se integra fácilmente con CI/CD y despliegues declarativos,
- facilita observabilidad centralizada (Prometheus, ELK).


- **CompletePR.yml** :  
  Se ejecuta al crear un Pull Request hacia la rama `de sprint`.  
  Este pipeline realiza un proceso de integración completo que incluye:
  - **Checkout** del código.
  - **Compilación y pruebas unitarias** (`mvn clean package`).
  - **Construcción de la imagen Docker** (`docker build`).
  - **Aplicación de manifiestos Kubernetes** en un *namespace* de prueba (`kubectl apply`).

### Flujo general del pipeline

1. **Developer / Git**
   - El desarrollador realiza cambios en el proyecto.
   - Ejecuta `git push` hacia una rama `feature/...` o `hotfix/...`.

2. **GitHub Actions – PushOn.yml**
   - Se dispara el workflow ligero.
   - Ejecuta `./mvnw clean verify`.
   - Si pasa: el código se integra en el repositorio.
   - Si falla: el push queda bloqueado con un check rojo.

3. **Pull Request → `feature` y `hotfix`**
   - Se crea un Pull Request desde `feature/...` o `hotfix/...` hacia `main`.

4. **GitHub Actions – CompletePR.yml**
   - Se dispara el workflow completo.
   - Realiza compilación, test, construcción de la imagen Docker y (si está configurado) despliegue al ambiente de prueba.

5. **Kubernetes (ambiente de prueba)**
   - El `Deployment` se actualiza con la nueva imagen.
   - Se crea o actualiza el `Pod` que contiene el microservicio Spring Boot.
   - El `Service` interno de Kubernetes expone el pod dentro del cluster.
   - El `Ingress` permite el acceso HTTP externo al microservicio.
   - Prometheus y ELK recolectan métricas y logs estructurados para observabilidad.

Este flujo permite validar continuamente la calidad del código, mantener la trazabilidad entre ramas y asegurar la entrega automatizada hacia entornos controlados de prueba.

6. **Despliegues a ambientes altos**
  - Se realizan a partir de un JOB donde se selecciona el tag y version incorporado por un Pull Request en la rama `main`

  Ambos pipelines en conjunto (PushOn.yml y CompletePR.yml) aseguran que:
  - Los commits solo se integran si superan las pruebas.
  - Los Pull Requests generan builds reproducibles y verificables en Kubernetes.
  - La calidad y estabilidad del código se mantienen antes de llegar a producción.

### Publicación en registry (opcional)
El punto 4 del ejercicio solicita publicar la imagen en un registry. El workflow `CompletePR.yml` está preparado para incluir pero no se coloco para permitir la ejecución en un entorno de evaluación sin credenciales. simplemente se deben agregar las opciones en las secciones de `docker/login-action` y `docker push` y configurar el secret del registry.

## Observabilidad
- Logging estructurado mediante Logback (formato JSON) para centralización (ELK / CloudWatch).
- Métricas expuestas vía Spring Boot Actuator:
  - `/actuator/health`
  - `/actuator/metrics`
  - `/actuator/prometheus`
Esto permite integrarse con Prometheus y Grafana.


## Diagrama de la solucion

![Solution diagram](imagen/TechnicalExercise-Solution.png "Solution diagram")


## Gestión de vulnerabilidades

- **Dependencias de código**: usar `mvn versions:display-dependency-updates` y/o integración con GitHub Dependabot para detectar librerías vulnerables.
- **Imágenes de contenedor**: escanear la imagen generada con una herramienta como Trivy o Grype en la etapa de CI (paso opcional que se puede agregar en `CompletePR.yml`).
- **Capas del SO base**: mantener la imagen base actualizada (`eclipse-temurin:17-jre-alpine` o similar) y fijar versiones para evitar inconvenientes por versiones.
- **Manejo de Vulnerabilidades**: si se detecta una vulnerabilidad grave, se actualiza el código, se recompila la imagen y se vuelve a desplegar para asegurar que el servicio no quede expuesto.

## Decisiones técnicas clave
1. **Framework**: Spring Boot en lugar de Micronaut, por madurez y estándar enterprise, se puede trabajar con Micronaut en situaciones muy especificas donde se requiera mas vlocidad y mas eficiencia en los recursos.
2. **Contenedores**: Docker como formato de empaquetado para permitir despliegue en cualquier plataforma.
3. **Orquestador**: Kubernetes elegido por soporte de health checks, escalabilidad y observabilidad integrada.
4. **CI/CD**: GitHub Actions dividido en dos workflows (validación de push y pipeline completo de PR) para separar calidad de integración.
5. **Observabilidad**: uso de Actuator y logs JSON para integración con Prometheus / ELK.
