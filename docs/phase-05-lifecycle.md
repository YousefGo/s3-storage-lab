# Phase 5 — Lifecycle, Intelligent-Tiering, Replication, Object Lock

## What was built
| Feature | Config | File |
|---|---|---|
| Lifecycle `uploads-tiering` | uploads/: Standard-IA @30d → Glacier @90d → expire @365d; noncurrent expire 30d; abort MPU 7d | `infra/s3/lifecycle.json` |
| Intelligent-Tiering | `reports/report.png` uploaded with `--storage-class INTELLIGENT_TIERING` | — |
| CRR us-east-1 → us-west-2 | prefix uploads/, SSE-KMS objects re-encrypted with replica-region CMK, delete markers NOT replicated | `infra/s3/replication.json`, `infra/iam/replication-*.json` |
| Batch Replication | S3 Batch Operations `S3ReplicateObject`, generated manifest (NONE/FAILED) | `infra/s3/batch/*.json`, `infra/iam/batch-*.json` |
| Object Lock | separate bucket, default GOVERNANCE 1 day | `storage-lab-locked-<account>` |

## Results
- New object: `PENDING` → `COMPLETED` (source), `REPLICA` + us-west-2 key (destination).
- `rm` on source created a delete marker; replica stayed intact.
- Batch job: 20 tasks / 20 succeeded / 0 failed (all versions, not just current).
- `glacier-demo.txt` (GLACIER class) was silently excluded from the manifest — found only by diffing key lists (17 vs 16).
- Object Lock: `delete-object --version-id` → AccessDenied; `--bypass-governance-retention` succeeded as admin; Legal Hold blocked deletion even with bypass.

## Lessons learned
- zsh `$VAR:r` is a modifier (strips extension): `$ACCOUNT:role` became `...576ole`. Use `${ACCOUNT}:role`.
- KMS: an IAM policy alone is not enough — the key policy must allow it (root "Enable IAM User Permissions" statement).
- "0 failed" is not proof of completeness — count and diff.
- Governance can be bypassed by any admin → use Compliance against ransomware / regulators.

## Verify
`./tests/verify-phase-05.sh` — 8 checks. Note: "invoice version is locked" fails after the 1-day retention expires (expected).

## Cost
Second KMS key: $1/month. Batch job: ~$0.25. Replication: per-request + inter-region transfer.
