# Quick Start Guide

Get up and running with OpenShift Java metrics samples in under 10 minutes.

## Prerequisites Check

```bash
# Verify tools installed
command -v podman && echo "✓ Podman" || echo "✗ Install Podman"
command -v oc && echo "✓ OpenShift CLI" || echo "✗ Install oc"
command -v mvn && echo "✓ Maven" || echo "✗ Install Maven"

# Verify OpenShift cluster access
oc whoami && echo "✓ Connected to cluster" || echo "✗ Login to cluster first"

# Verify registry access
podman login quay.io && echo "✓ Registry authenticated" || echo "✗ Login to registry"
```

## 5-Minute Local Test

Test a single sample locally before deploying:

```bash
# 1. Build Spring Boot sample
cd metrics-sample-springboot
mvn clean package

# 2. Run locally
java -jar target/metrics-sample-springboot-1.0.0.jar

# 3. Test endpoints (new terminal)
curl http://localhost:8080/actuator/health
curl http://localhost:8080/actuator/prometheus | grep jvm_memory

# 4. Stop with Ctrl+C
```


## 10-Minute OpenShift-Native Deploy

Build and deploy all samples using OpenShift BuildConfigs (recommended):

```bash
# 1. Ensure you're logged into OpenShift
oc whoami

# 2. Create namespace (if needed)
oc new-project java-metrics-demo

# 3. Trigger OpenShift builds from Git source
cd scripts
./trigger-openshift-builds.sh

# 4. Wait for builds to complete (monitor in another terminal)
oc get builds -w -n java-metrics-demo

# 5. Deploy all metrics samples to cluster
./deploy-all.sh

# 6. Watch deployment
oc get pods -n java-metrics-demo -w
```

**About `deploy-all.sh`:**
This script applies all deployment manifests for every metrics sample (Undertow, Spring Boot, Tomcat, WildFly) and OpenJDK version to your OpenShift namespace. It prints status and how to check pods, services, and ServiceMonitors. See [DEPLOYMENT.md](DEPLOYMENT.md) for more details.

## Alternative: Local Build & Push (Optional)

If you prefer building locally and pushing to external registry:

```bash
# 1. Update registry references
./scripts/update-image-refs.sh quay.io/yourorg

# 2. Build all images locally (with optional version overrides)
export REGISTRY=quay.io/yourorg
./scripts/build-all.sh


# 3. Override specific versions for testing (dynamic version management)
BUILDER_IMAGE_17=registry.access.redhat.com/ubi9/openjdk-17:1.22 \
TOMCAT_VERSION=10.1.50 \
REGISTRY=quay.io/yourorg \
./scripts/build-all.sh

# Use a centralized config for overrides
cp versions.env.example versions.env
source versions.env && ./scripts/build-all.sh

# 4. Push to registry
./scripts/push-all.sh

# 5. Deploy
./scripts/deploy-all.sh
```

**Note**: GitHub Actions workflow is now manual-dispatch only. Trigger via:
```bash
gh workflow run build-metrics-samples.yml
```


### Version Override Examples (Dynamic Version Management)

Test different image versions without modifying files:

```bash
# Test newer OpenJDK patch version
BUILDER_IMAGE_21=registry.access.redhat.com/ubi9/openjdk-21:1.22 \
RUNTIME_IMAGE_21=registry.access.redhat.com/ubi9/openjdk-21-runtime:1.22 \
./scripts/build-all.sh

# Test different Tomcat version
TOMCAT_VERSION=10.1.50 ./scripts/build-all.sh

# Test newer WildFly release
WILDFLY_IMAGE_17=quay.io/wildfly/wildfly:38.0.1.Final-jdk17 \
./scripts/build-all.sh

# Use a centralized config for batch overrides
cp versions.env.example versions.env
source versions.env && ./scripts/build-all.sh
```

## Verify Deployment

```bash
# Check all pods running
oc get pods -n java-metrics-demo

# Expected output: 16 pods (4 runtimes × 4 Java versions)
# NAME                                       READY   STATUS    RESTARTS   AGE
# metrics-undertow-openjdk11-xxx             1/1     Running   0          2m
# metrics-undertow-openjdk17-xxx             1/1     Running   0          2m
# metrics-springboot-openjdk11-xxx           1/1     Running   0          2m
# ...

# Check services
oc get svc -n java-metrics-demo

# Check ServiceMonitors (if Prometheus Operator installed)
oc get servicemonitor -n java-metrics-demo
```

## Access Metrics

### Option 1: Port Forward (Quick)

```bash
# Undertow
oc port-forward -n java-metrics-demo deployment/metrics-undertow-openjdk17 8080:8080 &
curl http://localhost:8080/metrics

# Spring Boot
oc port-forward -n java-metrics-demo deployment/metrics-springboot-openjdk17 8081:8080 &
curl http://localhost:8081/actuator/prometheus

# WildFly (note management port)
oc port-forward -n java-metrics-demo deployment/metrics-wildfly-openjdk17 9990:9990 &
curl http://localhost:9990/metrics

# Stop port-forwards
killall oc
```

