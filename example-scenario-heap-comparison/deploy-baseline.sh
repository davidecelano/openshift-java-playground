#!/bin/bash
# Deploy heap comparison scenario

set -e

NAMESPACE="${NAMESPACE:-java-metrics-demo}"
VERSIONS=(11 17 21 23)

echo "Deploying heap comparison scenario to ${NAMESPACE}"
echo ""

oc project "${NAMESPACE}" || oc new-project "${NAMESPACE}"

echo "=== Deploying baseline configurations ==="
for VERSION in "${VERSIONS[@]}"; do
  echo "Deploying OpenJDK ${VERSION} (baseline)..."
  sed "s/VERSION/${VERSION}/g" baseline-deployment.yaml | oc apply -f -
done

echo ""
echo "Waiting 60 seconds for pods to stabilize..."
sleep 60

echo ""
echo "Baseline deployed. Pods:"
oc get pods -l scenario=heap-comparison

echo ""
echo "To deploy tuned configuration after capturing baseline:"
echo "  ./deploy-tuned.sh"
