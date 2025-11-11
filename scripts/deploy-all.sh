#!/bin/bash
# Deploy all metrics samples to OpenShift

set -e

# Allow dynamic namespace via NAMESPACE env var, default to java-metrics-demo
NAMESPACE="${NAMESPACE:-java-metrics-demo}"
SAMPLES=(undertow springboot tomcat wildfly)

echo "Deploying all metrics samples to namespace: ${NAMESPACE}"
echo ""

# Create namespace if it doesn't exist
oc get project "${NAMESPACE}" >/dev/null 2>&1 || oc new-project "${NAMESPACE}"

for SAMPLE in "${SAMPLES[@]}"; do
  echo "=== Deploying metrics-sample-${SAMPLE} ==="
  cd "metrics-sample-${SAMPLE}"
  oc apply -n "${NAMESPACE}" -f k8s/
  cd ..
  echo ""
done

echo "Deployment complete!"
echo ""
echo "Check status:"
echo "  oc get pods -n ${NAMESPACE}"
echo "  oc get svc -n ${NAMESPACE}"
echo "  oc get servicemonitor -n ${NAMESPACE}"
