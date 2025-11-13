#!/bin/bash
# Quick runtime validation - tests container startup and endpoint health
# Tests one version from each runtime type

cd "$(dirname "$0")/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TOTAL=0
PASSED=0
FAILED=0

echo "Runtime & Endpoint Validation"
echo "=============================="
echo ""

cleanup() {
    local container=$1
    podman stop "$container" >/dev/null 2>&1 || true
    podman rm "$container" >/dev/null 2>&1 || true
}

test_runtime() {
    local runtime=$1
    local version=$2
    local endpoint=$3
    local host_port=$4
    local container_port=$5
    local pattern=$6
    
    ((TOTAL++))
    local container="test-runtime-${runtime}-${version}"
    local image="localhost/test-${runtime}:${version}"
    
    echo "Testing $runtime openjdk$version..."
    
    # Cleanup any existing container
    cleanup "$container"
    
    # Start container
    echo -n "  Starting container... "
    if ! podman run -d --name "$container" -p "${host_port}:${container_port}" "$image" >/dev/null 2>&1; then
        echo -e "${RED}FAIL${NC} (failed to start)"
        ((FAILED++))
        return
    fi
    echo -e "${GREEN}OK${NC}"
    
    # Wait for startup
    echo -n "  Waiting for endpoint... "
    local max_attempts=30
    local success=false
    
    for ((i=1; i<=max_attempts; i++)); do
        # For Tomcat, accept both 200 and 404 responses (404 means server is running)
        local response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${host_port}${endpoint}" 2>/dev/null || echo "000")
        if [[ "$response" == "200" || "$response" == "404" ]]; then
            # Get actual content and check pattern
            local content=$(curl -s "http://localhost:${host_port}${endpoint}" 2>/dev/null || echo "")
            if echo "$content" | grep -q "$pattern" 2>/dev/null; then
                success=true
                break
            fi
        fi
        sleep 1
    done
    
    # Cleanup
    cleanup "$container"
    
    if [ "$success" = true ]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC} (endpoint not responding)"
        ((FAILED++))
    fi
}

# Test one version from each runtime
test_runtime "undertow" "17" "/metrics" "8081" "8080" "jvm_memory"
test_runtime "springboot" "21" "/actuator/prometheus" "8082" "8080" "jvm_memory"
test_runtime "tomcat" "17" "/" "8083" "8080" "Tomcat/10"
test_runtime "wildfly" "17" "/metrics" "8084" "9990" "base_"

echo ""
echo "=============================="
echo "Summary: $PASSED/$TOTAL passed"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All runtime tests successful!${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAILED tests failed${NC}"
    exit 1
fi
