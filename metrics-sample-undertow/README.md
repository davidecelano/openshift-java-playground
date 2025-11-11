# Metrics Sample: Undertow with Multi-Version OpenJDK

Lightweight HTTP service using Undertow, exposing Prometheus JVM metrics across OpenJDK 11, 17, 21, and 23 on Red Hat UBI base images.

## Build & Deploy

### Local Build
```bash
cd metrics-sample-undertow

# Build all versions
podman build -f Dockerfile.openjdk11 -t quay.io/yourorg/metrics-undertow:openjdk11 .
podman build -f Dockerfile.openjdk17 -t quay.io/yourorg/metrics-undertow:openjdk17 .
podman build -f Dockerfile.openjdk21 -t quay.io/yourorg/metrics-undertow:openjdk21 .
podman build -f Dockerfile.openjdk23 -t quay.io/yourorg/metrics-undertow:openjdk23 .

# Push to registry
podman push quay.io/yourorg/metrics-undertow:openjdk11
podman push quay.io/yourorg/metrics-undertow:openjdk17
podman push quay.io/yourorg/metrics-undertow:openjdk21
podman push quay.io/yourorg/metrics-undertow:openjdk23
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
java -jar target/metrics-sample-undertow-1.0.0.jar

# Access endpoints
curl http://localhost:8080/health
curl http://localhost:8080/metrics
```

## Tuning Notes
- IO threads = min(2, vCPUs)
- Worker threads = IO threads × 8
- Heap: 65% of container memory (512Mi limit → ~330Mi max heap)
- Initial heap: 50% to reduce early GC churn
