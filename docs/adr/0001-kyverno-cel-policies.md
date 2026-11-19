# 1. Kyverno CEL policy types

## Status

Accepted

## Context

Kyverno 1.20 no longer executes or accepts new `kyverno.io/v1`
ClusterPolicy resources. The replacements are the CEL-based types in
`policies.kyverno.io/v1`.

## Decision

Use `ImageValidatingPolicy` for signature and attestation checks and
`ValidatingPolicy` for pod hardening. Both are written in CEL, the same
language as Kubernetes ValidatingAdmissionPolicy.

## Consequences

- One expression language for Kyverno and native admission policies.
- Kyverno autogenerates the same rules for Deployments, StatefulSets, Jobs
  and CronJobs, so a bad image is refused when the Deployment is applied, not
  later when its ReplicaSet fails to create pods.
- Blog posts and examples that use `verifyImages` in ClusterPolicy no longer
  apply.
