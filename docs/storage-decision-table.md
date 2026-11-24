# Storage Decision Table (SAA-C03) — built from hands-on phases 1–7

## Block / File
| Need | Service | Phase |
|---|---|---|
| Boot/data disk for one EC2, persistent, 1 AZ | EBS gp3 | 1 |
| Highest IOPS, temporary data (lost on stop) | Instance Store | 1 (lesson 10) |
| Very high IOPS, critical DB | EBS io2 (Multi-Attach possible) | theory |
| Shared Linux file system, many instances, multi-AZ | EFS | 6 |
| Shared Windows (SMB, AD) | FSx for Windows File Server | theory |
| HPC / ML, very high throughput | FSx for Lustre | theory |
| DR copy of a disk in another region | EBS snapshot copy (encrypted) | 1 |

## S3 storage classes
| Access pattern | Class | Min duration | Retrieval |
|---|---|---|---|
| Frequent | Standard | — | ms |
| Unknown / changing | Intelligent-Tiering | — | ms (no retrieval fee) |
| Monthly | Standard-IA | 30 d | ms (+ per-GB fee) |
| Re-creatable, monthly | One Zone-IA | 30 d | ms |
| Quarterly, needs ms | Glacier Instant Retrieval | 90 d | ms |
| Yearly, minutes–hours OK | Glacier Flexible Retrieval | 90 d | 1–5 min / 3–5 h / 5–12 h |
| Archive, cheapest | Glacier Deep Archive | 180 d | 12 h / 48 h |

## S3 features
| Need | Feature | Phase |
|---|---|---|
| Recover overwritten/deleted object | Versioning | 2 |
| Move to cheaper class over time / expire | Lifecycle rules | 5 |
| Copy to another region automatically | CRR (+ versioning both sides) | 5 |
| Copy existing objects | S3 Batch Replication | 5 |
| Replicate within 15 min with SLA | Replication Time Control | theory |
| WORM, admins can bypass | Object Lock Governance | 5 |
| WORM, nobody can delete (ransomware, regulator) | Object Lock Compliance | 5 (theory) |
| Hold with no end date | Legal Hold | 5 |
| Browser uploads without passing through server | Presigned URL + CORS | 2 |
| React to uploads | Event notifications → SQS → Lambda | 3 |
| Fast global delivery, private bucket | CloudFront + OAC | 4 |
| Large uploads | Multipart (> 100 MB) | 2 |

## Backup / transfer
| Need | Service | Phase |
|---|---|---|
| Centralized, policy-based backups across services | AWS Backup | 7 |
| Immutable backups | Backup Vault Lock | theory |
| Online / scheduled transfer to S3/EFS/FSx | DataSync | 7 |
| TBs–PBs, slow internet | Snowball | theory |
| On-prem apps keep NFS/SMB/iSCSI, data in S3 | Storage Gateway | theory |
| SFTP/FTPS into S3 | Transfer Family | theory |
