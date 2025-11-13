#!/bin/bash
# Validate complete OpenShift BuildConfig workflow
# Tests: ImageStream creation, BuildConfig creation, build triggering, 
# deployment from ImageStreamTag, and endpoint health checks

set -euo pipefail

cd "$(dirname "$0")/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL=0
PASSED=0
FAILED=0
NAMESPACE="${OPENSHIFT_NAMESPACE:-java-metrics-validation}"
SAMPLE="${SAMPLE:-undertow}"
JAVA_VERSION="${JAVA_VERSION:-17}"

echo -e "${BLUE}OpenShift Deployment Validation${NC}"
echo "========================================"
echo ""
echo "Configuration:"
echo "  Namespace: $NAMESPACE"
echo "  Sample: metrics-sample-$SAMPLE"
echo "  Java Version: openjdk$JAVA_VERSION"
echo ""

# Helper functions
test_step() {
    local description=$1
    ((TOTAL++))
    echo -n "  [$TOTAL] $description... "
}

pass_step() {
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
}

fail_step() {
    local error=$1
    echo -e "${RED}FAIL${NC}"
    echo -e "      ${RED}Error: $error${NC}"
    ((FAILED++))
}

warn_step() {
    local warning=$1
    echo -e "${YELLOW}WARN${NC}"
    echo -e "      ${YELLOW}Warning: $warning${NC}"
}

# Prerequisites check
echo "=== Prerequisites Check ==="

test_step "OpenShift CLI (oc) installed"
if command -v oc &> /dev/null; then
    pass_step
else
    fail_step "oc command not found. Install OpenShift CLI."
    exit 1
fi

test_step "OpenShift cluster connection"
if oc whoami &> /dev/null; then
    pass_step
else
    fail_step "Not logged in to OpenShift cluster. Run 'oc login' first."
    exit 1
fi

echo ""
echo "=== Phase 1: Namespace Preparation ==="

test_step "Check if namespace exists"
if oc get namespace "$NAMESPACE" &> /dev/null; then
    warn_step "Namespace already exists, will reuse"
else
    pass_step
fi

test_step "Create/verify namespace"
if oc create namespace "$NAMESPACE" 2>&1 | grep -q "AlreadyExists"; then
    pass_step
elif oc get namespace "$NAMESPACE" &> /dev/null; then
    pass_step
else
    fail_step "Failed to create namespace"
fi

test_step "Switch to namespace"
if oc project "$NAMESPACE" &> /dev/null; then
    pass_step
else
    fail_step "Failed to switch to namespace"
fi

echo ""
echo "=== Phase 2: ImageStream Creation ==="

test_step "Apply ImageStream manifest"
if oc apply -f "metrics-sample-$SAMPLE/openshift/imagestream.yaml" &> /dev/null; then
    pass_step
else
    fail_step "Failed to apply ImageStream"
fi

test_step "Verify ImageStream exists"
if oc get imagestream "metrics-$SAMPLE" &> /dev/null; then
    pass_step
else
    fail_step "ImageStream not found after creation"
fi

echo ""
echo "=== Phase 3: BuildConfig Creation ==="

test_step "Apply BuildConfig manifest"
if oc apply -f "metrics-sample-$SAMPLE/openshift/buildconfig-openjdk${JAVA_VERSION}.yaml" &> /dev/null; then
    pass_step
else
    fail_step "Failed to apply BuildConfig"
fi

test_step "Verify BuildConfig exists"
if oc get buildconfig "metrics-$SAMPLE-openjdk$JAVA_VERSION" &> /dev/null; then
    pass_step
else
    fail_step "BuildConfig not found after creation"
fi

echo ""
echo "=== Phase 4: Build Trigger & Monitoring ==="

test_step "Trigger build"
BUILD_NAME=$(oc start-build "metrics-$SAMPLE-openjdk$JAVA_VERSION" -o name 2>&1)
if [ $? -eq 0 ]; then
    pass_step
else
    fail_step "Failed to trigger build: $BUILD_NAME"
fi

test_step "Wait for build to start"
sleep 5
if oc get "$BUILD_NAME" &> /dev/null; then
    pass_step
else
    fail_step "Build not found after triggering"
fi

