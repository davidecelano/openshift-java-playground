# Metrics Sample: WildFly with Micrometer

WildFly application server with CDI-based metrics using built-in Micrometer subsystem across OpenJDK 11, 17, 21, and 23.

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

## Tuning Notes
- Undertow IO threads managed by WildFly subsystem
- Worker threads: configurable via `JBOSS_MAX_THREADS` (default 80)
- Heap: 65% of container memory (1Gi limit → ~660Mi max heap)
- Initial heap: 50%
- Larger memory footprint than Tomcat due to additional modules and CDI overhead
- Metrics exposed on management interface (port 9990)
- Automatic JVM metrics registration via Micrometer subsystem
