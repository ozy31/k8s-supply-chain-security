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
"$root/hack/lab-keys.sh" >/dev/null
key="$root/out/keys/cosign.key"
export COSIGN_PASSWORD=""

# Cosign 3 writes Sigstore bundles by default. Kyverno 1.20 resolves the
# classic .sig/.att tags, and the lab has no transparency log, so use those.
cosign_flags=(--key "$key" --new-bundle-format=false --use-signing-config=false --tlog-upload=false -y)

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
# Scan the SBOM rather than the image again: one inventory, two consumers.
trivy sbom --quiet --format cosign-vuln --output "$work/vuln.json" "$work/sbom.spdx.json"
trivy sbom --quiet --format table --severity HIGH,CRITICAL "$work/sbom.spdx.json" >&2 || true

log "sign"
cosign sign "${cosign_flags[@]}" "$ref" 2>/dev/null

if [[ -z "${SKIP_ATTEST:-}" ]]; then
  log "attest sbom + vuln"
  cosign attest "${cosign_flags[@]}" --type spdxjson --predicate "$work/sbom.spdx.json" "$ref" 2>/dev/null
  cosign attest "${cosign_flags[@]}" --type vuln --predicate "$work/vuln.json" "$ref" 2>/dev/null
fi

echo "$cluster_repo@$digest"