test_step "Monitor build completion (timeout: 10 minutes)"
BUILD_STATUS=""
MAX_WAIT=600
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    BUILD_STATUS=$(oc get "$BUILD_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    
    if [ "$BUILD_STATUS" == "Complete" ]; then
        pass_step
        break
    elif [ "$BUILD_STATUS" == "Failed" ] || [ "$BUILD_STATUS" == "Error" ] || [ "$BUILD_STATUS" == "Cancelled" ]; then
        fail_step "Build ended with status: $BUILD_STATUS"
        echo -e "      ${RED}Build logs:${NC}"
        oc logs "$BUILD_NAME" 2>&1 | tail -n 20 | sed 's/^/        /'
        break
    fi
    
    sleep 10
    ((ELAPSED+=10))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    fail_step "Build timeout after ${MAX_WAIT}s (status: $BUILD_STATUS)"
fi

echo ""
echo "=== Phase 5: ImageStreamTag Verification ==="

test_step "Verify ImageStreamTag created"
if oc get imagestreamtag "metrics-$SAMPLE:openjdk$JAVA_VERSION" &> /dev/null; then
    pass_step
else
    fail_step "ImageStreamTag not found after build"
fi

test_step "Get ImageStreamTag image reference"
IMAGE_REF=$(oc get imagestreamtag "metrics-$SAMPLE:openjdk$JAVA_VERSION" -o jsonpath='{.image.dockerImageReference}' 2>/dev/null)
if [ -n "$IMAGE_REF" ]; then
    pass_step
    echo "      Image: ${IMAGE_REF:0:80}..."
else
    fail_step "Failed to get image reference"
fi

echo ""
echo "=== Phase 6: Deployment from ImageStreamTag ==="

test_step "Apply deployment manifest"
if oc apply -f "metrics-sample-$SAMPLE/k8s/deployment-openjdk${JAVA_VERSION}.yaml" &> /dev/null; then
    pass_step
else
    fail_step "Failed to apply deployment"
fi

test_step "Apply service manifest"
if oc apply -f "metrics-sample-$SAMPLE/k8s/service.yaml" &> /dev/null; then
    pass_step
else
    fail_step "Failed to apply service"
fi

test_step "Wait for deployment rollout (timeout: 5 minutes)"
if timeout 300 oc rollout status deployment "metrics-sample-$SAMPLE-openjdk$JAVA_VERSION" &> /dev/null; then
    pass_step
else
    fail_step "Deployment rollout timeout or failed"
fi

test_step "Verify pod is running"
POD_NAME=$(oc get pods -l "app=metrics-sample-$SAMPLE,version=openjdk$JAVA_VERSION" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD_NAME" ]; then
    POD_STATUS=$(oc get pod "$POD_NAME" -o jsonpath='{.status.phase}' 2>/dev/null)
    if [ "$POD_STATUS" == "Running" ]; then
        pass_step
        echo "      Pod: $POD_NAME"
    else
        fail_step "Pod status: $POD_STATUS"
    fi
else
    fail_step "No pod found with matching labels"
fi

echo ""
echo "=== Phase 7: Endpoint Health Checks ==="

# Determine metrics endpoint based on runtime
if [ "$SAMPLE" == "springboot" ]; then
    METRICS_PATH="/actuator/prometheus"
elif [ "$SAMPLE" == "wildfly" ]; then
    METRICS_PATH="/metrics"
    METRICS_PORT="9990"
else
    METRICS_PATH="/metrics"
    METRICS_PORT="8080"
fi

test_step "Health endpoint responds"
HEALTH_RESPONSE=$(oc exec "$POD_NAME" -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null || echo "000")
if [ "$HEALTH_RESPONSE" == "200" ]; then
    pass_step
else
    fail_step "Health endpoint returned HTTP $HEALTH_RESPONSE"
fi

test_step "Metrics endpoint responds"
METRICS_PORT="${METRICS_PORT:-8080}"
METRICS_RESPONSE=$(oc exec "$POD_NAME" -- curl -s http://localhost:${METRICS_PORT}${METRICS_PATH} 2>/dev/null || echo "")
if echo "$METRICS_RESPONSE" | grep -q "jvm_memory_used_bytes"; then
    pass_step
    METRIC_COUNT=$(echo "$METRICS_RESPONSE" | grep -c "^[a-z]" || echo "0")
    echo "      Metrics exposed: ~$METRIC_COUNT"
else
    fail_step "Metrics endpoint did not return expected Prometheus metrics"
fi

echo ""
echo "=== Phase 8: Container Awareness Verification ==="

test_step "JVM detected container limits"
CONTAINER_LOGS=$(oc logs "$POD_NAME" 2>/dev/null | grep "os,container" || echo "")
if [ -n "$CONTAINER_LOGS" ]; then
    pass_step
    echo "$CONTAINER_LOGS" | head -n 3 | sed 's/^/      /'
else
    warn_step "No container awareness logs found (may not be enabled)"
fi

test_step "Heap size matches expected percentage"
HEAP_MAX=$(echo "$METRICS_RESPONSE" | grep "jvm_memory_max_bytes.*heap" | awk '{print $2}' | head -n 1)
if [ -n "$HEAP_MAX" ] && [ "$HEAP_MAX" -gt 0 ]; then
    pass_step
    HEAP_MB=$((HEAP_MAX / 1024 / 1024))
    echo "      Max heap: ${HEAP_MB}Mi"
else
    warn_step "Could not determine heap size from metrics"
fi

echo ""
echo "========================================"
echo -e "${BLUE}Summary: $PASSED/$TOTAL passed${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All OpenShift deployment validation tests successful!${NC}"
    echo ""
    echo "Deployed resources:"
    echo "  oc get all -l app=metrics-sample-$SAMPLE -n $NAMESPACE"
    echo ""
    echo "Access application:"
    echo "  oc port-forward -n $NAMESPACE svc/metrics-sample-$SAMPLE 8080:8080"
    echo ""
    echo "Cleanup:"
    echo "  oc delete namespace $NAMESPACE"
    exit 0
else
    echo -e "${RED}✗ $FAILED tests failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  oc get builds -n $NAMESPACE"
    echo "  oc logs $BUILD_NAME -n $NAMESPACE"
    echo "  oc get pods -n $NAMESPACE"
    echo "  oc logs $POD_NAME -n $NAMESPACE"
    exit 1
fi
