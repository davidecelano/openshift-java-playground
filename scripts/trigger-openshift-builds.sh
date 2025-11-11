#!/bin/bash
set -e

# Always resolve paths from repo root, regardless of CWD
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."

NAMESPACE="${NAMESPACE:-java-metrics-demo}"
RUNTIME="${1:-all}"
JAVA_VERSION="${2:-all}"

echo "🏗️  OpenShift Build Trigger Script"
echo "Namespace: $NAMESPACE"
echo "Runtime: $RUNTIME"
echo "Java Version: $JAVA_VERSION"
echo

# Ensure namespace exists
if ! oc get namespace "$NAMESPACE" &>/dev/null; then
  echo "Creating namespace $NAMESPACE..."
  oc create namespace "$NAMESPACE"
fi

# Array of runtimes
RUNTIMES=("undertow" "springboot" "tomcat" "wildfly")
VERSIONS=("11" "17" "21" "23")

# Filter runtimes
if [ "$RUNTIME" != "all" ]; then
  RUNTIMES=("$RUNTIME")
fi

# Filter versions
if [ "$JAVA_VERSION" != "all" ]; then
  VERSIONS=("$JAVA_VERSION")
fi

# Function to create ImageStream if not exists
create_imagestream() {
  local runtime=$1
  local sample_dir="metrics-sample-${runtime}"

  if ! oc get imagestream "metrics-${runtime}" -n "$NAMESPACE" &>/dev/null; then
    echo "📦 Creating ImageStream for ${runtime}..."
    oc apply -f "$REPO_ROOT/${sample_dir}/openshift/imagestream.yaml" -n "$NAMESPACE"
  fi
}

# Function to create and start BuildConfig
trigger_build() {
  local runtime=$1
  local version=$2
  local sample_dir="metrics-sample-${runtime}"
  local bc_name="metrics-${runtime}-openjdk${version}"

  echo "🔨 Processing ${bc_name}..."

  # Create/update BuildConfig
  if ! oc get buildconfig "$bc_name" -n "$NAMESPACE" &>/dev/null; then
    echo "   Creating BuildConfig..."
    oc apply -f "$REPO_ROOT/${sample_dir}/openshift/buildconfig-openjdk${version}.yaml" -n "$NAMESPACE"
  else
    echo "   BuildConfig exists, updating..."
    oc apply -f "$REPO_ROOT/${sample_dir}/openshift/buildconfig-openjdk${version}.yaml" -n "$NAMESPACE"
  fi

  # Start build
  echo "   Starting build..."
  oc start-build "$bc_name" -n "$NAMESPACE" --follow || echo "   ⚠️  Build may be running already"
  echo
}

# Main execution
for runtime in "${RUNTIMES[@]}"; do
  echo "==================================="
  echo "Runtime: ${runtime}"
  echo "==================================="

  create_imagestream "$runtime"

  for version in "${VERSIONS[@]}"; do
    trigger_build "$runtime" "$version"
  done

  echo
done

echo "✅ All builds triggered!"
echo
echo "Monitor builds:"
echo "  oc get builds -n $NAMESPACE"
echo
echo "Watch specific build:"
echo "  oc logs -f bc/metrics-undertow-openjdk17 -n $NAMESPACE"
echo
echo "List images:"
echo "  oc get imagestream -n $NAMESPACE"