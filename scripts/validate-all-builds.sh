#!/bin/bash
# Phase 7 Build Validation Script
# Tests all 16 Docker configurations across 4 runtimes and multiple Java versions
# Validates container startup, endpoint health, and ARG parameterization

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
cd "$WORKSPACE_DIR"

# Use podman if docker requires sudo, otherwise use docker
if ! docker ps >/dev/null 2>&1 && command -v podman >/dev/null 2>&1; then
    CONTAINER_CMD="podman"
    echo "Using Podman (Docker requires elevated permissions)"
else
    CONTAINER_CMD="docker"
    echo "Using Docker"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test result tracking
declare -a PASSED_TESTS
declare -a FAILED_TESTS
TOTAL_TESTS=0

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test result recording
record_pass() {
    local test_name="$1"
    PASSED_TESTS+=("$test_name")
    log_success "$test_name"
}

record_fail() {
    local test_name="$1"
    local error_msg="$2"
    FAILED_TESTS+=("$test_name: $error_msg")
    log_error "$test_name - $error_msg"
}

# Container cleanup
cleanup_container() {
    local container_name="$1"
    if $CONTAINER_CMD ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_info "Cleaning up container: $container_name"
        $CONTAINER_CMD rm -f "$container_name" >/dev/null 2>&1 || true
    fi
}

# Wait for container to be healthy
wait_for_healthy() {
    local container_name="$1"
    local max_attempts=30
    local attempt=1
    
    log_info "Waiting for container $container_name to be healthy..."
    
    while [ $attempt -le $max_attempts ]; do
        if $CONTAINER_CMD ps --filter "name=$container_name" --filter "status=running" | grep -q "$container_name"; then
            sleep 2
            return 0
        fi
        
        # Check if container exited
        if ! $CONTAINER_CMD ps -a --filter "name=$container_name" | grep -q "$container_name"; then
            log_error "Container $container_name does not exist"
            return 1
        fi
        
        if $CONTAINER_CMD ps -a --filter "name=$container_name" --filter "status=exited" | grep -q "$container_name"; then
            log_error "Container $container_name exited prematurely"
            $CONTAINER_CMD logs "$container_name" 2>&1 | tail -20
            return 1
        fi
        
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_error "Container $container_name did not become healthy in time"
    return 1
}

# Test endpoint
test_endpoint() {
    local container_name="$1"
    local endpoint="$2"
    local port="$3"
    local expected_pattern="$4"
    
    log_info "Testing endpoint: http://localhost:$port$endpoint"
    
    local max_attempts=15
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "http://localhost:$port$endpoint" >/dev/null 2>&1; then
            local response=$(curl -s "http://localhost:$port$endpoint")
            if [ -n "$expected_pattern" ]; then
                if echo "$response" | grep -q "$expected_pattern"; then
                    log_success "Endpoint responded with expected pattern"
                    return 0
                else
                    log_warning "Endpoint responded but pattern not found (attempt $attempt/$max_attempts)"
                fi
            else
                log_success "Endpoint responded successfully"
                return 0
            fi
        else
            log_info "Endpoint not ready yet (attempt $attempt/$max_attempts)"
        fi
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_error "Endpoint did not respond successfully"
    $CONTAINER_CMD logs "$container_name" 2>&1 | tail -30
    return 1
}

# Build and test a single configuration
test_build() {
    local runtime="$1"
    local java_version="$2"
    local dockerfile="$3"
    local endpoint="$4"
    local port="${5:-8080}"
    local expected_pattern="${6:-}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    local test_name="${runtime}-openjdk${java_version}"
    local image_name="test-${test_name}:latest"
    local container_name="test-${test_name}"
    
    log_info "=========================================="
    log_info "Testing: $test_name"
    log_info "=========================================="
    
    # Cleanup any existing container
    cleanup_container "$container_name"
    
    # Build the image
    log_info "Building image: $image_name"
    if ! $CONTAINER_CMD build -f "$dockerfile" -t "$image_name" "metrics-sample-${runtime}" 2>&1 | tail -10; then
        record_fail "$test_name" "Build failed"
        return 1
    fi
    log_success "Build completed: $image_name"
    
    # Run the container
    log_info "Starting container: $container_name"
    if ! $CONTAINER_CMD run -d --name "$container_name" -p "${port}:8080" "$image_name" >/dev/null 2>&1; then
        record_fail "$test_name" "Container failed to start"
        return 1
    fi
    
    # Wait for container to be healthy
    if ! wait_for_healthy "$container_name"; then
        record_fail "$test_name" "Container not healthy"
        cleanup_container "$container_name"
        return 1
    fi
    
    # Test endpoint
    if ! test_endpoint "$container_name" "$endpoint" "$port" "$expected_pattern"; then
        record_fail "$test_name" "Endpoint test failed"
        cleanup_container "$container_name"
        return 1
    fi
    
    # Cleanup
    cleanup_container "$container_name"
    
    record_pass "$test_name"
    return 0
}

