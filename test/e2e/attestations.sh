#!/usr/bin/env bash
# Attestation cases: a valid signature is necessary but not sufficient. The
# image must also carry a signed SBOM and a recent, clean, signed scan.
set -euo pipefail

source "$(dirname "$0")/lib.sh"
setup_namespace
run="$(date +%s)"

echo "== release images"
good="$("$root/hack/release.sh" "att-good-$run" 2>/dev/null)"
no_attest="$(SKIP_ATTEST=1 "$root/hack/release.sh" "att-none-$run" 2>/dev/null)"
stale="$(STALE_SCAN=1 "$root/hack/release.sh" "att-stale-$run" 2>/dev/null)"
vulnerable="$(CONTEXT_DIR="$root/test/fixtures/vulnerable" IMAGE_NAME=vulnerable \
  "$root/hack/release.sh" "att-vuln-$run" 2>/dev/null)"

echo "== cases"
expect_admitted fully-attested "$good"
expect_denied signed-no-attestations "$no_attest" "attestation signed by the lab key"
expect_denied stale-scan "$stale" "older than 7 days"
expect_denied critical-vulns "$vulnerable" "reports CRITICAL vulnerabilities"

summary
