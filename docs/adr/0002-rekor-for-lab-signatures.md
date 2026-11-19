# 2. Record lab signatures in the public Rekor log

## Status

Accepted

## Context

The first version of the lab was fully offline: key-based signatures with
`--tlog-upload=false` and `insecureIgnoreTlog: true` in the policies.
Signature checks worked, but every attestation was refused. Kyverno 1.20
only accepts a key-signed attestation when its signing time is proven,
either by a Rekor entry or by an RFC 3161 timestamp:

- Classic `.att` attestations without a log entry fail with
  `cosign bundle verification failed`.
- Adding a timestamp from a local Sigstore TSA to a classic attestation
  fails in cosign 3 itself (`hashed messages don't match`).
- Sigstore bundles with a local TSA verify with the cosign CLI, but Kyverno
  skips loading trust material for key-based attestors when the tlog is
  ignored, so the timestamp cannot be checked.

## Decision

Upload lab signatures and attestations to the public Sigstore Rekor
instance and keep the classic `.sig`/`.att` format. Policies point
`ctlog.url` at `https://rekor.sigstore.dev` and only ignore the SCT, which
key-based signing does not have.

Classic tags rather than bundles because bundles are discovered through
the OCI referrers API, which the lab registry (distribution v3) does not
serve.

## Consequences

- The lab exercises the same Rekor verification as the keyless production
  path.
- Each e2e run adds public log entries containing image digests,
  signatures and the throwaway lab public key. Nothing else is published.
- The e2e tests need internet access, both for uploads and for Kyverno to
  fetch the Sigstore trust root.
- Revisit when Kyverno verifies key-based bundles with a custom trusted
  root, which would allow a fully offline lab with a local TSA.
