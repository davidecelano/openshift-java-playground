# Metrics Sample: Spring Boot with Embedded Tomcat

📚 **Documentation**: [Main README](../README.md) | [Quick Start](../QUICKSTART.md) | [Deployment](../DEPLOYMENT.md) | [Testing](../TESTING.md) | [Implementation](../IMPLEMENTATION.md)

---

Spring Boot application with Actuator exposing Prometheus metrics across OpenJDK 17, 21, and 23 on Red Hat UBI base images.

## About This Sample

Spring Boot represents the **industry-standard Java framework**, making it essential for:
- **Real-world comparison** against enterprise application behavior
- **Framework overhead analysis** (dependency injection, auto-configuration impact on startup/memory)
- **Actuator integration patterns** demonstrating production-ready health checks and metrics

This sample showcases Spring Boot's container-aware configuration (`InitialRAMPercentage` reduces bean initialization GC) and embedded Tomcat thread pool tuning via environment variables.

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

## Key Configuration

| Parameter | Value | Effect | Override Method |
|-----------|-------|--------|------------------|
| **Memory Limit** | 768Mi | Accommodates Spring framework + dependency graph | Edit `k8s/deployment-openjdk*.yaml` |
| **Max Heap** | 70% | `-XX:MaxRAMPercentage=70.0` → ~537Mi | Change in Dockerfile CMD |
| **Initial Heap** | 50% | `-XX:InitialRAMPercentage=50.0` → ~384Mi (reduces startup GC) | Change in Dockerfile CMD |
| **Tomcat Max Threads** | 50 | Configurable via `TOMCAT_MAX_THREADS` env var | Set in `deployment.yaml` env section |
| **Actuator Port** | 8080 | Same port as application | `application.properties` |
| **Metrics Endpoint** | `/actuator/prometheus` | Spring Boot Actuator standard path | Auto-configured |
| **Base Images** | UBI 9 OpenJDK | Java 17/21: `:1.21`, Java 23: uses Java 21 base | Dockerfile ARG or BuildConfig buildArgs |

**Spring Boot Specifics**:
- **Startup optimization**: Higher `InitialRAMPercentage` critical for Spring's bean initialization
- **Embedded Tomcat tuning**: `server.tomcat.max-threads` property or `TOMCAT_MAX_THREADS` env var
- **Auto-configuration**: JVM metrics registered automatically via Micrometer starter
- **Java 23 note**: Compiles to Java 21 target (`-Djava.version=21` in Dockerfile)

## Comparing with Other Runtimes

| Metric | Spring Boot | Undertow | Tomcat | WildFly |
|--------|-------------|----------|--------|----------|
| **Memory Limit** | 768Mi | 512Mi (smallest) | 768Mi | 1Gi (largest) |
| **Heap %** | 70% | 65% | 70% | 65% |
| **Startup Time** | ~8s | ~2s (fastest) | ~5s | ~15s |
| **JAR/WAR Size** | ~45MB (largest) | ~15MB | ~20MB (WAR) | ~30MB (WAR) |
| **Framework** | Full Spring ecosystem | Minimal (Undertow only) | Servlet API | Jakarta EE |
| **Metrics Path** | `/actuator/prometheus` | `/metrics` | `/metrics` | `/metrics` (port 9990) |
| **Use Case** | Enterprise apps, rapid dev | Microservices | Classic web apps | Full app server |

For detailed runtime comparison, see [Main README: Runtime Comparison](../README.md#sample-applications).

## Related Documentation

- **[Main README](../README.md)**: Project overview, architecture, all runtime samples
- **[Quick Start](../QUICKSTART.md)**: Deploy this sample in 10 minutes
- **[Deployment Guide](../DEPLOYMENT.md)**: Build strategies (local, OpenShift BuildConfig, GitHub Actions)
- **[Testing Guide](../TESTING.md)**: Validate builds, troubleshoot issues, performance testing
- **[Implementation Guide](../IMPLEMENTATION.md)**: Technical architecture, design decisions, Spring Boot-specific internals
- **[Version Management](../VERSIONS.md)**: Update Java/UBI/Spring Boot versions, override procedures
