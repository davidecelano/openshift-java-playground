#!/bin/bash
# Build all metrics samples across all OpenJDK versions
# Supports dynamic version overrides via environment variables or build args

set -e

REGISTRY="${REGISTRY:-quay.io/yourorg}"
SAMPLES=(undertow springboot tomcat wildfly)
VERSIONS=(11 17 21 23)

# Version overrides (optional)
BUILDER_IMAGE_11="${BUILDER_IMAGE_11:-}"
BUILDER_IMAGE_17="${BUILDER_IMAGE_17:-}"
BUILDER_IMAGE_21="${BUILDER_IMAGE_21:-}"
RUNTIME_IMAGE_11="${RUNTIME_IMAGE_11:-}"
RUNTIME_IMAGE_17="${RUNTIME_IMAGE_17:-}"
RUNTIME_IMAGE_21="${RUNTIME_IMAGE_21:-}"
WILDFLY_IMAGE_11="${WILDFLY_IMAGE_11:-}"
WILDFLY_IMAGE_17="${WILDFLY_IMAGE_17:-}"
WILDFLY_IMAGE_21="${WILDFLY_IMAGE_21:-}"
TOMCAT_VERSION="${TOMCAT_VERSION:-}"

echo "Building all metrics samples..."
echo "Registry: ${REGISTRY}"
echo ""

build_image() {
  local sample=$1
  local version=$2
  local image="${REGISTRY}/metrics-${sample}:openjdk${version}"
  
  echo "  Building ${image}..."
  
  # Build args array
  local build_args=()
  
  # Add version-specific build args if set
  case $version in
    11)
      [[ -n "$BUILDER_IMAGE_11" ]] && build_args+=(--build-arg "BUILDER_IMAGE=$BUILDER_IMAGE_11")
      [[ -n "$RUNTIME_IMAGE_11" ]] && build_args+=(--build-arg "RUNTIME_IMAGE=$RUNTIME_IMAGE_11")
      [[ -n "$WILDFLY_IMAGE_11" ]] && build_args+=(--build-arg "WILDFLY_IMAGE=$WILDFLY_IMAGE_11")
      ;;
    17)
      [[ -n "$BUILDER_IMAGE_17" ]] && build_args+=(--build-arg "BUILDER_IMAGE=$BUILDER_IMAGE_17")
      [[ -n "$RUNTIME_IMAGE_17" ]] && build_args+=(--build-arg "RUNTIME_IMAGE=$RUNTIME_IMAGE_17")
      [[ -n "$WILDFLY_IMAGE_17" ]] && build_args+=(--build-arg "WILDFLY_IMAGE=$WILDFLY_IMAGE_17")
      ;;
    21|23)
      [[ -n "$BUILDER_IMAGE_21" ]] && build_args+=(--build-arg "BUILDER_IMAGE=$BUILDER_IMAGE_21")
      [[ -n "$RUNTIME_IMAGE_21" ]] && build_args+=(--build-arg "RUNTIME_IMAGE=$RUNTIME_IMAGE_21")
      [[ -n "$WILDFLY_IMAGE_21" ]] && build_args+=(--build-arg "WILDFLY_IMAGE=$WILDFLY_IMAGE_21")
      ;;
  esac
  
  # Add Tomcat version if set
  [[ -n "$TOMCAT_VERSION" ]] && build_args+=(--build-arg "TOMCAT_VERSION=$TOMCAT_VERSION")
  
  # Build command
  podman build -f "Dockerfile.openjdk${version}" "${build_args[@]}" -t "${image}" .
  echo "  ✓ ${image}"
}

for SAMPLE in "${SAMPLES[@]}"; do
  echo "=== Building metrics-sample-${SAMPLE} ==="
  cd "metrics-sample-${SAMPLE}"
  
  for VERSION in "${VERSIONS[@]}"; do
    build_image "$SAMPLE" "$VERSION"
  done
  
  cd ..
  echo ""
done

echo "Build complete! Run ./scripts/push-all.sh to push images."
echo ""
echo "To override versions, set environment variables before running:"
echo "  BUILDER_IMAGE_17=registry.../openjdk-17:1.22 ./scripts/build-all.sh"
echo "  TOMCAT_VERSION=10.1.16 ./scripts/build-all.sh"
