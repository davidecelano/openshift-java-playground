#!/bin/bash
# Quick verification that repository structure is complete

set -e

echo "Verifying OpenShift Java Playground repository structure..."
echo ""

ERRORS=0

# Check directories
DIRS=(
  "metrics-sample-undertow"
  "metrics-sample-springboot"
  "metrics-sample-tomcat"
  "metrics-sample-wildfly"
  "example-scenario-heap-comparison"
  "scripts"
  ".github/workflows"
)

for DIR in "${DIRS[@]}"; do
  if [ -d "${DIR}" ]; then
    echo "✓ Directory exists: ${DIR}"
  else
    echo "✗ Missing directory: ${DIR}"
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""

# Check key files
FILES=(
  "README.md"
  "DEPLOYMENT.md"


  ".github/workflows/build-metrics-samples.yml"
  "scripts/build-all.sh"
  "scripts/push-all.sh"
  "scripts/deploy-all.sh"
)

for FILE in "${FILES[@]}"; do
  if [ -f "${FILE}" ]; then
    echo "✓ File exists: ${FILE}"
  else
    echo "✗ Missing file: ${FILE}"
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""

# Check sample completeness
SAMPLES=(undertow springboot tomcat wildfly)
for SAMPLE in "${SAMPLES[@]}"; do
  DIR="metrics-sample-${SAMPLE}"
  echo "Checking ${DIR}..."
  
  SAMPLE_FILES=(
    "${DIR}/pom.xml"
    "${DIR}/README.md"
    "${DIR}/Dockerfile.openjdk11"
    "${DIR}/Dockerfile.openjdk17"
    "${DIR}/Dockerfile.openjdk21"
    "${DIR}/Dockerfile.openjdk23"
    "${DIR}/k8s/service.yaml"
    "${DIR}/k8s/servicemonitor.yaml"
  )
  
  for FILE in "${SAMPLE_FILES[@]}"; do
    if [ -f "${FILE}" ]; then
      echo "  ✓ ${FILE}"
    else
      echo "  ✗ Missing: ${FILE}"
      ERRORS=$((ERRORS + 1))
    fi
  done
done

echo ""

if [ ${ERRORS} -eq 0 ]; then
  echo "✓ Repository structure is complete!"
  echo ""
  echo "Next steps:"
  echo "  1. Update image references: ./scripts/update-image-refs.sh quay.io/yourorg"
  echo "  2. Build samples: REGISTRY=quay.io/yourorg ./scripts/build-all.sh"
  echo "  3. Push images: REGISTRY=quay.io/yourorg ./scripts/push-all.sh"
  echo "  4. Deploy: ./scripts/deploy-all.sh"
  exit 0
else
  echo "✗ Found ${ERRORS} issue(s). Please review."
  exit 1
fi
