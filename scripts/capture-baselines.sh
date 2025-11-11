#!/bin/bash
# Capture JVM container awareness baseline for all running pods

set -e

NAMESPACE="${NAMESPACE:-java-metrics-demo}"
OUTPUT_DIR="./baseline-captures"

mkdir -p "${OUTPUT_DIR}"

echo "Capturing baselines from namespace: ${NAMESPACE}"
echo "Output directory: ${OUTPUT_DIR}"
echo ""

oc get pods -n "${NAMESPACE}" -o name | while read -r pod; do
  POD_NAME=$(basename "${pod}")
  echo "Capturing baseline for ${POD_NAME}..."
  
  OUTPUT_FILE="${OUTPUT_DIR}/${POD_NAME}-baseline.txt"
  
  oc exec -n "${NAMESPACE}" "${POD_NAME}" -- \
    java -Xlog:os+container=info -XX:+PrintFlagsFinal -version \
    > "${OUTPUT_FILE}" 2>&1 || true
  
  echo "  ✓ Saved to ${OUTPUT_FILE}"
done

echo ""
echo "Baseline capture complete!"
echo "Review files in ${OUTPUT_DIR}/"
