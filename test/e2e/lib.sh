#!/usr/bin/env bash
# Shared helpers for the e2e tests. Admission is checked with server-side
# dry runs, so every case exercises the real webhooks without leaving pods.

source "$(dirname "${BASH_SOURCE[0]}")/../../hack/require-kind-context.sh"

passed=0
failed=0
ns=e2e-$$

setup_namespace() {
  kc create namespace "$ns" >/dev/null
  kc label namespace "$ns" supply-chain.lab/enforce=true >/dev/null
  trap 'kc delete namespace "$ns" --wait=false >/dev/null 2>&1 || true' EXIT
}

# A pod spec that satisfies the hardening policy, so a denial can only come
# from the image policies under test.
hardened_pod() {
  local name="$1" image="$2"
  cat <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: $name
  namespace: $ns
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: $image
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: [ALL]
YAML
}

admit() {
  hardened_pod "$1" "$2" | kc apply --dry-run=server -o jsonpath='{.spec.containers[0].image}' -f - 2>&1
}

expect_admitted() {
  local name="$1" image="$2" out
  if out="$(admit "$name" "$image")"; then
    echo "PASS  $name admitted as $out"
    passed=$((passed + 1))
  else
    echo "FAIL  $name was denied: $out"
    failed=$((failed + 1))
  fi
}

# expect_denied <name> <image> <substring the denial must contain>
expect_denied() {
  local name="$1" image="$2" reason="$3" out
  if out="$(admit "$name" "$image")"; then
    echo "FAIL  $name was admitted as $out"
    failed=$((failed + 1))
  elif grep -qF "$reason" <<<"$out"; then
    echo "PASS  $name denied: $reason"
    passed=$((passed + 1))
  else
    echo "FAIL  $name denied for the wrong reason: $out"
    failed=$((failed + 1))
  fi
}

summary() {
  echo "---"
  echo "$passed passed, $failed failed"
  [[ $failed -eq 0 ]]
}
