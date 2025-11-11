#!/bin/bash
# Push all metrics samples to container registry

set -e

REGISTRY="${REGISTRY:-quay.io/yourorg}"
SAMPLES=(undertow springboot tomcat wildfly)
VERSIONS=(11 17 21 23)

echo "Pushing all metrics samples to ${REGISTRY}..."
echo ""

for SAMPLE in "${SAMPLES[@]}"; do
  for VERSION in "${VERSIONS[@]}"; do
    IMAGE="${REGISTRY}/metrics-${SAMPLE}:openjdk${VERSION}"
    echo "Pushing ${IMAGE}..."
    podman push "${IMAGE}"
    echo "  ✓ Pushed"
  done
done

echo ""
echo "All images pushed successfully!"
