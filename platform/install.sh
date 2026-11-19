#!/usr/bin/env bash
# Installs Kyverno at the pinned chart version into the kind cluster.
set -euo pipefail

source "$(dirname "$0")/../hack/require-kind-context.sh"

hc repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
hc repo update kyverno >/dev/null
hc upgrade --install kyverno kyverno/kyverno \
  --version "$KYVERNO_CHART_VERSION" \
  --namespace kyverno --create-namespace \
  --values "$root/platform/kyverno-values.yaml" \
  --wait --timeout 5m

kc -n kyverno rollout status deploy/kyverno-admission-controller --timeout 180s
echo "kyverno $(kc -n kyverno get deploy kyverno-admission-controller -o jsonpath='{.spec.template.spec.containers[0].image}')"
