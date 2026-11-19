#!/usr/bin/env bash
# Writes policies/lab/*.yaml to out/policies with the lab public key filled in
# at the placeholder's indentation.
# Prints the output directory.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pub="$("$root/hack/lab-keys.sh")"
out="$root/out/policies"
mkdir -p "$out"

for src in "$root"/policies/lab/*.yaml; do
  awk -v keyfile="$pub" '
    function emit(file, indent,   line) {
      while ((getline line < file) > 0) if (line != "") print indent line
      close(file)
    }
    /__LAB_PUBLIC_KEY__/ { emit(keyfile, substr($0, 1, index($0, "__") - 1)); next }
    { print }
  ' "$src" >"$out/$(basename "$src")"
done
echo "$out"
