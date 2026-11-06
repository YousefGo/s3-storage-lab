
# Phase 1 — EC2 + EBS

## Goal

Run the file-storage API on a single EC2 instance with its data on a
separate, encrypted EBS volume that survives reboots, instance termination,
and a full region outage (via snapshot copy).

## Architecture

```
Internet
   │  Security Group: 22 (my IP), 80 (anywhere)
   ▼
EC2  t3.micro  (us-east-1)
   ├─ Nginx :80  ──reverse proxy──►  uvicorn :8000 (systemd)
   ├─ Root volume (OS)
   └─ /data ◄── EBS gp3, encrypted (aws/ebs), DeleteOnTermination=false
                 │
                 └─ snapshot ──copy (encrypted)──► us-west-2 (DR)
```

## What was built

| Resource                    | Config                                              | Why                                       |
| --------------------------- | --------------------------------------------------- | ----------------------------------------- |
| IAM role + instance profile | read-only, least privilege                          | No access keys on the server              |
| Security Group              | 22 from my IP, 80 public, 8000 closed               | App only reachable through Nginx          |
| EBS data volume             | gp3, 20 GiB, encrypted, mounted via UUID in fstab   | Data lives apart from the OS              |
| systemd unit                | `RequiresMountsFor=/data`, `Restart=on-failure` | App starts only after the disk is mounted |
| Nginx                       | reverse proxy, `client_max_body_size` raised      | Default 1 MB caused 413 on uploads        |

## Operations performed

- **Snapshot & restore** into a different AZ (volumes are AZ-bound, snapshots are regional).
- **Cross-region copy** to us-west-2 with `--encrypted` (KMS keys are regional).
- **Encrypt an existing volume:** snapshot → encrypted copy → new volume → swap.
- **Encryption by default** enabled for the region.
- **Online resize** 10Gb → 20 GiB with `modify-volume` + `xfs_growfs`, no downtime.

## Decisions

- [ADR-001](adr/001-uuid-storage-keys.md) — UUID storage keys
- [ADR-002](adr/002-....md) — Separate EBS data volume
- [ADR-003](- [ADR-003](adr/003-ebs-encryption-aws-managed-key.md) — EBS encryption with aws/ebs) — EBS encryption with aws/ebs

## Verify

```bash
./tests/verify-phase-01.sh <public-ip>
# 7 passed, 0 failed
```

## Problems hit

See [troubleshooting.md](troubleshooting.md) — 11 entries.

## SAA-C03 mapping

EBS volume types, AZ scope, snapshots (incremental, regional), cross-region copy,
EBS encryption & KMS, DeleteOnTermination, IAM roles for EC2, Security Groups.

## Lessons learned


- **Verify before you trust.** `mount -a` before reboot caught a broken fstab line
  that would have left the instance unbootable; `lsblk` vs `df` showed the disk
  had grown but the filesystem had not.
- **Separating layers gives control.** Keeping data on its own EBS volume let me
  snapshot, encrypt, move across AZs, and resize it without touching the OS.
- **The CLI makes work repeatable.** Every step is a command I can rerun, script,
  and verify (`tests/verify-phase-01.sh`) — the console can't be tested or reviewed.
