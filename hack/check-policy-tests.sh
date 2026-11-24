#!/usr/bin/env bash
# Fails when a common policy has no offline test, or when a test only
# proves one direction. A policy that is never shown to refuse something
# may be refusing nothing; one never shown to admit may block everything.
#
# Image policies (policies/lab, policies/github) need signatures and a
# registry, so they are covered by test/e2e instead.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
status=0

for policy in policies/common/*.yaml; do
  name="$(basename "$policy")"
  tests="$(grep -l "policies/common/$name" test/policies/*/kyverno-test.yaml || true)"
  if [[ -z "$tests" ]]; then
    echo "MISSING  $policy has no test in test/policies/*/kyverno-test.yaml"
    status=1
    continue
  fi
  for test in $tests; do
    for result in pass fail; do
      if ! grep -qE "^ *result: $result\$" "$test"; then
        echo "ONE-SIDED  $test never expects '$result' for $name"
        status=1
      fi
    done
  done
done

[[ $status -eq 0 ]] && echo "every common policy has pass and fail cases"
exit "$status"
