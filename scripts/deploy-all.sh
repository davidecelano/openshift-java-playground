#!/bin/bash
# Deploy all metrics samples to OpenShift

set -e

NAMESPACE="${NAMESPACE:-java-metrics-demo}"
SAMPLES=(undertow springboot tomcat wildfly)

echo "Deploying all metrics samples to namespace: ${NAMESPACE}"
echo ""

# Create namespace if it doesn't exist
oc new-project "${NAMESPACE}" 2>/dev/null || oc project "${NAMESPACE}"

for SAMPLE in "${SAMPLES[@]}"; do
  echo "=== Deploying metrics-sample-${SAMPLE} ==="
  cd "metrics-sample-${SAMPLE}"
  oc apply -f k8s/
  cd ..
  echo ""
done

echo "Deployment complete!"
echo ""
echo "Check status:"
echo "  oc get pods -n ${NAMESPACE}"
echo "  oc get svc -n ${NAMESPACE}"
echo "  oc get servicemonitor -n ${NAMESPACE}"
