#!/usr/bin/env bash
# Hardening cases against the live webhook (the offline CLI tests in
# test/policies cover the full matrix).
set -euo pipefail

source "$(dirname "$0")/lib.sh"
setup_namespace

image="$("$root/hack/release.sh" "hardening-$(date +%s)" 2>/dev/null)"

expect_admitted hardened "$image"

out="$(kc -n "$ns" run as-root --image="$image" --dry-run=server -o name 2>&1 || true)"
if grep -qF "runAsNonRoot=true" <<<"$out"; then
  echo "PASS  as-root denied: runAsNonRoot"
  passed=$((passed + 1))
else
  echo "FAIL  as-root: $out"
  failed=$((failed + 1))
fi

# Namespaces without the opt-in label are not subject to the baseline.
kc create namespace "$ns-optout" >/dev/null
out="$(kc -n "$ns-optout" run as-root --image="$image" --dry-run=server -o name 2>&1 || true)"
kc delete namespace "$ns-optout" --wait=false >/dev/null
if [[ "$out" == "pod/as-root" ]]; then
  echo "PASS  opt-out namespace is not enforced"
  passed=$((passed + 1))
else
  echo "FAIL  opt-out namespace: $out"
  failed=$((failed + 1))
fi

summary
