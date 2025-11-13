#!/bin/bash
# Quick build validation - just tests that all Dockerfiles build successfully
# Does not run containers or test endpoints (faster validation)

cd "$(dirname "$0")/.."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
TOTAL=0
PASSED=0
FAILED=0

echo "Quick Build Validation for UBI 9 Migration"
echo "==========================================="
echo ""

test_build() {
    local sample=$1
    local version=$2
    local dockerfile="Dockerfile.openjdk${version}"
    
    ((TOTAL++))
    echo -n "Testing $sample openjdk$version... "
    
    if podman build -q -f "metrics-sample-${sample}/${dockerfile}" -t "test-${sample}:${version}" "metrics-sample-${sample}" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}"
        ((FAILED++))
        echo "  Failed to build metrics-sample-${sample}/${dockerfile}"
    fi
}

# Test all configurations
echo "Undertow (4 versions):"
test_build "undertow" "11"
test_build "undertow" "17"
test_build "undertow" "21"
test_build "undertow" "23"

echo ""
echo "Spring Boot (3 versions):"
test_build "springboot" "17"
test_build "springboot" "21"
test_build "springboot" "23"

echo ""
echo "Tomcat (4 versions):"
test_build "tomcat" "11"
test_build "tomcat" "17"
test_build "tomcat" "21"
test_build "tomcat" "23"

echo ""
echo "WildFly (4 versions):"
test_build "wildfly" "11"
test_build "wildfly" "17"
test_build "wildfly" "21"
test_build "wildfly" "23"

echo ""
echo "==========================================="
echo "Summary: $PASSED/$TOTAL passed"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All builds successful!${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAILED builds failed${NC}"
    exit 1
fi
