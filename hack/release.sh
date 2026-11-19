#!/usr/bin/env bash
# Local equivalent of the CI release pipeline:
#
#   build -> push -> SBOM (syft) -> vulnerability scan (trivy)
#         -> sign (cosign) -> attest SBOM -> attest scan result
#
# Everything is addressed by digest, never by tag, so what was scanned is
# exactly what gets signed and later admitted.
#
#   hack/release.sh <tag>            build app/ and release it
#   SKIP_SIGN=1 hack/release.sh <t>  push without signing (for negative tests)
#   SKIP_ATTEST=1 ...                sign but skip both attestations
#   KEY_NAME=rogue ...               sign with a different lab key pair
#   STALE_SCAN=1 ...                 backdate the scan by 30 days (e2e only)
#
# Prints the in-cluster image reference (kind-registry:5000/app@sha256:...).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
source "$root/versions.env"

tag="${1:?usage: release.sh <tag>}"
context_dir="${CONTEXT_DIR:-$root/app}"
repo="localhost:${REGISTRY_PORT}/${IMAGE_NAME:-app}"
cluster_repo="kind-registry:5000/${IMAGE_NAME:-app}"
work="$root/out/release/$tag"
mkdir -p "$work"

# The lab signs with a local key pair. In CI the same steps run keyless
# with the workflow's OIDC identity (see .github/workflows/release.yml).
key_name="${KEY_NAME:-cosign}"
"$root/hack/lab-keys.sh" "$key_name" >/dev/null
key="$root/out/keys/$key_name.key"
export COSIGN_PASSWORD=""

# Signatures and attestations are recorded in the public Sigstore
# transparency log (Rekor). Kyverno requires a log entry before it trusts a
# key-signed attestation. The entry holds the image digest, the signature and
# the lab public key; nothing else about the image or the repo.
#
# Classic .sig/.att tags instead of Sigstore bundles: bundles are discovered
# through the OCI referrers API, which the lab registry (distribution v3)
# does not serve.
cosign_flags=(--key "$key" --new-bundle-format=false --use-signing-config=false -y)

log() { echo "==> $*" >&2; }

log "build $repo:$tag"
docker build -q \
  --build-arg VERSION="$tag" \
  --build-arg COMMIT="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo unknown)" \
  -t "$repo:$tag" "$context_dir" >/dev/null
docker push -q "$repo:$tag" >/dev/null
digest="$(crane digest "$repo:$tag")"
ref="$repo@$digest"
log "pushed $ref"

if [[ -n "${SKIP_SIGN:-}" ]]; then
  echo "$cluster_repo@$digest"
  exit 0
fi

log "sbom"
syft scan "registry:$ref" -o spdx-json="$work/sbom.spdx.json" -q

log "scan"
# Scan the image itself, not the SBOM: Trivy needs the OS release files to
# match distro packages, and an SPDX document does not carry them.
trivy image --quiet --format cosign-vuln --output "$work/vuln.json" "$ref"
trivy convert --quiet --format table --severity HIGH,CRITICAL "$work/vuln.json" >&2 2>/dev/null || true

if [[ -n "${STALE_SCAN:-}" ]]; then
  old="$(date -u -v-30d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ)"
  jq --arg t "$old" '.metadata.scanStartedOn = $t | .metadata.scanFinishedOn = $t' \
    "$work/vuln.json" >"$work/vuln.stale.json"
  mv "$work/vuln.stale.json" "$work/vuln.json"
fi

log "sign"
cosign sign "${cosign_flags[@]}" "$ref" 2>/dev/null

if [[ -z "${SKIP_ATTEST:-}" ]]; then
  log "attest sbom + vuln"
  cosign attest "${cosign_flags[@]}" --type spdxjson --predicate "$work/sbom.spdx.json" "$ref" 2>/dev/null
  cosign attest "${cosign_flags[@]}" --type vuln --predicate "$work/vuln.json" "$ref" 2>/dev/null
fi

echo "$cluster_repo@$digest"
