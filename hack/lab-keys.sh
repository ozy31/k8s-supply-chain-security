#!/usr/bin/env bash
# Creates the lab signing key pair once, under out/keys (git-ignored).
# The private key never leaves this machine; policies get the public key.
#
#   hack/lab-keys.sh            create if missing, print the public key path
#   hack/lab-keys.sh rogue      a second pair, used to prove that a valid
#                               signature from the wrong key is rejected
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
name="${1:-cosign}"
dir="$root/out/keys"
mkdir -p "$dir"

if [[ ! -f "$dir/$name.key" ]]; then
  (
    cd "$dir"
    COSIGN_PASSWORD="" cosign generate-key-pair --output-key-prefix "$name" >/dev/null 2>&1
  )
fi
echo "$dir/$name.pub"