### Option 2: Routes (Persistent)

```bash
# Create routes
oc expose service metrics-undertow -n java-metrics-demo
oc expose service metrics-springboot -n java-metrics-demo
oc expose service metrics-tomcat -n java-metrics-demo

# Get URLs
oc get routes -n java-metrics-demo

# Access
ROUTE=$(oc get route metrics-undertow -n java-metrics-demo -o jsonpath='{.spec.host}')
curl http://${ROUTE}/health
curl http://${ROUTE}/metrics | grep jvm_memory_used
```

## Query Prometheus

If Prometheus Operator is installed:

```bash
# Get Prometheus route (cluster-specific)
oc get route -n openshift-monitoring prometheus-k8s

# Open in browser and query:
# jvm_memory_used_bytes{namespace="java-metrics-demo", area="heap"}
# jvm_threads_live_threads{namespace="java-metrics-demo"}
# rate(jvm_gc_pause_seconds_sum{namespace="java-metrics-demo"}[5m])
```

## Run Example Experiment

Test heap comparison across Java versions:

```bash
# 1. Deploy baseline
cd example-scenario-heap-comparison
./deploy-baseline.sh

# 2. Wait 5 minutes for warmup
sleep 300

# 3. Capture baselines
../scripts/capture-baselines.sh

# 4. Check results
ls -lh baseline-captures/

# 5. View container detection
grep -i "container\|memory limit" baseline-captures/*.txt
```

## Troubleshooting

### Pods Not Starting

```bash
# Check events
oc describe pod <pod-name> -n java-metrics-demo

# Check logs
oc logs <pod-name> -n java-metrics-demo

# Common fixes:
# - Image pull error: Verify registry access, check image exists
# - OOMKilled: Increase memory limits in deployment YAML
# - CrashLoopBackOff: Check application logs for errors
```

### Metrics Not Showing

```bash
# Test endpoint inside pod
oc exec -n java-metrics-demo <pod-name> -- curl -s http://localhost:8080/metrics | head

# Verify ServiceMonitor labels match Service
oc get servicemonitor metrics-undertow -n java-metrics-demo -o yaml
oc get service metrics-undertow -n java-metrics-demo -o yaml

# Check Prometheus targets (via UI)
```

### Build Failures

```bash
# Test Maven build locally first
cd metrics-sample-<runtime>
mvn clean package

# Check Podman build
podman build -f Dockerfile.openjdk17 -t test:local .
podman run --rm test:local java -version
```

## What to Explore Next

1. **Compare Versions**: Query Prometheus for heap usage across Java versions
   ```promql
   jvm_memory_used_bytes{area="heap", namespace="java-metrics-demo"}
   ```

2. **Adjust Tuning**: Modify JAVA_OPTS in deployments and redeploy
   ```bash
   oc set env deployment/metrics-undertow-openjdk17 \
     JAVA_OPTS="-XX:MaxRAMPercentage=75.0" -n java-metrics-demo
   ```

3. **Load Test**: Deploy a load generator to observe behavior under stress

4. **Create Scenario**: Copy `example-scenario-heap-comparison/` as template

5. **Review Guidance**: Read `.github/copilot-instructions.md` for tuning patterns

## Cleanup

```bash
# Delete everything
./scripts/cleanup.sh

# Or just the namespace
oc delete project java-metrics-demo
```

## Common Commands Reference

```bash
# Build single runtime
cd metrics-sample-undertow
podman build -f Dockerfile.openjdk17 -t myapp:latest .

# Deploy single runtime
oc apply -f k8s/

# Scale deployment
oc scale deployment/metrics-undertow-openjdk17 --replicas=3 -n java-metrics-demo

# Update image
oc set image deployment/metrics-undertow-openjdk17 \
  app=quay.io/myorg/metrics-undertow:openjdk17 -n java-metrics-demo

# View logs
oc logs -f deployment/metrics-undertow-openjdk17 -n java-metrics-demo

# Exec into pod
oc exec -it deployment/metrics-undertow-openjdk17 -n java-metrics-demo -- bash

# Capture JVM flags
oc exec deployment/metrics-undertow-openjdk17 -n java-metrics-demo -- \
  java -XX:+PrintFlagsFinal -version 2>&1 | grep -i container
```

## Getting Help

- **Documentation**: See `README.md`, `DEPLOYMENT.md`, `CONTRIBUTING.md`
- **Tuning Guide**: `.github/copilot-instructions.md`
- **Issues**: Open GitHub issue with logs and steps to reproduce
- **Discussions**: Use GitHub Discussions for questions

---

**Ready to start?** Run `./scripts/verify-structure.sh` to validate your setup!
