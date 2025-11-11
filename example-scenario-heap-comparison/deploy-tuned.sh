#!/bin/bash
# Deploy tuned heap configurations

set -e

NAMESPACE="${NAMESPACE:-java-metrics-demo}"
VERSIONS=(11 17 21 23)

echo "Deploying tuned heap configurations to ${NAMESPACE}"
echo ""

oc project "${NAMESPACE}"

echo "=== Deploying tuned configurations ==="
for VERSION in "${VERSIONS[@]}"; do
  echo "Deploying OpenJDK ${VERSION} (tuned)..."
  sed "s/VERSION/${VERSION}/g" tuned-deployment.yaml | oc apply -f -
done

echo ""
echo "Waiting 60 seconds for pods to stabilize..."
sleep 60

echo ""
echo "Tuned deployed. Pods:"
oc get pods -l scenario=heap-comparison

echo ""
echo "Capture results with:"
echo "  ../scripts/capture-baselines.sh"
