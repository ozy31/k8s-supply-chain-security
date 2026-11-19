# 3. Scan the image, not the SBOM, and refuse empty scans

## Status

Accepted

## Context

The pipeline first scanned the SPDX SBOM produced by syft, so that one
inventory fed both attestations. On the deliberately vulnerable fixture
(alpine 3.10.0, three CRITICAL CVEs) the scan came back with no results at
all. The SPDX document does not carry the OS release information Trivy
uses to match distro packages, so Trivy reported nothing, and the policy,
which only looked for CRITICAL findings, admitted the image.

## Decision

- Trivy scans the image by digest. The SBOM is still produced and attested
  separately.
- The policy refuses a scan attestation whose result list is empty.

## Consequences

- The e2e test with the vulnerable fixture fails if this regresses.
- A truly empty image (scratch with a static binary and no metadata) needs
  an explicit exception. That is preferable to letting a broken scan read
  as a clean one.
