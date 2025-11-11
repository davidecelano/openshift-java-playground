# Metrics Sample: Standalone Tomcat

Standalone Apache Tomcat 10 server with servlet-based metrics endpoints across OpenJDK 11, 17, 21, and 23 on Red Hat UBI base images.

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

## Tuning Notes
- Tomcat max threads: 100 (configurable via `TOMCAT_MAX_THREADS` env var)
- Heap: 70% of container memory (768Mi limit → ~537Mi max heap)
- Initial heap: 50%
- Uses `CATALINA_OPTS` for JVM flags