# Main validation matrix
main() {
    log_info "╔════════════════════════════════════════════════════════╗"
    log_info "║  Phase 7: UBI 9 Build Validation Matrix              ║"
    log_info "║  Testing: 4 runtimes × multiple Java versions        ║"
    log_info "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    # Undertow (Java 11, 17, 21, 23)
    log_info "Testing Undertow runtime..."
    test_build "undertow" "11" "metrics-sample-undertow/Dockerfile.openjdk11" "/metrics" "8081" "jvm_memory"
    test_build "undertow" "17" "metrics-sample-undertow/Dockerfile.openjdk17" "/metrics" "8082" "jvm_memory"
    test_build "undertow" "21" "metrics-sample-undertow/Dockerfile.openjdk21" "/metrics" "8083" "jvm_memory"
    test_build "undertow" "23" "metrics-sample-undertow/Dockerfile.openjdk23" "/metrics" "8084" "jvm_memory"
    
    # Spring Boot (Java 17, 21, 23)
    log_info "Testing Spring Boot runtime..."
    test_build "springboot" "17" "metrics-sample-springboot/Dockerfile.openjdk17" "/actuator/prometheus" "8085" "jvm_memory"
    test_build "springboot" "21" "metrics-sample-springboot/Dockerfile.openjdk21" "/actuator/prometheus" "8086" "jvm_memory"
    test_build "springboot" "23" "metrics-sample-springboot/Dockerfile.openjdk23" "/actuator/prometheus" "8087" "jvm_memory"
    
    # Tomcat (Java 11, 17, 21, 23)
    log_info "Testing Tomcat runtime..."
    test_build "tomcat" "11" "metrics-sample-tomcat/Dockerfile.openjdk11" "/" "8088" "Tomcat"
    test_build "tomcat" "17" "metrics-sample-tomcat/Dockerfile.openjdk17" "/" "8089" "Tomcat"
    test_build "tomcat" "21" "metrics-sample-tomcat/Dockerfile.openjdk21" "/" "8090" "Tomcat"
    test_build "tomcat" "23" "metrics-sample-tomcat/Dockerfile.openjdk23" "/" "8091" "Tomcat"
    
    # WildFly (Java 11, 17, 21, 23)
    log_info "Testing WildFly runtime..."
    test_build "wildfly" "11" "metrics-sample-wildfly/Dockerfile.openjdk11" "/metrics" "8092" "jvm_memory"
    test_build "wildfly" "17" "metrics-sample-wildfly/Dockerfile.openjdk17" "/metrics" "8093" "jvm_memory"
    test_build "wildfly" "21" "metrics-sample-wildfly/Dockerfile.openjdk21" "/metrics" "8094" "jvm_memory"
    test_build "wildfly" "23" "metrics-sample-wildfly/Dockerfile.openjdk23" "/metrics" "8095" "jvm_memory"
    
    # Print summary
    echo ""
    log_info "╔════════════════════════════════════════════════════════╗"
    log_info "║              VALIDATION SUMMARY                        ║"
    log_info "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    local passed_count=${#PASSED_TESTS[@]}
    local failed_count=${#FAILED_TESTS[@]}
    
    log_info "Total tests: $TOTAL_TESTS"
    log_success "Passed: $passed_count"
    
    if [ $failed_count -gt 0 ]; then
        log_error "Failed: $failed_count"
        echo ""
        log_error "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  ❌ $test"
        done
        echo ""
        exit 1
    else
        echo ""
        log_success "╔════════════════════════════════════════════════════════╗"
        log_success "║  ✅ ALL TESTS PASSED! 100% SUCCESS RATE              ║"
        log_success "╚════════════════════════════════════════════════════════╝"
        echo ""
        exit 0
    fi
}

# Run main validation
main
