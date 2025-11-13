# Metrics Sample: Standalone Tomcat

📚 **Documentation**: [Main README](../README.md) | [Quick Start](../QUICKSTART.md) | [Deployment](../DEPLOYMENT.md) | [Testing](../TESTING.md) | [Implementation](../IMPLEMENTATION.md)

---

Standalone Apache Tomcat 10 server with servlet-based metrics endpoints across OpenJDK 11, 17, 21, and 23 on Red Hat UBI base images.

## About This Sample

Standalone Tomcat demonstrates **classic enterprise servlet container** deployment patterns, essential for:
- **Comparing embedded vs standalone** servlet containers (vs Spring Boot's embedded Tomcat)
- **Manual Tomcat installation** in containers (download, extract, configure)
- **Legacy application migration** from traditional WAR deployments to containers
- **Version control** over Tomcat releases (not tied to framework versions)

This sample uses `CATALINA_OPTS` for JVM tuning and `microdnf` (UBI 9 requirement) for package management, showcasing container best practices.

## Build & Deploy

### Local Build
```bash
cd metrics-sample-tomcat

# Build all versions
podman build -f Dockerfile.openjdk11 -t quay.io/yourorg/metrics-tomcat:openjdk11 .
podman build -f Dockerfile.openjdk17 -t quay.io/yourorg/metrics-tomcat:openjdk17 .
podman build -f Dockerfile.openjdk21 -t quay.io/yourorg/metrics-tomcat:openjdk21 .
podman build -f Dockerfile.openjdk23 -t quay.io/yourorg/metrics-tomcat:openjdk23 .

# Push to registry
podman push quay.io/yourorg/metrics-tomcat:openjdk11
podman push quay.io/yourorg/metrics-tomcat:openjdk17
podman push quay.io/yourorg/metrics-tomcat:openjdk21
podman push quay.io/yourorg/metrics-tomcat:openjdk23
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

# Run with local Tomcat (adjust paths)
cp target/metrics.war $CATALINA_HOME/webapps/ROOT.war
$CATALINA_HOME/bin/catalina.sh run

# Access endpoints
curl http://localhost:8080/health
curl http://localhost:8080/metrics
```

## Key Configuration

| Parameter | Value | Effect | Override Method |
|-----------|-------|--------|------------------|
| **Memory Limit** | 768Mi | Same as Spring Boot (servlet container overhead) | Edit `k8s/deployment-openjdk*.yaml` |
| **Max Heap** | 70% | `-XX:MaxRAMPercentage=70.0` → ~537Mi | Change in Dockerfile ENV CATALINA_OPTS |
| **Initial Heap** | 50% | `-XX:InitialRAMPercentage=50.0` → ~384Mi | Change in Dockerfile ENV CATALINA_OPTS |
| **Tomcat Max Threads** | 100 | Connector `maxThreads` attribute (higher than Spring Boot's 50) | `TOMCAT_MAX_THREADS` env var updates `server.xml` |
| **Tomcat Version** | 10.1.49 | Latest Tomcat 10.1.x (Jakarta EE 9) | Dockerfile ARG `TOMCAT_VERSION` |
| **Metrics Port** | 8080 | Same port as application (servlet-based endpoint) | Service definition |
| **JVM Flags** | Via `CATALINA_OPTS` | Tomcat-specific environment variable | Set in `deployment.yaml` env section |
| **Base Images** | UBI 9 OpenJDK | Java 11/17/21/23: `:1.21` | Dockerfile ARG or BuildConfig buildArgs |

**Tomcat-Specific Behavior**:
- **Manual installation**: Dockerfile downloads Tomcat binary from Apache mirrors (not pre-installed)
- **Package manager**: Uses `microdnf` (UBI 9 minimal) for `tar`/`gzip` installation
- **Thread pool sizing**: Default 100 threads (higher than Spring Boot) to handle servlet concurrency
- **Metrics integration**: Servlet-based `MetricsServlet` using Micrometer Prometheus registry

## Comparing with Other Runtimes

| Metric | Tomcat | Spring Boot | Undertow | WildFly |
|--------|--------|-------------|----------|----------|
| **Memory Limit** | 768Mi | 768Mi | 512Mi (smallest) | 1Gi (largest) |
| **Heap %** | 70% | 70% | 65% | 65% |
| **Startup Time** | ~5s | ~8s | ~2s (fastest) | ~15s |
| **WAR/JAR Size** | ~20MB (WAR) | ~45MB (JAR) | ~15MB (JAR) | ~30MB (WAR) |
| **Tomcat Version** | 10.1.49 (standalone) | Embedded (Spring-managed) | N/A (Undertow) | N/A (Undertow in WildFly) |
| **Max Threads** | 100 (default) | 50 (default) | IO × 8 = 16 | 80 (default) |
| **Use Case** | Classic web apps | Enterprise apps | Microservices | Full Jakarta EE |

For detailed runtime comparison, see [Main README: Runtime Comparison](../README.md#sample-applications).

## Related Documentation

- **[Main README](../README.md)**: Project overview, architecture, all runtime samples
- **[Quick Start](../QUICKSTART.md)**: Deploy this sample in 10 minutes
- **[Deployment Guide](../DEPLOYMENT.md)**: Build strategies (local, OpenShift BuildConfig, GitHub Actions)
- **[Testing Guide](../TESTING.md)**: Validate builds, troubleshoot issues, performance testing
- **[Implementation Guide](../IMPLEMENTATION.md)**: Technical architecture, design decisions, Tomcat-specific internals
- **[Version Management](../VERSIONS.md)**: Update Java/UBI/Tomcat versions, override procedures
