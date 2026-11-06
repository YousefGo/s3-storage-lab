
# AWS Storage Lab

Hands-on project covering AWS storage services for the **AWS Solutions Architect
Associate (SAA-C03)**. A FastAPI file-storage API that evolves phase by phase —
every phase is built by hand with the AWS CLI, documented, and verified by a script.

## Stack

Python · FastAPI · SQLite · boto3 · AWS CLI · Nginx · systemd · Linux

## Progress

| Phase | Topic                                         | Status  | Docs                                |
| ----- | --------------------------------------------- | ------- | ----------------------------------- |
| 1     | EC2 + EBS (encryption, snapshots, DR, resize) | ✅ Done | [phase-01](docs/phase-01-ec2-ebs.md) |
| 2     | S3                                            | ⏳ Next | —                                  |

## How each phase is documented

- **Phase summary:** what was built and why → `docs/phase-XX-*.md`
- **Decisions (ADRs):** choices and trade-offs → [`docs/adr/`](docs/adr/)
- **Troubleshooting:** real problems and fixes → [`docs/troubleshooting.md`](docs/troubleshooting.md)
- **Verification:** PASS/FAIL script per phase → [`tests/`](tests/)

## Verify Phase 1

```bash
./tests/verify-phase-01.sh <public-ip>
# 7 passed, 0 failed
```

## Repo layout

```
app/          FastAPI app + schema.sql
infra/server/ systemd unit + Nginx config
docs/         phase summaries, ADRs, troubleshooting
tests/        verification scripts
```
