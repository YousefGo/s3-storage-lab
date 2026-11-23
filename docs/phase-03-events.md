
# Phase 3 — Event-driven thumbnails

## Goal

Every image uploaded to `uploads/` gets a 256 px thumbnail in `thumbnails/`,
with no server involved.

## Architecture

```
S3 uploads/*.jpg|jpeg|png ──event──► SQS (visibility 180 s, long polling 20 s)
                                       │  └─ 3 failed receives ──► DLQ (14 days)
                                       ▼
                         Lambda (Python 3.12 + Pillow layer, 30 s, 512 MB)
                                       ▼
                               S3 thumbnails/*.jpg (SSE-KMS)
```

## What was built

| Resource             | Config                                                                                         | Why                                                            |
| -------------------- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| SQS queue            | Visibility 180 s (6× Lambda timeout), long polling, redrive to DLQ after 3                    | No double processing; fewer empty receives; bad files isolated |
| Queue policy         | Only `s3.amazonaws.com` with `aws:SourceArn` = bucket, `aws:SourceAccount`               | Prevents the confused-deputy problem                           |
| S3 notification      | `ObjectCreated:*`, prefix `uploads/`, suffix `.jpg`/`.jpeg`/`.png`                   | Images only; no recursive loop                                 |
| Lambda role          | `GetObject` on `uploads/*`, `PutObject` on `thumbnails/*`, KMS Decrypt/GenerateDataKey | Cannot overwrite originals                                     |
| Pillow layer         | `manylinux2014_x86_64` wheels in `python/`                                                 | Native library built for Lambda's Linux                        |
| Event source mapping | Batch size 1                                                                                   | One bad file never blocks others                               |

## Experiments

- Filter: `ignored.txt` (an image renamed) → no event; `.jpg` → event with key and size only.
- Direct `invoke` before wiring the queue: cold start 402 ms, billed 1001 ms (init is billed).
- Corrupt `.jpg` → `UnidentifiedImageError` ×3 → DLQ. Fix path: DLQ redrive.

## Verify

```bash
./tests/verify-phase-03.sh   # 7 passed, 0 failed
```

## SAA-C03 mapping

S3 event targets (SQS/SNS/Lambda/EventBridge), queue policies, visibility timeout vs
Lambda timeout, long polling, DLQ and redrive, Lambda layers, cold starts, recursive loops.

## Lessons learned

## 15. Variables empty in a new terminal (`s3:///uploads/...`, `--queue-url: expected one argument`)

**Fix:** `scripts/env.sh` exports every ID; run `source scripts/env.sh` first in each terminal.
`source` keeps variables in the current shell; `./env.sh` would run in a child shell and lose them.

## 16. Verify script failed: `OSError: image file is truncated`

**Cause:** the test image was a hand-written base64 JPEG that was invalid. The Lambda was fine.
**Fix:** generate a real image with Pillow in the script. Lesson: test data can be the bug.
