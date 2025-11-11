#!/bin/bash
# Build all metrics samples across all OpenJDK versions

set -e

REGISTRY="${REGISTRY:-quay.io/yourorg}"
SAMPLES=(undertow springboot tomcat wildfly)
VERSIONS=(11 17 21 23)

echo "Building all metrics samples..."
echo "Registry: ${REGISTRY}"
echo ""

for SAMPLE in "${SAMPLES[@]}"; do
  echo "=== Building metrics-sample-${SAMPLE} ==="
  cd "metrics-sample-${SAMPLE}"
  
  for VERSION in "${VERSIONS[@]}"; do
    IMAGE="${REGISTRY}/metrics-${SAMPLE}:openjdk${VERSION}"
    echo "  Building ${IMAGE}..."
    podman build -f Dockerfile.openjdk${VERSION} -t "${IMAGE}" .
    echo "  ✓ ${IMAGE}"
  done
  
  cd ..
  echo ""
done

echo "Build complete! Run ./scripts/push-all.sh to push images."
