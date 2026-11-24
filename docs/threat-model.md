# Threat model

What this setup stops, what it does not, and where the trust sits.

## Assets

- The cluster: anything admitted runs with the permissions of its pod.
- The release pipeline identity: whoever can sign as it can ship code.

## Threats and controls

| Threat | Control | Verified by |
| --- | --- | --- |
| Someone pushes an image straight to the registry | Signature required at admission | `test/e2e/signatures.sh` unsigned |
| Attacker signs with their own key | Only the lab key / release workflow identity is trusted | rogue-key case |
| A signed tag is moved to a malicious image | Kyverno resolves the tag at admission and verifies that digest; the pod is pinned to it | retagged case, pinned check |
| An image is signed but never scanned | Signed scan attestation required | signed-no-attestations case |
| A clean scan from months ago vouches for an image that is now vulnerable | Scan must be less than 7 days old | stale-scan case |
| The scanner silently found no packages (wrong input, broken scan) | Empty scan results are refused | policy rule, see ADR 0003 |
| A known CRITICAL CVE ships | Refused at admission, and the release workflow fails before signing | critical-vulns case |
| An image from an unmatched registry skips signature checks | Registry allowlist in enforced namespaces, prefix-matched so look-alike repositories fail | `test/policies/registries` |
| One pod exhausts node memory | Memory limit required | `test/policies/hardening` |
| A compromised image tries to escalate | Non-root, read-only rootfs, drop ALL, no privileged, no host namespaces | `test/policies`, `test/e2e/hardening.sh` |
| A container uses unfiltered syscalls to attack the kernel | RuntimeDefault or Localhost seccomp profile required | `test/policies/hardening` |
| A pod reads node files or binds node ports | hostPath volumes and hostPort refused | `test/policies/hardening` |
| A pod reads host details through /proc or changes node-wide kernel settings | `procMount: Default` and safe sysctls only | `test/policies/hardening` |
| A compromised pod uses its service account token against the API server | No token on the default account; API access needs a dedicated account with visible RBAC | `default-sa-token` fixture |
| A policy rule silently stops refusing anything | Every common policy must have pass and fail cases | `hack/check-policy-tests.sh` |
| An untagged image slips past the tag rule because its registry has a port | Tag is read from the last path segment only | `untagged-with-port` fixture |
| Signing key theft | Production is keyless; certificates live ~10 minutes and are bound to the workflow | design |
| Signature backdating or silent key misuse | Every signature is in the public Rekor log and can be audited | design |

## Out of scope

- **A compromised release workflow.** If an attacker can run
  `release.yml` on a version tag, their image is signed like ours. Protect
  tags with rulesets and require review on the workflow file.
- **Vulnerabilities discovered after admission.** Running pods are not
  re-checked by Kyverno. The weekly rescan workflow reports CRITICAL CVEs in
  the newest releases, but it does not evict anything; acting on it is a
  release, not an automatic rollback.
- **Namespaces without the enforce label.** The allowlist and hardening
  baseline apply only where `supply-chain.lab/enforce=true` is set. A
  namespace that is created without it gets image verification for matched
  registries only.
- **Kyverno availability.** `failurePolicy: Fail` means pods are refused
  when Kyverno is down. That is the intended trade-off; run three replicas
  in production.
