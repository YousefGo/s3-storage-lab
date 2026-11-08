
# ADR-003: Encrypt EBS with the AWS managed key (aws/ebs)

**Status:** Accepted
**Date:** 5-11-2026

## Context

The data volume was created unencrypted. EBS cannot encrypt a volume in place,
and the project needs data at rest to be encrypted, including the DR copy in
another region.

## Decision

- Encrypt the existing data by: snapshot → copy with `--encrypted` →
  new volume from the encrypted snapshot → swap the volumes.
- Use the AWS managed key `aws/ebs`.
- Enable EBS encryption by default in the region so new volumes are always encrypted.

## Alternatives considered

- **Customer managed KMS key (CMK):** custom key policy, cross-account sharing,
  controlled rotation and deletion. Rejected for now: extra cost and management
  with no extra requirement in this phase.
- **Keep the volume unencrypted:** rejected; fails basic security requirements.

## Consequences

- ✅ Data, snapshots, and the DR copy are encrypted with no app changes.
- ✅ Encryption by default prevents future unencrypted volumes.
- ⚠️ `aws/ebs` snapshots cannot be shared with other accounts; that would need a CMK.
- ⚠️ The swap needed a short downtime (unmount → detach → attach → mount).
- ⚠️ KMS keys are regional, so the cross-region copy is re-encrypted with the target region's key.
