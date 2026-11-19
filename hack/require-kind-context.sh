#!/usr/bin/env bash
# Every script that talks to a cluster sources this first. It pins kubectl
# and helm to the kind context so nothing ever lands on whatever cluster the
# current-context happens to point at (Docker Desktop likes to grab it).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/versions.env"

# Capture first: `grep -q` exits early and pipefail would report SIGPIPE.
contexts="$(kubectl config get-contexts -o name)"
if ! grep -qx "$KUBE_CONTEXT" <<<"$contexts"; then
  echo "context $KUBE_CONTEXT not found; run 'make cluster' first" >&2
  exit 1
fi

kc() { kubectl --context "$KUBE_CONTEXT" "$@"; }
hc() { helm --kube-context "$KUBE_CONTEXT" "$@"; }
