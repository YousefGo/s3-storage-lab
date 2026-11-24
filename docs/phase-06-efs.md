# Phase 6 — EFS (shared file system across AZs)

## What was built
| Item | Value |
|---|---|
| File system | `storage-lab-efs`, encrypted at rest (aws/elasticfilesystem), General Purpose, Elastic throughput |
| Mount targets | us-east-1c (app server AZ) + us-east-1b |
| Security group | `storage-lab-efs`: TCP 2049 **only from the EC2 SG** (no CIDR) |
| Mount | `amazon-efs-utils`, `-o tls` (stunnel → in-transit encryption), persistent via `/etc/fstab` with `_netdev` |
| Lifecycle | IA after 30 days → Archive after 90 days → back to Standard after 1 access |

## Proof of sharing
- Server A (us-east-1c) wrote `hello.txt`.
- Server B (us-east-1b), launched with user-data only (no SSH), mounted EFS, read `hello.txt` and wrote `from-b.txt`.
- Server A read `from-b.txt`. Server B was terminated — its file stayed (data lives in EFS, not on the instance).

## Observations
- `df -hT` shows `nfs4` and Size `8.0E` — no capacity to provision; billed per GB actually stored.
- Mount source shows `127.0.0.1:/` because TLS goes through a local stunnel proxy.
- Without `/etc/fstab` the mount is lost on stop/start.

## EBS vs EFS
| | EBS | EFS |
|---|---|---|
| Attach | 1 instance (io2 Multi-Attach aside) | thousands, concurrently |
| Scope | 1 AZ | Regional (mount target per AZ) |
| Size | provisioned | elastic |
| OS | any | Linux (NFSv4); Windows → FSx |

## Verify
`./tests/verify-phase-06.sh` — 9 checks.

## Files
`infra/efs/userdata-server-b.sh`, `infra/efs/fstab.line`
