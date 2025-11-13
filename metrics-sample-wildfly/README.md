# Metrics Sample: WildFly with Micrometer

📚 **Documentation**: [Main README](../README.md) | [Quick Start](../QUICKSTART.md) | [Deployment](../DEPLOYMENT.md) | [Testing](../TESTING.md) | [Implementation](../IMPLEMENTATION.md)

---

WildFly application server with CDI-based metrics using built-in Micrometer subsystem across OpenJDK 11, 17, 21, and 23.

## About This Sample

WildFly provides the **full Jakarta EE application server** experience, making it crucial for:
- **Enterprise application patterns** (CDI, JPA, JMS, EJB) with maximum framework overhead
- **Subsystem architecture** demonstrating modular server design and management interface separation
- **Built-in Micrometer support** (WildFly 34+) showing zero-configuration metrics in modern app servers
- **Memory footprint ceiling** (1Gi limit) representing the upper bound for Java application servers in containers

This sample demonstrates WildFly's **management port separation** (8080 for apps, 9990 for metrics/admin) and **version-specific features** (WildFly 34 for Java 11, WildFly 38 for Java 17/21/23).

## Build & Deploy

### Local Build
```bash
cd metrics-sample-wildfly

# Build all versions
podman build -f Dockerfile.openjdk11 -t quay.io/yourorg/metrics-wildfly:openjdk11 .
podman build -f Dockerfile.openjdk17 -t quay.io/yourorg/metrics-wildfly:openjdk17 .
podman build -f Dockerfile.openjdk21 -t quay.io/yourorg/metrics-wildfly:openjdk21 .
podman build -f Dockerfile.openjdk23 -t quay.io/yourorg/metrics-wildfly:openjdk23 .

# Push to registry
podman push quay.io/yourorg/metrics-wildfly:openjdk11
podman push quay.io/yourorg/metrics-wildfly:openjdk17
podman push quay.io/yourorg/metrics-wildfly:openjdk21
podman push quay.io/yourorg/metrics-wildfly:openjdk23
```

### OpenShift Deploy
```bash
# Update image references in k8s/*.yaml first
oc apply -f k8s/
```

## Test Locally
```bash
# Build WAR
mvn clean package

# Run with local WildFly (adjust paths)
cp target/metrics.war $JBOSS_HOME/standalone/deployments/
$JBOSS_HOME/bin/standalone.sh

# Access endpoints
curl http://localhost:8080/api/health
curl http://localhost:9990/metrics
```

## Key Configuration

| Parameter | Value | Effect | Override Method |
|-----------|-------|--------|------------------|
| **Memory Limit** | 1Gi (largest) | Accommodates WildFly modules + CDI + subsystems | Edit `k8s/deployment-openjdk*.yaml` |
| **Max Heap** | 65% | `-XX:MaxRAMPercentage=65.0` → ~660Mi (lower % due to native overhead) | Change in Dockerfile CMD |
| **Initial Heap** | 50% | `-XX:InitialRAMPercentage=50.0` → ~512Mi | Change in Dockerfile CMD |
| **Worker Threads** | 80 | Configurable via `JBOSS_MAX_THREADS` env var | Set in `deployment.yaml` env section |
| **Application Port** | 8080 | HTTP listener for deployed applications | Service `http` port |
| **Management Port** | 9990 | Admin interface + metrics endpoint (separate Service needed) | Service `management` port |
| **WildFly Version** | 34.0.1.Final (Java 11)<br>38.0.0.Final (Java 17/21/23) | Latest stable supporting target Java version | Dockerfile ARG `WILDFLY_IMAGE` |
| **Metrics Endpoint** | `/metrics` | On management port 9990 (not application port) | WildFly subsystem configuration |
| **Base Images** | Quay.io WildFly | Official WildFly images (not UBI, uses UBI internally) | Dockerfile FROM |

**WildFly-Specific Behavior**:
- **Built-in Micrometer**: WildFly 34+/38+ includes Micrometer subsystem (no manual config needed)
- **Management separation**: Metrics on port 9990, apps on port 8080 (requires 2 Services in k8s)
- **Module overhead**: Larger native memory footprint (subsystems, JBoss Modules classloading) justifies lower heap %
- **Version strategy**: WildFly 34 (last Java 11 support), WildFly 38 (current for Java 17+)
- **Metrics namespace**: `base_` prefix (Microprofile base metrics)

## Comparing with Other Runtimes

| Metric | WildFly | Tomcat | Spring Boot | Undertow |
|--------|---------|--------|-------------|----------|
| **Memory Limit** | 1Gi (largest) | 768Mi | 768Mi | 512Mi (smallest) |
| **Heap %** | 65% | 70% | 70% | 65% |
| **Startup Time** | ~15s (slowest) | ~5s | ~8s | ~2s (fastest) |
| **WAR Size** | ~30MB | ~20MB | ~45MB (JAR) | ~15MB (JAR) |
| **Framework** | Full Jakarta EE | Servlet API | Spring ecosystem | Minimal |
| **Metrics Port** | 9990 (separate) | 8080 | 8080 | 8080 |
| **Max Threads** | 80 (default) | 100 | 50 | IO × 8 = 16 |
| **Use Case** | Full app server | Classic web apps | Enterprise apps | Microservices |

For detailed runtime comparison, see [Main README: Runtime Comparison](../README.md#sample-applications).

## Related Documentation

- **[Main README](../README.md)**: Project overview, architecture, all runtime samples
- **[Quick Start](../QUICKSTART.md)**: Deploy this sample in 10 minutes
- **[Deployment Guide](../DEPLOYMENT.md)**: Build strategies (local, OpenShift BuildConfig, GitHub Actions)
- **[Testing Guide](../TESTING.md)**: Validate builds, troubleshoot issues, performance testing
- **[Implementation Guide](../IMPLEMENTATION.md)**: Technical architecture, design decisions, WildFly-specific internals
- **[Version Management](../VERSIONS.md)**: Update Java/WildFly versions, override procedures
