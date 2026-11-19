#!/usr/bin/env bash
# Renders and applies every policy, then waits until Kyverno reports each
# one ready, so tests never race a webhook that is not configured yet.
set -euo pipefail

source "$(dirname "$0")/require-kind-context.sh"

rendered="$("$root/hack/render-policies.sh")"
kc apply -f "$rendered"
[[ -d "$root/policies/common" ]] && kc apply -f "$root/policies/common"

for kind in imagevalidatingpolicies validatingpolicies; do
  for name in $(kc get "$kind" -o name 2>/dev/null); do
    kc wait "$name" --for=jsonpath='{.status.conditionStatus.ready}'=true --timeout=90s >/dev/null
    echo "ready: $name"
  done
done
