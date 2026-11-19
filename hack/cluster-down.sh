#!/usr/bin/env bash
# Deletes the kind cluster and the local registry. Touches nothing else.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
source "$root/versions.env"

kind delete cluster --name "$CLUSTER_NAME"
docker rm -f kind-registry >/dev/null 2>&1 || true
