# Phase 7 — AWS Backup + DataSync

## AWS Backup
| Item | Value |
|---|---|
| Vaults | `storage-lab-vault` (us-east-1), `storage-lab-vault-dr` (us-west-2) |
| Role | `storage-lab-backup` (AWS managed: ...ForBackup + ...ForRestores) |
| Plan | `storage-lab-daily`: `cron(0 0 * * ? *)` (03:00 Riyadh), keep 7 days, copy to us-west-2 (keep 7 days) |
| Selection | EFS file systems + EBS volumes **AND** tag `Project=storage-lab` (`Resources` + `Conditions` = AND; `ListOfTags` would be OR) |

### Restore drill
1. On-demand EFS backup → recovery point COMPLETED.
2. Deleted `from-b.txt` on EFS ("disaster").
3. `start-restore-job` with `newFileSystem=false` → files restored into `aws-backup-restore_<timestamp>/` (never overwrites live data).
4. Copied `from-b.txt` back. A backup you never restored is not a backup.

## DataSync (S3 → EFS)
- Source: `s3://<bucket>/uploads` via read-only role `storage-lab-datasync` (+ kms:Decrypt).
- Destination: EFS `/from-s3`, ENI in the app subnet with the **EC2 SG** → existing NFS rule applies. TLS 1.2 in transit.
- Excluded `/glacier-demo.txt` (archived objects can't be read).
- Result: SUCCESS, 17 items (16 files + root dir), ~55 MB, checksum-verified.

## Lessons learned
- DataSync does **not** create the EFS subdirectory → `x40016 Could not mount subdirectory`. Create it first.
- Read `Result.ErrorDetail` before re-running a failed execution.
- `list-*` results are not guaranteed to be ordered — filter by condition, don't use `[-1]`.

## Exam map
- Central, policy-based backups across services → AWS Backup. Immutable backups → Backup Vault Lock.
- Online, scheduled transfer on-prem/AWS ↔ S3/EFS/FSx → DataSync. Huge data + slow link → Snowball.
- On-prem apps keep using NFS/SMB/iSCSI backed by S3 → Storage Gateway. SFTP into S3 → Transfer Family.

## Verify
`./tests/verify-phase-07.sh` — 8 checks.
