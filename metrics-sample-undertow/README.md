# Metrics Sample: Undertow with Multi-Version OpenJDK

📚 **Documentation**: [Main README](../README.md) | [Quick Start](../QUICKSTART.md) | [Deployment](../DEPLOYMENT.md) | [Testing](../TESTING.md) | [Implementation](../IMPLEMENTATION.md)

---

Lightweight HTTP service using Undertow, exposing Prometheus JVM metrics across OpenJDK 11, 17, 21, and 23 on Red Hat UBI base images.

## About This Sample

Undertow provides the **minimal footprint baseline** for comparing Java runtimes in containers. Its direct NIO control and small dependency tree make it ideal for:
- **Low-latency microservices** requiring sub-10ms response times
- **Resource-constrained environments** (512Mi memory limit vs 768Mi+ for frameworks)
- **Baseline experiments** measuring pure JVM overhead without framework noise

Undertow's architecture exposes container-aware thread pool sizing (IO threads = vCPUs, worker threads = IO × 8), making it excellent for studying JVM CPU detection mechanisms.

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

## Key Configuration

| Parameter | Value | Effect | Override Method |
|-----------|-------|--------|------------------|
| **Memory Limit** | 512Mi | Smallest footprint (baseline) | Edit `k8s/deployment-openjdk*.yaml` |
| **Max Heap** | 65% | `-XX:MaxRAMPercentage=65.0` → ~330Mi | Change in Dockerfile CMD |
| **Initial Heap** | 50% | `-XX:InitialRAMPercentage=50.0` → ~256Mi (reduces early GC) | Change in Dockerfile CMD |
| **IO Threads** | `min(2, vCPUs)` | Connection acceptance, non-blocking I/O | Hardcoded in `Main.java` |
| **Worker Threads** | `IO threads × 8` | Blocking operations (default 16 for 2 vCPUs) | Hardcoded in `Main.java` |
| **Metrics Port** | 8080 | Same port as application (single listener) | Change in Dockerfile EXPOSE + Service |
| **Base Images** | UBI 9 OpenJDK | Java 11: `:1.21`, Java 17/21/23: `:1.21` | Dockerfile ARG or BuildConfig buildArgs |

**Container-Aware Behavior**:
- JVM reads cgroups memory limit → calculates max heap automatically
- `Runtime.getRuntime().availableProcessors()` returns container vCPUs (not host cores)
- Verify detection: `docker logs <container> | grep "os,container"`

## Comparing with Other Runtimes

| Metric | Undertow | Spring Boot | Tomcat | WildFly |
|--------|----------|-------------|--------|----------|
| **Memory Limit** | 512Mi (smallest) | 768Mi | 768Mi | 1Gi (largest) |
| **Heap %** | 65% | 70% | 70% | 65% |
| **Startup Time** | ~2s | ~8s | ~5s | ~15s |
| **JAR/WAR Size** | ~15MB | ~45MB | ~20MB (WAR) | ~30MB (WAR) |
| **Metrics Endpoint** | `/metrics` | `/actuator/prometheus` | `/metrics` | `/metrics` (port 9990) |
| **Use Case** | Microservices, low-latency | Enterprise apps, rapid dev | Classic web apps | Full Jakarta EE |

For detailed runtime comparison, see [Main README: Runtime Comparison](../README.md#sample-applications).

## Related Documentation

- **[Main README](../README.md)**: Project overview, architecture, all runtime samples
- **[Quick Start](../QUICKSTART.md)**: Deploy this sample in 10 minutes
- **[Deployment Guide](../DEPLOYMENT.md)**: Build strategies (local, OpenShift BuildConfig, GitHub Actions)
- **[Testing Guide](../TESTING.md)**: Validate builds, troubleshoot issues, performance testing
- **[Implementation Guide](../IMPLEMENTATION.md)**: Technical architecture, design decisions, Undertow-specific internals
- **[Version Management](../VERSIONS.md)**: Update Java/UBI versions, override procedures
