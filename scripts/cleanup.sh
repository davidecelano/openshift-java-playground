#!/bin/bash
# Clean up all deployed metrics samples

set -e

NAMESPACE="${NAMESPACE:-java-metrics-demo}"

echo "Cleaning up namespace: ${NAMESPACE}"
echo ""

read -p "Delete entire namespace? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
  oc delete project "${NAMESPACE}"
  echo "Namespace ${NAMESPACE} deleted."
else
  echo "Deleting individual resources..."
  SAMPLES=(undertow springboot tomcat wildfly)
  
  for SAMPLE in "${SAMPLES[@]}"; do
    echo "Deleting metrics-sample-${SAMPLE}..."
    cd "metrics-sample-${SAMPLE}"
    oc delete -f k8s/ --ignore-not-found=true -n "${NAMESPACE}"
    cd ..
  done
  
  echo "Cleanup complete."
fi
