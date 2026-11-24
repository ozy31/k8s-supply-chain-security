# 4. A Kyverno baseline next to Pod Security Admission

## Status

Accepted

## Context

Kubernetes ships Pod Security Admission (PSA). The `restricted` level
already refuses root containers, privilege escalation, host namespaces,
hostPath, host ports, unmasked `/proc`, unsafe sysctls and missing seccomp
profiles. The demo namespace sets
`pod-security.kubernetes.io/enforce: restricted`.

So why repeat those rules in `policies/common/pod-hardening.yaml`?

## Decision

Keep PSA `restricted` on enforced namespaces, and keep the Kyverno baseline
as a superset of it:

| Rule | PSA restricted | Kyverno baseline |
| --- | --- | --- |
| Non-root, no escalation, drop ALL, seccomp | yes | yes |
| No host namespaces, hostPath, hostPort, unmasked /proc, unsafe sysctls | yes | yes |
| Read-only root filesystem | no | yes |
| Memory limit | no | yes |
| Explicit tag or digest, never `latest` | no | yes |
| No service account token on the default account | no | yes |
| Images only from allowed registries | no | yes (`allowed-registries`) |

Reasons for the overlap:

- **One place to read the baseline.** The policy file and its tests list
  everything a pod must satisfy, instead of half of it being implied by a
  namespace label.
- **It survives a missing label.** A namespace created without the PSA
  label gets `privileged` by default. The Kyverno baseline keys on
  `supply-chain.lab/enforce=true`, so either label alone still blocks the
  dangerous cases.
- **Messages that say what to fix.** Each Kyverno rule has its own message,
  which shows up in `kubectl` output and in CI.
- **The same test harness.** `kyverno test` proves every rule in both
  directions offline; PSA has no equivalent outside a cluster.

## Consequences

- A pod that breaks a shared rule is refused by both, with two messages.
  That is noise, not a problem.
- Changing the baseline means editing one policy and its tests; PSA does
  not need to change.
- `hack/check-policy-tests.sh` keeps every common policy covered by pass
  and fail cases, so the superset cannot quietly lose a rule.
