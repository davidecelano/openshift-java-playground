# Deployment Guide

Complete guide for building, deploying, and monitoring metrics sample applications on OpenShift.

## Prerequisites

### Required Tools
```bash
# Verify installations
podman --version  # or docker --version
oc version       # OpenShift CLI
mvn --version    # Maven 3.6+
```

### Registry Access
Configure access to your container registry (Quay.io example):

```bash
# Login to registry
podman login quay.io

# Create robot account or use personal credentials
# For GitHub Actions, add secrets: QUAY_USERNAME, QUAY_PASSWORD
```

### OpenShift Cluster
- OpenShift 4.10+ or Kubernetes 1.24+ with Prometheus Operator
- Sufficient quotas: 4Gi memory, 2 CPU per sample variant

## Build All Samples Locally

### Quick Build Script
```bash
#!/bin/bash
set -e

REGISTRY="quay.io/yourorg"
SAMPLES=(undertow springboot tomcat wildfly)
VERSIONS=(11 17 21 23)

for SAMPLE in "${SAMPLES[@]}"; do
  echo "Building metrics-sample-${SAMPLE}..."
  cd "metrics-sample-${SAMPLE}"
  
  for VERSION in "${VERSIONS[@]}"; do
    echo "  OpenJDK ${VERSION}..."
    podman build -f Dockerfile.openjdk${VERSION} \
      -t ${REGISTRY}/metrics-${SAMPLE}:openjdk${VERSION} .
  done
  
  cd ..
done

echo "Build complete!"
```

Save as `build-all.sh`, make executable: `chmod +x build-all.sh`

### Push All Images
```bash
#!/bin/bash
set -e

REGISTRY="quay.io/yourorg"
SAMPLES=(undertow springboot tomcat wildfly)
VERSIONS=(11 17 21 23)

for SAMPLE in "${SAMPLES[@]}"; do
  for VERSION in "${VERSIONS[@]}"; do
    echo "Pushing ${SAMPLE}:openjdk${VERSION}..."
    podman push ${REGISTRY}/metrics-${SAMPLE}:openjdk${VERSION}
  done
done

echo "Push complete!"
```

Save as `push-all.sh`, make executable: `chmod +x push-all.sh`

## Deploy to OpenShift

### Update Image References
Before deploying, update all `k8s/deployment-*.yaml` files with your registry:

```bash
# Example: Replace placeholder with actual registry
find . -name "deployment-*.yaml" -exec sed -i \
  's|quay.io/yourorg|quay.io/myactualorg|g' {} \;
```

### Deploy Single Sample (Example: Undertow)
```bash
cd metrics-sample-undertow

# Create namespace
oc new-project java-metrics-demo

# Deploy all OpenJDK versions
oc apply -f k8s/deployment-openjdk11.yaml
oc apply -f k8s/deployment-openjdk17.yaml
oc apply -f k8s/deployment-openjdk21.yaml
oc apply -f k8s/deployment-openjdk23.yaml

# Create service
oc apply -f k8s/service.yaml

# Create ServiceMonitor (if Prometheus Operator installed)
oc apply -f k8s/servicemonitor.yaml

# Verify deployments
oc get pods -l app=metrics-undertow
oc get svc metrics-undertow
```

### Deploy All Samples
```bash
#!/bin/bash
set -e

SAMPLES=(undertow springboot tomcat wildfly)

oc new-project java-metrics-demo || oc project java-metrics-demo

for SAMPLE in "${SAMPLES[@]}"; do
  echo "Deploying metrics-sample-${SAMPLE}..."
  cd "metrics-sample-${SAMPLE}"
  oc apply -f k8s/
  cd ..
done

echo "Deployment complete!"
echo "Check status: oc get pods"
```

Save as `deploy-all.sh`

## Access Applications

### Via Port Forward
```bash
# Undertow
oc port-forward deployment/metrics-undertow-openjdk17 8080:8080
curl http://localhost:8080/health
curl http://localhost:8080/metrics

# Spring Boot
oc port-forward deployment/metrics-springboot-openjdk17 8081:8080
curl http://localhost:8081/actuator/health
curl http://localhost:8081/actuator/prometheus

# Tomcat
oc port-forward deployment/metrics-tomcat-openjdk17 8082:8080
curl http://localhost:8082/health
curl http://localhost:8082/metrics

# WildFly (note management port)
oc port-forward deployment/metrics-wildfly-openjdk17 8083:8080 9990:9990
curl http://localhost:8083/api/health
curl http://localhost:9990/metrics
```

### Via OpenShift Routes
```bash
# Create routes
oc expose service metrics-undertow
oc expose service metrics-springboot
oc expose service metrics-tomcat
oc expose service metrics-wildfly

# Get URLs
oc get routes

# Access via route
ROUTE=$(oc get route metrics-undertow -o jsonpath='{.spec.host}')
curl http://${ROUTE}/health
```

