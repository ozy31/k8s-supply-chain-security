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
| A compromised image tries to escalate | Non-root, read-only rootfs, drop ALL, no privileged, no host namespaces | `test/policies`, `test/e2e/hardening.sh` |
| Signing key theft | Production is keyless; certificates live ~10 minutes and are bound to the workflow | design |
| Signature backdating or silent key misuse | Every signature is in the public Rekor log and can be audited | design |

## Out of scope

- **A compromised release workflow.** If an attacker can run
  `release.yml` on a version tag, their image is signed like ours. Protect
  tags with rulesets and require review on the workflow file.
- **Vulnerabilities discovered after admission.** Running pods are not
  re-checked. A periodic rescan job or Kyverno background reports would
  cover this.
- **Images outside the matched registries.** Policies match
  `kind-registry:5000/*` and the GHCR repository. A registry allowlist
  policy would close the gap for everything else.
- **Kyverno availability.** `failurePolicy: Fail` means pods are refused
  when Kyverno is down. That is the intended trade-off; run three replicas
  in production.
