
# Phase 2 — S3 direct uploads

## Goal

Move file storage from the EC2 disk to a private, encrypted S3 bucket.
The browser uploads straight to S3 with a presigned URL; the server only signs.

## Architecture

```
Browser ──1. POST /uploads──► FastAPI (EC2, IAM role)
   │                            └─ signs PUT URL with temporary role creds (ASIA...)
   ├──2. PUT file (CORS) ─────► S3 bucket ──► KMS (GenerateDataKey)
   └──3. POST /complete ──────► FastAPI ──head_object──► S3 → status = stored
```

## What was built

| Resource        | Config                                                                                                | Why                                                                    |
| --------------- | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| S3 bucket       | Block Public Access (all 4), versioning, tags                                                         | Private by default; recover overwrites/deletes                         |
| KMS key         | `alias/storage-lab-s3`, rotation on, Bucket Key                                                     | Key policy control (needed for CloudFront in phase 4); fewer KMS calls |
| Bucket policy   | Deny `s3:*` when `aws:SecureTransport=false`                                                      | Encryption in transit                                                  |
| EC2 role policy | `PutObject`/`GetObject` on `uploads/*`, `GenerateDataKey`/`Decrypt` on the key              | Least privilege; no delete                                             |
| CORS            | `PUT` from known origins only, no `*`                                                             | Browser direct upload                                                  |
| App             | `POST /uploads` (pending + presigned PUT, 5 min), `POST /uploads/{id}/complete` (`head_object`) | Server never trusts the browser                                        |

## Experiments

- **Presigned URL:** wrong `Content-Type` → `SignatureDoesNotMatch`; after 5 min → `Request has expired`.
- **CORS:** upload blocked until the origin was added; `curl` works without CORS (browser-only rule).
- **Versioning:** restored an overwritten file by copying the old version; recovered a deleted file by removing the delete marker.
- **Glacier Flexible:** `GetObject` → `InvalidObjectState`; Expedited restore in < 5 min; class stays `GLACIER`.
- **Multipart:** 50 MB upload → ETag ends in `-7`; an abandoned upload is invisible to `ls` but billed until aborted.

## Verify

```bash
./tests/verify-phase-02.sh   # 12 passed, 0 failed
```

## SAA-C03 mapping

Bucket policy vs IAM policy, Block Public Access, SSE-S3 vs SSE-KMS, Bucket Key, KMS limits,
`aws:SecureTransport`, CORS, presigned URLs, versioning & delete markers, MFA Delete,
storage classes & retrieval tiers, multipart upload.

## Lessons learned

1- you must check the ip and address when you test 

2- test all cases
