#!/usr/bin/env bash
# Writes policies/lab/*.yaml to out/policies with the lab public key filled
# in at the placeholder's indentation. Prints the output directory.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pub="${PUBLIC_KEY:-$("$root/hack/lab-keys.sh")}"
out="$root/out/policies"
mkdir -p "$out"

for src in "$root"/policies/lab/*.yaml; do
  awk -v keyfile="$pub" '
    /__LAB_PUBLIC_KEY__/ {
      indent = substr($0, 1, index($0, "__LAB_PUBLIC_KEY__") - 1)
      while ((getline line < keyfile) > 0) if (line != "") print indent line
      close(keyfile)
      next
    }
    { print }
  ' "$src" >"$out/$(basename "$src")"
done
echo "$out"
