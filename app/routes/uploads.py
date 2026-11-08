import uuid
from pathlib import Path

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.config import AWS_REGION, S3_BUCKET
from app.db import get_conn

router = APIRouter(prefix="/uploads", tags=["uploads"])

s3 = boto3.client(
    "s3",
    region_name=AWS_REGION,
    endpoint_url=f"https://s3.{AWS_REGION}.amazonaws.com",
    config=Config(signature_version="s3v4"),
)

URL_TTL_SECONDS = 300            # 5 minutes
MAX_SINGLE_PUT = 5 * 1024**3     # S3 limit for one PUT (5 GB)


class UploadRequest(BaseModel):
    filename: str = Field(min_length=1, max_length=255)
    content_type: str = "application/octet-stream"
    size_bytes: int = Field(gt=0, le=MAX_SINGLE_PUT)


@router.post("", status_code=201)
def create_upload(req: UploadRequest):
    key = f"uploads/{uuid.uuid4().hex}{Path(req.filename).suffix.lower()}"
    with get_conn() as conn:
        cur = conn.execute(
            "INSERT INTO files (storage_key, original_name, content_type, size_bytes, status) "
            "VALUES (?, ?, ?, ?, 'pending')",
            (key, req.filename, req.content_type, req.size_bytes),
        )
        file_id = cur.lastrowid

    url = s3.generate_presigned_url(
        "put_object",
        Params={"Bucket": S3_BUCKET, "Key": key, "ContentType": req.content_type},
        ExpiresIn=URL_TTL_SECONDS,
    )
    return {"id": file_id, "key": key, "upload_url": url, "expires_in": URL_TTL_SECONDS}


@router.post("/{file_id}/complete")
def complete_upload(file_id: int):
    with get_conn() as conn:
        row = conn.execute(
            "SELECT storage_key FROM files WHERE id = ?", (file_id,)
        ).fetchone()
    if row is None:
        raise HTTPException(404, "Upload not found")

    try:
        head = s3.head_object(Bucket=S3_BUCKET, Key=row["storage_key"])
    except ClientError:
        raise HTTPException(409, "Object not in S3 yet")

    with get_conn() as conn:
        conn.execute(
            "UPDATE files SET status = 'stored', size_bytes = ? WHERE id = ?",
            (head["ContentLength"], file_id),
        )
    return {
        "id": file_id,
        "status": "stored",
        "size_bytes": head["ContentLength"],
        "encryption": head.get("ServerSideEncryption"),
    }