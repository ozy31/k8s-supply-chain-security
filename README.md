# k8s-supply-chain-security

Only images that were built, scanned and signed by our own pipeline get to
run. Kyverno checks every pod at admission and refuses anything it cannot
verify.

```
build ─► push ─► SBOM (syft) ─► scan (trivy) ─► sign (cosign) ─► attest SBOM + scan
                                                      │
                                    Rekor transparency log
                                                      │
kubectl apply ─► Kyverno ImageValidatingPolicy ───────┘
                   ├─ signature from the trusted key / workflow identity
                   ├─ signed SPDX SBOM with packages in it
                   ├─ signed scan: not empty, < 7 days old, no CRITICAL
                   └─ tag resolved and pinned to the verified digest
                 Kyverno ValidatingPolicy
                   ├─ images only from the lab registry or this repo's GHCR path
                   └─ non-root, read-only rootfs, drop ALL, seccomp, memory limit,
                      no privilege, no host namespaces, hostPath or hostPort
```

Everything runs locally on kind, and the e2e suite proves each rule with a
real image, not only a policy unit test.

## What gets refused

| Case | How the test builds it | Refused by |
| --- | --- | --- |
| Unsigned image | `SKIP_SIGN=1 hack/release.sh` | require-signature |
| Signed with another key | `KEY_NAME=rogue hack/release.sh` | require-signature |
| Signed tag re-pointed at an unsigned image | `crane tag` after signing | require-signature (digest resolved at admission) |
| Signed, no attestations | `SKIP_ATTEST=1 hack/release.sh` | require-sbom, deny-critical-vulnerabilities |
| Scan older than 7 days | `STALE_SCAN=1 hack/release.sh` | deny-critical-vulnerabilities |
| Signed and attested, but CRITICAL CVEs | `test/fixtures/vulnerable` (alpine 3.10.0) | deny-critical-vulnerabilities |
| Root container in an enforced namespace | `kubectl run` without securityContext | pod-hardening |
| Image from Docker Hub or a look-alike GHCR path | offline fixture | allowed-registries |
| Container without a memory limit | offline fixture | pod-hardening |
| No seccomp profile, or `Unconfined` on one container | offline fixture | pod-hardening |
| hostPath volume or hostPort | offline fixture | pod-hardening |
| `kind-registry:5000/app` with no tag (the port is not a tag) | offline fixture | pod-hardening |

Admitted pods are rewritten from `app:v1.2.3` to `app:v1.2.3@sha256:…`, so
moving a tag later cannot change what runs.

## Run it

Requirements: Docker, kind, kubectl, helm, cosign 3, syft, trivy, crane,
kyverno CLI 1.20, Go.

```bash
make up               # kind + local registry + Kyverno 1.20 + policies
make test-policies    # 20 offline Kyverno CLI cases (no cluster)
make e2e              # 12 admission cases against the live webhooks
make down
```

Every script pins `kubectl --context kind-supply-chain` and
`helm --kube-context kind-supply-chain`, so nothing can land on another
cluster even when Docker Desktop changes the current context.

## Lab vs production

| | Lab (`policies/lab`) | Production (`policies/github`) |
| --- | --- | --- |
| Signer | cosign key pair generated under `out/keys` (git-ignored) | Keyless: Fulcio certificate for the release workflow's OIDC identity |
| Trust anchor | Lab public key, injected at render time | `issuer` + `subjectRegExp` for `release.yml` on a `vX.Y.Z` tag |
| Registry | `registry:3` on the kind network | GHCR |
| Provenance | none | SLSA v1 from `actions/attest-build-provenance` |
| Pipeline | `hack/release.sh` | `.github/workflows/release.yml` |

The lab path is covered end to end by the e2e tests. The production policy
is validated by the API server (`kubectl apply --dry-run=server`), but it is
not exercised against a real GHCR release yet.

## After admission

Admission checks an image once. `.github/workflows/rescan.yml` rescans the
three newest releases every Monday with a fresh vulnerability database and
fails on a CRITICAL finding. Because the policy refuses scans older than 7
days, a release has to be re-released (new scan, new attestation) at least
weekly to keep scheduling; the rescan says early whether that release will
come out clean.

## Transparency log

Signatures and attestations, from the lab included, are recorded in the
public Sigstore Rekor log. Kyverno 1.20 only trusts a key-signed attestation
when it has a verified log entry (see [ADR 0002](docs/adr/0002-rekor-for-lab-signatures.md)).
An entry holds the image digest, the signature and the public key of a
throwaway lab key pair. It contains no source code, SBOM content or
credentials.

## Layout

```
app/                      sample Go service, distroless, non-root
hack/release.sh           build → SBOM → scan → sign → attest, by digest
hack/cluster-up.sh        kind + registry wired for in-cluster pulls
policies/lab/             key-based image policies (rendered with the lab key)
policies/github/          keyless image policy for GHCR releases
policies/common/          registry allowlist and pod hardening ValidatingPolicies
test/policies/            offline `kyverno test` cases, one directory per policy
test/e2e/                 live admission tests
docs/                     threat model, ADRs
```

## License

MIT