## Monitor with Prometheus

### Verify ServiceMonitor
```bash
# Check ServiceMonitor created
oc get servicemonitor

# Verify Prometheus targets
# Access Prometheus UI (cluster-dependent), check Targets page
```

### Query Metrics Examples
```promql
# Heap usage across all versions
jvm_memory_used_bytes{area="heap", namespace="java-metrics-demo"}

# Compare GC pause times
rate(jvm_gc_pause_seconds_sum[5m]) / rate(jvm_gc_pause_seconds_count[5m])

# Thread count by version
jvm_threads_live_threads{namespace="java-metrics-demo"}

# CPU usage
process_cpu_usage{namespace="java-metrics-demo"}
```

### Grafana Dashboard
Import or create dashboard with panels:

1. **Heap Usage**: `jvm_memory_used_bytes{area="heap"}`
2. **GC Pause Time**: `rate(jvm_gc_pause_seconds_sum[5m])`
3. **Thread Count**: `jvm_threads_live_threads`
4. **CPU Usage**: `process_cpu_usage`
5. **Class Loading**: `jvm_classes_loaded_classes`

Use variables for `version` (openjdk11, openjdk17, etc.) and `runtime` (undertow, springboot, etc.)

## Troubleshooting

### Pod Not Starting
```bash
# Check events
oc describe pod <pod-name>

# Check logs
oc logs <pod-name>

# Common issues:
# - Image pull errors: verify registry access
# - OOMKilled: increase memory limits
# - CrashLoopBackOff: check application logs for startup errors
```

### Metrics Not Appearing
```bash
# Verify ServiceMonitor
oc get servicemonitor -o yaml

# Check Prometheus targets (via UI or API)
# Ensure labels match between Service and ServiceMonitor

# Test metrics endpoint directly
oc exec <pod-name> -- curl -s http://localhost:8080/metrics | head -20
```

### Resource Limits
```bash
# Check current resource usage
oc adm top pods

# Adjust limits in deployment-*.yaml:
resources:
  requests:
    memory: "512Mi"  # Increase if needed
    cpu: "500m"
  limits:
    memory: "1Gi"
    cpu: "1000m"

# Apply changes
oc apply -f k8s/deployment-openjdk17.yaml
```

## Performance Tuning Experiments

### Compare Heap Ergonomics
```bash
# Deploy all versions of same runtime
oc apply -f metrics-sample-undertow/k8s/

# Monitor heap usage over 1 hour
# Query: jvm_memory_used_bytes{area="heap", app="metrics-undertow"}

# Compare:
# - Max heap reached per version
# - Time to reach steady state
# - GC frequency
```

### Thread Scaling
```bash
# Adjust TOMCAT_MAX_THREADS in deployment
oc set env deployment/metrics-springboot-openjdk17 TOMCAT_MAX_THREADS=100

# Load test (requires load generator)
# Monitor: jvm_threads_live_threads, process_cpu_usage

# Compare throughput vs thread count
```

### Startup Time
```bash
# Capture startup logs
oc logs deployment/metrics-undertow-openjdk11 | grep "started"
oc logs deployment/metrics-undertow-openjdk17 | grep "started"

# Compare:
# - Time from pod creation to ready
# - Initial heap size vs configured
# - Class loading time
```

## GitHub Actions Setup

### Configure Secrets
In GitHub repository settings, add:

- `QUAY_USERNAME`: Quay.io robot account username
- `QUAY_PASSWORD`: Quay.io robot account token

### Workflow Triggers
```yaml
# Builds trigger on:
# 1. Push to main affecting metrics-sample-* directories
# 2. Pull requests with same path filters

# Customize in .github/workflows/build-metrics-samples.yml
```

### View Build Status
Check Actions tab in GitHub repository. Each matrix job builds one Java version.

## Cleanup

### Delete Deployments
```bash
# Delete single sample
cd metrics-sample-undertow
oc delete -f k8s/

# Delete all samples
oc delete project java-metrics-demo

# Or delete selectively
oc delete deployment,service,servicemonitor -l app=metrics-undertow
```

### Remove Images from Registry
```bash
# Via Quay.io UI or API
# Or using podman/skopeo commands
```

## Next Steps

1. **Baseline Capture**: Run `java -Xlog:os+container=info -XX:+PrintFlagsFinal -version` in each pod
2. **Load Testing**: Deploy JMeter/Gatling to generate traffic
3. **Comparative Analysis**: Export Prometheus data to CSV for statistical analysis
4. **Tune & Iterate**: Adjust JVM flags, redeploy, measure improvements

See individual sample READMEs for runtime-specific tuning guidance.
