#!/usr/bin/env bash
# Signature cases: who signed the image, and whether the signed digest is
# what actually runs.
set -euo pipefail

source "$(dirname "$0")/lib.sh"
setup_namespace
run="$(date +%s)"

echo "== release images"
good="$("$root/hack/release.sh" "sig-good-$run" 2>/dev/null)"
unsigned="$(SKIP_SIGN=1 "$root/hack/release.sh" "sig-unsigned-$run" 2>/dev/null)"
rogue="$(KEY_NAME=rogue "$root/hack/release.sh" "sig-rogue-$run" 2>/dev/null)"

# An unsigned image also lacks attestations, so whichever image policy
# answers first denies it. Every one of them names the missing lab-key proof.
echo "== cases"
expect_admitted signed "$good"
expect_denied unsigned "$unsigned" "signed by the lab key"
expect_denied rogue-key "$rogue" "signed by the lab key"

# Re-point a signed tag at an unsigned image. Kyverno resolves the tag at
# admission time and checks the digest it finds, so the swap is caught.
crane tag "localhost:${REGISTRY_PORT}/app@${unsigned#*@}" "sig-good-$run" >/dev/null 2>&1
expect_denied retagged "kind-registry:5000/app:sig-good-$run" "signed by the lab key"

# A signed tag is rewritten to the verified digest, so later tag moves
# cannot change what the pod runs.
pinned="$(admit pinned "$good")"
if [[ "$pinned" == *"@sha256:"* ]]; then
  echo "PASS  admitted image is pinned to a digest"
  passed=$((passed + 1))
else
  echo "FAIL  admitted image is not pinned: $pinned"
  failed=$((failed + 1))
fi

summary
