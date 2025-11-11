# Metrics Sample: Spring Boot with Embedded Tomcat

Spring Boot application with Actuator exposing Prometheus metrics across OpenJDK 11, 17, 21, and 23 on Red Hat UBI base images.

## Build & Deploy

### Local Build
```bash
cd metrics-sample-springboot

# Build all versions
podman build -f Dockerfile.openjdk11 -t quay.io/yourorg/metrics-springboot:openjdk11 .
podman build -f Dockerfile.openjdk17 -t quay.io/yourorg/metrics-springboot:openjdk17 .
podman build -f Dockerfile.openjdk21 -t quay.io/yourorg/metrics-springboot:openjdk21 .
podman build -f Dockerfile.openjdk23 -t quay.io/yourorg/metrics-springboot:openjdk23 .

# Push to registry
podman push quay.io/yourorg/metrics-springboot:openjdk11
podman push quay.io/yourorg/metrics-springboot:openjdk17
podman push quay.io/yourorg/metrics-springboot:openjdk21
podman push quay.io/yourorg/metrics-springboot:openjdk23
```

### OpenShift Deploy
```bash
# Update image references in k8s/*.yaml first
oc apply -f k8s/
```

## Test Locally
```bash
# Run with Maven
mvn clean package
java -jar target/metrics-sample-springboot-1.0.0.jar

# Access endpoints
curl http://localhost:8080/actuator/health
curl http://localhost:8080/actuator/prometheus
```

## Tuning Notes
- Embedded Tomcat max threads: 50 (configurable via `TOMCAT_MAX_THREADS` env var)
- Heap: 70% of container memory (768Mi limit → ~537Mi max heap)
- Initial heap: 50% for faster startup with large dependency graph
- Larger memory limit than Undertow due to Spring framework overhead
