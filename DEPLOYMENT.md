# Deployment Guide

📚 **Documentation**: [README](README.md) | [Quick Start](QUICKSTART.md) | [Deployment](DEPLOYMENT.md) | [Testing](TESTING.md) | [Versions](VERSIONS.md) | [Version Management](VERSION_MANAGEMENT.md)

---

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

### Using Build Scripts

The repository includes pre-built scripts for building and pushing all samples:

```bash
# Set your registry
export REGISTRY=quay.io/yourorg

# Build all 15 configurations
./scripts/build-all.sh

# Push to registry
./scripts/push-all.sh
```

**Script features**:
- Builds all 4 runtimes × multiple Java versions
- Supports version override via environment variables
- Validates builds before proceeding
- Shows progress and summary

**📖 Version Overrides**: See [VERSIONS.md](VERSIONS.md#dynamic-version-management) for overriding base images, Tomcat versions, and WildFly versions.

### Build Single Sample

```bash
cd metrics-sample-undertow
podman build -f Dockerfile.openjdk17 -t myregistry/metrics-undertow:17 .
```

### Override Versions at Build Time

```bash
# Test newer OpenJDK patch
BUILDER_IMAGE_17=registry.access.redhat.com/ubi9/openjdk-17:1.22 \
  ./scripts/build-all.sh

# Test different Tomcat version
TOMCAT_VERSION=10.1.50 ./scripts/build-all.sh

# Use centralized config file
cp versions.env.example versions.env
# Edit versions.env with your overrides
source versions.env && ./scripts/build-all.sh
```

## OpenShift BuildConfig (Cluster-Native Builds)

### Overview

OpenShift BuildConfig enables building container images directly in the cluster from Git sources, eliminating the need for local builds and external registry pushes.

**Benefits**:
- Build from source in cluster (no local Docker/Podman needed)
- Automatic image tagging in ImageStream
- Integrated with OpenShift RBAC and security
- Triggered by Git webhook or manual start-build

### Create ImageStreams

```bash
# Create ImageStream for each runtime
oc apply -f metrics-sample-undertow/openshift/imagestream.yaml
oc apply -f metrics-sample-springboot/openshift/imagestream.yaml
oc apply -f metrics-sample-tomcat/openshift/imagestream.yaml
oc apply -f metrics-sample-wildfly/openshift/imagestream.yaml

# Verify ImageStreams created
oc get imagestream
```

### Create BuildConfigs

```bash
# Create BuildConfigs for all Java versions
oc apply -f metrics-sample-undertow/openshift/buildconfig-openjdk11.yaml
oc apply -f metrics-sample-undertow/openshift/buildconfig-openjdk17.yaml
oc apply -f metrics-sample-undertow/openshift/buildconfig-openjdk21.yaml
oc apply -f metrics-sample-undertow/openshift/buildconfig-openjdk23.yaml

# Repeat for other runtimes: springboot, tomcat, wildfly

# Verify BuildConfigs created
oc get buildconfig
```

### Trigger Builds

```bash
# Manual build trigger
oc start-build metrics-undertow-openjdk17

# Monitor build logs
oc logs -f bc/metrics-undertow-openjdk17

# Or use the provided script to trigger all builds
./scripts/trigger-openshift-builds.sh

# Check build status
oc get builds
oc get builds -w  # Watch mode
```

### Build with Version Overrides

```bash
# Override base image version
oc start-build metrics-undertow-openjdk17 \
  --build-arg BUILDER_IMAGE=registry.access.redhat.com/ubi9/openjdk-17:1.22

# Override Tomcat version
oc start-build metrics-tomcat-openjdk17 \
  --build-arg TOMCAT_VERSION=10.1.50

# Override WildFly image
oc start-build metrics-wildfly-openjdk21 \
  --build-arg WILDFLY_IMAGE=quay.io/wildfly/wildfly:38.0.1.Final-jdk21
```

### Deploy from ImageStreamTag

Once builds complete, deploy using ImageStreamTags:

```bash
# Deployments reference ImageStreamTag
# Example from deployment-openjdk17.yaml:
# image: metrics-undertow:openjdk17

oc apply -f metrics-sample-undertow/k8s/deployment-openjdk17.yaml
oc apply -f metrics-sample-undertow/k8s/service.yaml
```

**Note**: Ensure deployment YAML references ImageStreamTag (e.g., `image: metrics-undertow:openjdk17`) not external registry image.

### BuildConfig Structure

Each BuildConfig includes:
- **Source**: Git repository URL and branch
- **Strategy**: Docker build with specific Dockerfile
- **Output**: ImageStreamTag (e.g., `metrics-undertow:openjdk17`)
- **Build Args**: Default versions (overridable)
- **Triggers**: ConfigChange (auto-rebuild on BuildConfig change)

**📖 More Details**: See [TESTING.md](TESTING.md#test-buildconfig-workflow) for validation procedures.

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


### Deploy All Samples (Recommended)

The easiest way to deploy all metrics samples is to use the provided script:

```bash
cd scripts
./deploy-all.sh
```

This script applies all deployment manifests for every metrics sample (Undertow, Spring Boot, Tomcat, WildFly) and OpenJDK version to your OpenShift namespace (default: `java-metrics-demo`). It prints status and how to check pods, services, and ServiceMonitors.

**Prerequisites:**
- OpenShift CLI (`oc`) installed and logged in
- Namespace/project created (default: `java-metrics-demo`)
- ImageStreams and BuildConfigs created (see above)

**Manual Steps (if not using the script):**
1. Create namespace:
  ```bash
  oc new-project java-metrics-demo
  ```
2. For each sample:
  ```bash
  cd metrics-sample-<runtime>
  oc apply -f k8s/
  cd ..
  ```
3. Check status:
  ```bash
  oc get pods -n java-metrics-demo
  oc get svc -n java-metrics-demo
  oc get servicemonitor -n java-metrics-demo
  ```

See [README.md](README.md#openshift-native-build-recommended) and [QUICKSTART.md](QUICKSTART.md#10-minute-openshift-native-deploy) for more details.
## Dynamic Version Management

All Dockerfiles and BuildConfigs support dynamic version overrides for Java base images and runtime versions. You can override image versions at build time using environment variables, build arguments, or a centralized config file. See [README.md](README.md#dynamic-version-management) and [VERSIONS.md](VERSIONS.md) for details and examples.

## Access Applications

### Via Port Forward (Quick Testing)

See [QUICKSTART.md](QUICKSTART.md#access-metrics) for port-forward examples.

```bash
# Quick test
oc port-forward deployment/metrics-undertow-openjdk17 8080:8080
curl http://localhost:8080/metrics
```

### Via OpenShift Routes (Persistent Access)
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

**Quick Diagnostics**:
```bash
# Check pod status
oc get pods

# View events
oc describe pod <pod-name>

# Check logs
oc logs <pod-name>

# Resource usage
oc adm top pods
```

**🔧 Comprehensive Troubleshooting**: See **[TESTING.md](TESTING.md#troubleshooting)** for detailed solutions:
- Pods not starting (ImagePullError, OOMKilled, CrashLoopBackOff, Pending)
- Metrics not showing (endpoint tests, ServiceMonitor, Prometheus targets)
- Build failures (Maven, Docker, BuildConfig)
- Performance issues (memory leaks, high CPU, slow startup)
- Container debugging procedures

## Performance Tuning Experiments

### Quick Tuning Test

```bash
# Adjust heap percentage
oc set env deployment/metrics-undertow-openjdk17 \
  JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=60.0"

# Compare in Prometheus
# Query: jvm_memory_used_bytes{area="heap"}
```

### Comprehensive Testing Procedures

**🧪 Performance Testing**: See **[TESTING.md](TESTING.md#performance-testing)** for detailed procedures:
- Heap ergonomics comparison across Java versions
- Thread scaling tests with load generation
- Startup time analysis
- Resource limit stress testing
- GC behavior monitoring

**📊 Example Experiments**: See [README.md](README.md#-example-experiments) for memory tuning, CPU scaling, and cgroups comparisons.

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

**Validation & Testing**:
- Run validation scripts: `./scripts/quick-validate-builds.sh`
- See [TESTING.md](TESTING.md) for comprehensive testing procedures
- Capture baseline JVM flags: [TESTING.md - Capture Diagnostics](TESTING.md#capture-jvm-diagnostics)

**Monitoring & Analysis**:
- Set up Grafana dashboards (see Monitor with Prometheus section above)
- Query metrics in Prometheus (see examples above)
- Export data for analysis

**Tuning & Optimization**:

- Experiment with JVM flags: [README.md - Examples](README.md#-example-experiments)
- Runtime-specific tuning: See individual sample READMEs

**Version Management**:
- Update base images: [VERSIONS.md](VERSIONS.md)
- Test new versions: [TESTING.md - ARG Overrides](TESTING.md#test-arg-parameterization)
