# Testing & Validation Guide

📚 **Documentation**: [README](README.md) | [Quick Start](QUICKSTART.md) | [Deployment](DEPLOYMENT.md) | [Testing](TESTING.md) | [Versions](VERSIONS.md) | [Contributing](CONTRIBUTING.md)

---

Comprehensive guide for validating builds, testing deployments, troubleshooting issues, and performing experiments with OpenShift Java samples.

## Table of Contents

- [Quick Validation](#quick-validation)
- [Build Testing](#build-testing)
- [Deployment Testing](#deployment-testing)
- [Metrics Validation](#metrics-validation)
- [Performance Testing](#performance-testing)
- [Troubleshooting](#troubleshooting)
- [Debugging Containers](#debugging-containers)

---

## Quick Validation

### Verify Repository Structure
```bash
# Validates all expected files and directories exist
./scripts/verify-structure.sh
```

**Expected output**: ✓ marks for all checks (Dockerfiles, manifests, scripts)

### Quick Build Validation (All 15 Configurations)
```bash
# Tests that all Dockerfiles build successfully
# Does NOT run containers (fast validation)
./scripts/quick-validate-builds.sh
```

**Duration**: ~5-10 minutes (uses cache)  
**Expected output**: `15/15 passed` with all green `PASS` indicators

### BuildConfig & ARG Override Validation
```bash
# Validates YAML syntax and tests ARG parameterization
./scripts/validate-buildconfigs.sh
```

**Tests performed**:
- 15 BuildConfig YAML files validated
- 4 ARG override scenarios tested (BUILDER_IMAGE, RUNTIME_IMAGE, TOMCAT_VERSION, WILDFLY_IMAGE)

**Expected output**: `19/19 passed`

### Runtime & Endpoint Validation
```bash
# Builds containers, runs them, tests endpoints
# Takes longer but validates full functionality
./scripts/validate-runtime.sh
```

**Tests performed**:
- Container startup verification
- Endpoint health checks (/metrics, /actuator/prometheus)
- Pattern matching for expected responses

**Expected output**: `4/4 passed` (one per runtime type)

### Comprehensive Validation Suite
```bash
# Complete validation: builds, runtime, endpoints, BuildConfigs
# Use for final validation before releases
./scripts/validate-all-builds.sh
```

**Duration**: ~30-45 minutes  
**Tests all 16 configurations with full runtime testing**

---

## Build Testing

### Test Single Sample Build

#### Local Maven Build
```bash
cd metrics-sample-undertow
mvn clean package

# Verify JAR created
ls -lh target/*.jar
```

**Success criteria**: 
- Build completes without errors
- JAR file exists in `target/`
- No test failures

#### Docker/Podman Build
```bash
# Build with default ARGs
podman build -f Dockerfile.openjdk17 -t test-undertow:17 .

# Verify image created
podman images | grep test-undertow

# Test image runs
podman run --rm test-undertow:17 java -version
```

**Success criteria**:
- Image builds successfully
- Java version matches expected (17 in this example)
- Container starts and exits cleanly

### Test ARG Parameterization

#### Override Builder Image
```bash
cd metrics-sample-undertow
podman build -f Dockerfile.openjdk17 \
  --build-arg BUILDER_IMAGE=registry.access.redhat.com/ubi9/openjdk-17:1.20 \
  -t test-override:latest .
```

#### Override Runtime Base (Tomcat)
```bash
cd metrics-sample-tomcat
podman build -f Dockerfile.openjdk17 \
  --build-arg RUNTIME_BASE=registry.access.redhat.com/ubi9/ubi-minimal:9.4 \
  -t test-tomcat-base:latest .
```

#### Override Application Server Version
```bash
# Tomcat version
cd metrics-sample-tomcat
podman build -f Dockerfile.openjdk17 \
  --build-arg TOMCAT_VERSION=10.1.48 \
  -t test-tomcat-custom:latest .

# WildFly version
cd metrics-sample-wildfly
podman build -f Dockerfile.openjdk17 \
  --build-arg WILDFLY_IMAGE=quay.io/wildfly/wildfly:37.0.0.Final-jdk17 \
  -t test-wildfly-custom:latest .
```

**Success criteria**: Build completes with overridden version

### Test with Version Environment Variables

Using `versions.env`:
```bash
# Create versions.env from template
cp versions.env.example versions.env

# Edit versions.env with your overrides
nano versions.env

# Source and build
source versions.env
BUILDER_IMAGE_17=$BUILDER_IMAGE_17 ./scripts/build-all.sh
```

### Validate Container Detection Logs

```bash
# Build and run with container logging
podman run --rm -m 512m test-undertow:17 2>&1 | grep -i "container\|memory"
```

**Expected output**:
```
OSContainer::init: Memory Limit is: 536870912
Memory: 512M
Memory Limit: 512M
Maximum Heap Size: 332M  # ~65% of 512M
```

---

## Deployment Testing

### Local Container Testing

#### Start Container with Resource Limits
```bash
# Run with 512Mi memory limit
podman run -d --name test-undertow \
  -m 512m \
  -p 8080:8080 \
  test-undertow:17

# Check container started
podman ps | grep test-undertow

# Check logs
podman logs test-undertow

# Test endpoint
curl http://localhost:8080/metrics

# Cleanup
podman stop test-undertow && podman rm test-undertow
```

#### Test Environment Variable Overrides
```bash
# Override JVM options
podman run -d --name test-tuned \
  -m 512m \
  -p 8080:8080 \
  -e JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=60.0" \
  test-undertow:17

# Verify settings in logs
podman logs test-tuned 2>&1 | grep -i "maxram\|initialram"

# Cleanup
podman stop test-tuned && podman rm test-tuned
```

### OpenShift Deployment Testing

#### Deploy Single Sample
```bash
# Create namespace
oc new-project java-metrics-test

# Deploy single runtime/version
cd metrics-sample-undertow
oc apply -f k8s/deployment-openjdk17.yaml
oc apply -f k8s/service.yaml

# Wait for ready
oc wait --for=condition=available --timeout=120s deployment/metrics-undertow-openjdk17

# Test endpoint via port-forward
oc port-forward svc/metrics-undertow 8080:8080 &
curl http://localhost:8080/metrics
kill %1  # Stop port-forward
```

#### Deploy All Samples
```bash
# Uses deploy-all.sh script
./scripts/deploy-all.sh

# Verify all pods running
oc get pods -n java-metrics-demo

# Check pod status
oc get pods -n java-metrics-demo -o wide
```

**Expected output**: All pods in `Running` status with `1/1` ready

#### Test BuildConfig Workflow
```bash
# Create ImageStream
oc apply -f metrics-sample-undertow/openshift/imagestream.yaml

# Create BuildConfig
oc apply -f metrics-sample-undertow/openshift/buildconfig-openjdk17.yaml

# Trigger build
oc start-build metrics-undertow-openjdk17

# Monitor build logs
oc logs -f bc/metrics-undertow-openjdk17

# Verify ImageStreamTag created
oc get istag | grep metrics-undertow

# Deploy from ImageStreamTag
oc apply -f metrics-sample-undertow/k8s/deployment-openjdk17.yaml
# (Ensure deployment references: image: metrics-undertow:openjdk17)
```

---

## Metrics Validation

### Test Metrics Endpoint Locally

#### Undertow & Tomcat
```bash
# /metrics endpoint
curl -s http://localhost:8080/metrics | head -20
```

**Expected metrics**:
- `jvm_memory_used_bytes`
- `jvm_memory_max_bytes`
- `jvm_gc_pause_seconds`
- `jvm_threads_live`

#### Spring Boot
```bash
# Actuator endpoints
curl -s http://localhost:8080/actuator/health
curl -s http://localhost:8080/actuator/prometheus | grep jvm_memory
```

#### WildFly
```bash
# Management interface on port 9990
curl -s http://localhost:9990/metrics | head -20
```

**Expected metrics**: `base_memory_*`, `base_cpu_*`, `vendor_*`

### Test Metrics in OpenShift

#### Via Port-Forward
```bash
# Forward service port
oc port-forward svc/metrics-undertow 8080:8080

# Test in another terminal
curl http://localhost:8080/metrics | grep jvm_memory_used_bytes
```

#### Via OpenShift Route
```bash
# Create route
oc expose service/metrics-undertow

# Get route URL
ROUTE=$(oc get route metrics-undertow -o jsonpath='{.spec.host}')

# Test endpoint
curl http://$ROUTE/metrics
```

### ServiceMonitor Validation

#### Deploy ServiceMonitor
```bash
cd metrics-sample-undertow
oc apply -f k8s/servicemonitor.yaml

# Verify ServiceMonitor created
oc get servicemonitor metrics-undertow -o yaml
```

#### Check Prometheus Targets
```bash
# Port-forward to Prometheus (if installed)
oc port-forward -n openshift-monitoring svc/prometheus-k8s 9090:9090

# Open browser: http://localhost:9090/targets
# Look for java-metrics-demo/metrics-undertow/0 target
```

#### Query Metrics in Prometheus
```bash
# Sample PromQL queries
# 1. Heap usage by version
jvm_memory_used_bytes{area="heap", namespace="java-metrics-demo"}

# 2. GC pause duration (95th percentile)
histogram_quantile(0.95, rate(jvm_gc_pause_seconds_bucket[5m]))

# 3. Thread count over time
jvm_threads_live{namespace="java-metrics-demo"}

# 4. Container memory limit
container_spec_memory_limit_bytes{namespace="java-metrics-demo"}
```

---

## Performance Testing

### Heap Ergonomics Comparison

#### Deploy All Versions of Same Runtime
```bash
cd metrics-sample-undertow
oc apply -f k8s/deployment-openjdk11.yaml
oc apply -f k8s/deployment-openjdk17.yaml
oc apply -f k8s/deployment-openjdk21.yaml
oc apply -f k8s/deployment-openjdk23.yaml
oc apply -f k8s/service.yaml
```

#### Monitor Heap Usage
```promql
# Prometheus query
jvm_memory_used_bytes{area="heap", app="metrics-undertow"} / jvm_memory_max_bytes{area="heap"}
```

#### Capture Baselines
```bash
# Get JVM flags from running containers
./scripts/capture-baselines.sh

# View results
cat baseline-captures/undertow-openjdk17-flags.txt | grep -i "maxram\|initialram"
```

### Thread Scaling Test

#### Adjust Thread Pool Size
```bash
# Tomcat example
oc set env deployment/metrics-tomcat-openjdk17 TOMCAT_MAX_THREADS=200

# Monitor thread count
kubectl exec deployment/metrics-tomcat-openjdk17 -- \
  curl -s http://localhost:8080/metrics | grep jvm_threads_live
```

#### Load Test (Requires External Tool)
```bash
# Using hey (HTTP load generator)
hey -z 60s -c 50 http://$ROUTE_URL/actuator/health

# Monitor during load:
# - CPU usage: oc adm top pods
# - Thread count: Query jvm_threads_live
# - GC frequency: Query rate(jvm_gc_pause_seconds_count[1m])
```

### Startup Time Comparison

#### Capture Startup Logs
```bash
# Get pod creation time and ready time
oc get pod -l app=metrics-undertow --sort-by='.metadata.creationTimestamp'

# Check application startup messages
oc logs deployment/metrics-undertow-openjdk17 | grep -i "started\|ready"
```

#### Compare Across Versions
```bash
for version in 11 17 21 23; do
  echo "=== Java $version ==="
  oc logs deployment/metrics-undertow-openjdk$version | grep "Started" | tail -1
done
```

### Resource Limit Stress Test

#### Set Tight Limits
```bash
# Edit deployment to reduce memory limit
oc set resources deployment/metrics-undertow-openjdk17 \
  --limits=memory=384Mi \
  --requests=memory=384Mi

# Monitor for OOMKilled events
oc get events -n java-metrics-demo --watch | grep OOM
```

#### Adjust Heap Percentage
```bash
# Lower heap to 50% to leave more headroom
oc set env deployment/metrics-undertow-openjdk17 \
  JAVA_OPTS="-XX:MaxRAMPercentage=50.0"

# Verify container restarts successfully
oc get pods -w
```

---

## Troubleshooting

### Pods Not Starting

#### Check Pod Status
```bash
# Get pod status
oc get pods -n java-metrics-demo

# Describe pod for events
oc describe pod <pod-name> -n java-metrics-demo
```

#### Common Issues & Fixes

**Image Pull Error**:
```bash
# Symptoms: ErrImagePull, ImagePullBackOff
# Check image exists
podman search <registry>/<image-name>

# Verify registry authentication
podman login <registry>
oc create secret docker-registry quay-secret \
  --docker-server=quay.io \
  --docker-username=<username> \
  --docker-password=<password>

# Link secret to service account
oc secrets link default quay-secret --for=pull
```

**OOMKilled** (Out of Memory):
```bash
# Symptoms: Pod terminated with reason: OOMKilled
# Check current limits
oc get deployment/<name> -o jsonpath='{.spec.template.spec.containers[0].resources}'

# Increase memory limit OR reduce heap percentage
oc set resources deployment/<name> --limits=memory=768Mi
# OR
oc set env deployment/<name> JAVA_OPTS="-XX:MaxRAMPercentage=60.0"
```

**CrashLoopBackOff**:
```bash
# Check application logs
oc logs <pod-name> -n java-metrics-demo

# Check previous container logs (if restarted)
oc logs <pod-name> --previous -n java-metrics-demo

# Common causes:
# - Application startup error (check Java exceptions)
# - Missing environment variables
# - Incorrect health probe configuration
```

**Pending Status**:
```bash
# Check why pod is pending
oc describe pod <pod-name> | grep -A 5 Events

# Common causes:
# - Insufficient cluster resources
# - PVC not bound
# - Node selector not matching
```

### Metrics Not Showing

#### Test Endpoint Inside Pod
```bash
# Exec into pod
oc exec -n java-metrics-demo <pod-name> -- curl -s http://localhost:8080/metrics | head

# Spring Boot actuator
oc exec -n java-metrics-demo <pod-name> -- curl -s http://localhost:8080/actuator/prometheus | head

# WildFly management endpoint
oc exec -n java-metrics-demo <pod-name> -- curl -s http://localhost:9990/metrics | head
```

**If endpoint returns data**: Networking/ServiceMonitor issue  
**If endpoint fails**: Application configuration issue

#### Verify Service Configuration
```bash
# Check service exists and has correct selectors
oc get service metrics-undertow -o yaml

# Verify service endpoints
oc get endpoints metrics-undertow

# Test service from another pod
oc run test-pod --image=registry.access.redhat.com/ubi9/ubi:latest --rm -it -- bash
curl http://metrics-undertow.java-metrics-demo.svc:8080/metrics
```

#### Verify ServiceMonitor Configuration
```bash
# Check ServiceMonitor exists
oc get servicemonitor metrics-undertow -o yaml

# Verify label selectors match Service
# ServiceMonitor.spec.selector.matchLabels should match Service.metadata.labels

# Check if Prometheus operator is running
oc get pods -n openshift-monitoring | grep prometheus-operator
```

#### Check Prometheus Scrape Configuration
```bash
# View Prometheus targets (via UI or API)
oc port-forward -n openshift-monitoring svc/prometheus-k8s 9090:9090

# Open: http://localhost:9090/targets
# Look for target with label: namespace="java-metrics-demo"

# If target shows "DOWN", check:
# - ServiceMonitor labels
# - Service port name (must match ServiceMonitor.spec.endpoints[].port)
# - Network policies
```

### Build Failures

#### Test Maven Build Locally
```bash
cd metrics-sample-<runtime>
mvn clean package -X  # Debug output

# Common issues:
# - Missing dependencies: Check pom.xml, verify Maven repo access
# - Compilation errors: Check Java version compatibility
# - Test failures: Run tests individually to isolate
```

#### Test Docker/Podman Build
```bash
podman build -f Dockerfile.openjdk17 -t test:local . --no-cache

# If build fails at specific step, debug that layer:
podman build -f Dockerfile.openjdk17 --target builder -t test:builder .
podman run --rm -it test:builder bash
```

#### OpenShift BuildConfig Failures
```bash
# Check build logs
oc logs -f bc/metrics-undertow-openjdk17

# Describe build for errors
oc describe build/<build-name>

# Common issues:
# - Git clone failures: Check repository URL, branch name
# - Out of disk space: Check builder pod node
# - Network issues: Check egress network policy
# - Base image pull failure: Verify image exists in registry
```

### Performance Issues

#### High Memory Usage
```bash
# Check heap usage
oc exec deployment/<name> -- curl -s http://localhost:8080/metrics | grep "jvm_memory_used_bytes{area=\"heap\"}"

# Check for memory leaks
# Monitor heap over time - should stabilize after warmup
# If heap keeps growing → potential memory leak

# Capture heap dump
oc exec deployment/<name> -- jcmd 1 GC.heap_dump /tmp/heap.dump
oc cp <pod-name>:/tmp/heap.dump ./heap.dump
# Analyze with Eclipse MAT or VisualVM
```

#### High CPU Usage
```bash
# Check CPU metrics
oc adm top pods -n java-metrics-demo

# Check GC overhead
oc exec deployment/<name> -- curl -s http://localhost:8080/metrics | grep jvm_gc_pause_seconds

# If high GC time:
# - Heap too small → Increase memory limit or MaxRAMPercentage
# - Heap too large → Reduce MaxRAMPercentage
# - Consider G1GC tuning flags
```

#### Slow Startup
```bash
# Check startup time in logs
oc logs deployment/<name> | grep -i "started\|ready"

# Increase initial heap to reduce early GC
oc set env deployment/<name> \
  JAVA_OPTS="-XX:InitialRAMPercentage=50.0 -XX:MaxRAMPercentage=65.0"
```

---

## Debugging Containers

### Exec into Running Container
```bash
# Get shell access
oc exec -it deployment/metrics-undertow-openjdk17 -- bash

# Inside container:
ps aux  # Check processes
env     # Check environment variables
java -version  # Verify Java version
curl http://localhost:8080/metrics  # Test endpoint locally
```

### View Container Logs
```bash
# Tail logs
oc logs -f deployment/metrics-undertow-openjdk17

# Last 100 lines
oc logs deployment/metrics-undertow-openjdk17 --tail=100

# Logs from previous container (if restarted)
oc logs deployment/metrics-undertow-openjdk17 --previous

# Logs from specific container in multi-container pod
oc logs <pod-name> -c <container-name>
```

### Debug Container with Extended Tools
```bash
# Create debug pod with same image
oc debug deployment/metrics-undertow-openjdk17

# Or run debug pod with tools image
oc run debug --image=registry.access.redhat.com/ubi9/ubi:latest -it --rm -- bash

# Inside debug pod, test connectivity
curl http://metrics-undertow.java-metrics-demo.svc:8080/metrics
```

### Capture JVM Diagnostics
```bash
# Thread dump
oc exec deployment/<name> -- jcmd 1 Thread.print > threaddump.txt

# Heap histogram
oc exec deployment/<name> -- jcmd 1 GC.class_histogram > histogram.txt

# JVM flags
oc exec deployment/<name> -- jcmd 1 VM.flags

# Container detection info
oc exec deployment/<name> -- java -Xlog:os+container=trace -version
```

### Network Debugging
```bash
# Test DNS resolution
oc exec deployment/<name> -- nslookup metrics-undertow.java-metrics-demo.svc

# Test connectivity to external services
oc exec deployment/<name> -- curl -v https://quay.io

# Check pod IP and ports
oc get pod <pod-name> -o wide
oc describe pod <pod-name> | grep "IP:\|Port:"
```

---

## Advanced Testing Scenarios

### Cgroups Detection Validation
```bash
# Check cgroups version on node
oc debug node/<node-name>
chroot /host
cat /proc/filesystems | grep cgroup

# Verify JVM detects cgroups correctly
oc exec deployment/<name> -- bash -c 'java -Xlog:os+container=info -version 2>&1 | grep -i cgroup'
```

### Compare Java Version Behavior
```bash
# Deploy all 4 Java versions of same runtime
for v in 11 17 21 23; do
  oc apply -f metrics-sample-undertow/k8s/deployment-openjdk${v}.yaml
done

# Compare container detection
for v in 11 17 21 23; do
  echo "=== Java $v ==="
  oc logs deployment/metrics-undertow-openjdk${v} 2>&1 | grep -i "memory limit\|active processor"
done
```

### Security Context Validation
```bash
# Verify non-root execution
oc exec deployment/<name> -- id
# Should show: uid=1001 or uid=1000750000 (OpenShift assigned)

# Check capabilities
oc exec deployment/<name> -- grep Cap /proc/1/status

# Verify seccomp profile
oc get pod <pod-name> -o jsonpath='{.spec.securityContext.seccompProfile}'
```

---

## Continuous Validation

### Pre-Commit Testing
```bash
# Before committing changes
./scripts/verify-structure.sh
./scripts/quick-validate-builds.sh

# If adding new sample/version
cd metrics-sample-<new>
mvn clean package
podman build -f Dockerfile.openjdk<X> -t test:local .
```

### PR Validation Checklist
- [ ] All validation scripts pass
- [ ] Documentation updated (README, sample README)
- [ ] VERSIONS.md updated if versions changed
- [ ] BuildConfig YAML matches Dockerfile ARGs
- [ ] Deployment manifests include security context
- [ ] ServiceMonitor labels match Service
- [ ] Local testing completed (build + run)

### Release Validation
```bash
# Full comprehensive validation
./scripts/validate-all-builds.sh

# Deploy to test cluster
oc new-project java-metrics-release-test
./scripts/deploy-all.sh

# Verify all pods running
oc get pods -n java-metrics-release-test

# Test metrics endpoints
for svc in $(oc get svc -o name); do
  echo "Testing $svc"
  oc port-forward $svc 8080:8080 &
  sleep 2
  curl -s http://localhost:8080/metrics | head -5
  kill %1
done
```

---

## Getting Help

### Documentation Resources
- **[Quick Start](QUICKSTART.md)**: Getting started guide
- **[Deployment](DEPLOYMENT.md)**: Detailed deployment procedures
- **[Implementation](IMPLEMENTATION.md)**: Technical architecture
- **[Versions](VERSIONS.md)**: Image version matrix
- **[Contributing](CONTRIBUTING.md)**: How to contribute
- **[Copilot Instructions](.github/copilot-instructions.md)**: Tuning guidance

### Community Support
- **Issues**: [GitHub Issues](https://github.com/davidecelano/openshift-java-playground/issues)
- **Discussions**: [GitHub Discussions](https://github.com/davidecelano/openshift-java-playground/discussions)

### Reporting Bugs
Include in bug reports:
1. Reproduction steps
2. Expected vs actual behavior
3. Logs: `oc logs <pod-name>`
4. Pod description: `oc describe pod <pod-name>`
5. Java version, runtime type, base image version
6. OpenShift/Kubernetes version

---

**✅ Validation Complete?** See **[Contributing Guide](CONTRIBUTING.md)** to add new samples or scenarios!
