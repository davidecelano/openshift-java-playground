# Quick Start Guide

📚 **Documentation**: [README](README.md) | [Quick Start](QUICKSTART.md) | [Deployment](DEPLOYMENT.md) | [Testing](TESTING.md) | [Versions](VERSIONS.md) | [Version Management](VERSION_MANAGEMENT.md)

---

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
This script applies all deployment manifests for every metrics sample (Undertow, Spring Boot, Tomcat, WildFly) and OpenJDK version to your OpenShift namespace.

**📖 More Deployment Options**: See **[DEPLOYMENT.md](DEPLOYMENT.md)** for local build & push workflows, GitHub Actions setup, and advanced deployment strategies.

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

### Quick Test via Port Forward

```bash
# Undertow
oc port-forward -n java-metrics-demo deployment/metrics-undertow-openjdk17 8080:8080 &
curl http://localhost:8080/metrics | grep jvm_memory

# Spring Boot
oc port-forward -n java-metrics-demo deployment/metrics-springboot-openjdk17 8081:8080 &
curl http://localhost:8081/actuator/prometheus | head

# Stop port-forwards
killall oc
```

**📊 More Access Options**: See **[DEPLOYMENT.md](DEPLOYMENT.md)** for Routes, Prometheus integration, and Grafana dashboard setup.

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
## Troubleshooting

**Quick checks**:
```bash
# Check pod status
oc get pods -n java-metrics-demo

# View pod events
oc describe pod <pod-name> -n java-metrics-demo

# Check logs
oc logs <pod-name> -n java-metrics-demo
```

**🔧 Comprehensive Troubleshooting**: See **[TESTING.md](TESTING.md#troubleshooting)** for detailed solutions to:
- Pods not starting (ImagePullError, OOMKilled, CrashLoopBackOff)
- Metrics not showing (endpoint tests, ServiceMonitor configuration)
- Build failures (Maven, Docker, BuildConfig)
- Performance issues (memory, CPU, GC)bash
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
## Getting Help

- **📚 Documentation**: [README](README.md) · [Deployment](DEPLOYMENT.md) · [Testing](TESTING.md) · [Versions](VERSIONS.md)

- **🐛 Issues**: [GitHub Issues](https://github.com/davidecelano/openshift-java-playground/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/davidecelano/openshift-java-playground/discussions)