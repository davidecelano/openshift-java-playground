#!/bin/bash
# Validate BuildConfig YAML files and test ARG overrides

cd "$(dirname "$0")/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TOTAL=0
PASSED=0
FAILED=0

echo "BuildConfig & ARG Override Validation"
echo "======================================"
echo ""

# Test BuildConfig YAML syntax
echo "=== BuildConfig YAML Validation ==="
test_buildconfig() {
    local runtime=$1
    local version=$2
    local file="metrics-sample-${runtime}/openshift/buildconfig-openjdk${version}.yaml"
    
    ((TOTAL++))
    echo -n "Validating $runtime openjdk$version... "
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}FAIL${NC} (file not found)"
        ((FAILED++))
        return
    fi
    
    if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC} (invalid YAML)"
        ((FAILED++))
    fi
}

# Validate all BuildConfigs
test_buildconfig "undertow" "11"
test_buildconfig "undertow" "17"
test_buildconfig "undertow" "21"
test_buildconfig "undertow" "23"
test_buildconfig "springboot" "17"
test_buildconfig "springboot" "21"
test_buildconfig "springboot" "23"
test_buildconfig "tomcat" "11"
test_buildconfig "tomcat" "17"
test_buildconfig "tomcat" "21"
test_buildconfig "tomcat" "23"
test_buildconfig "wildfly" "11"
test_buildconfig "wildfly" "17"
test_buildconfig "wildfly" "21"
test_buildconfig "wildfly" "23"

echo ""
echo "=== ARG Override Tests ==="

# Test ARG overrides (one per runtime type)
test_arg_override() {
    local runtime=$1
    local version=$2
    local arg_name=$3
    local arg_value=$4
    local dockerfile="Dockerfile.openjdk${version}"
    
    ((TOTAL++))
    echo -n "Testing $runtime $arg_name override... "
    
    if podman build -q -f "metrics-sample-${runtime}/${dockerfile}" \
        --build-arg "${arg_name}=${arg_value}" \
        -t "test-${runtime}:argtest" \
        "metrics-sample-${runtime}" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}"
        ((FAILED++))
    fi
}

# One override test per runtime type
test_arg_override "undertow" "17" "BUILDER_IMAGE" "registry.access.redhat.com/ubi9/openjdk-17:1.20"
test_arg_override "springboot" "21" "RUNTIME_IMAGE" "registry.access.redhat.com/ubi9/openjdk-21:1.20"
test_arg_override "tomcat" "17" "TOMCAT_VERSION" "10.1.48"
test_arg_override "wildfly" "17" "WILDFLY_IMAGE" "quay.io/wildfly/wildfly:37.0.0.Final-jdk17"

echo ""
echo "======================================"
echo "Summary: $PASSED/$TOTAL passed"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All validation tests successful!${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAILED tests failed${NC}"
    exit 1
fi
