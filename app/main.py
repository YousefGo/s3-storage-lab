import socket 
import uuid
from contextlib import asynccontextmanager
from pathlib import Path
from app.routes.uploads import router as uploads_router
from fastapi import FastAPI, HTTPException, UploadFile
from fastapi.responses import FileResponse
from app.config import UPLOAD_DIR, MAX_UPLOAD_BYTES
from app.db import get_conn, init_db 

@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield

app = FastAPI(title="AWS Storage Lab ", lifespan=lifespan)
app.include_router(uploads_router)

@app.get("/health")
def health():
    return {"status": "ok", "hostname": socket.gethostname()}



@app.post("/files", status_code=201)
def upload_file(file: UploadFile):
    key = f"{uuid.uuid4().hex}{Path(file.filename or '').suffix.lower()}"
    dest = UPLOAD_DIR / key

    size = 0
    with dest.open("wb") as out:
        while chunk := file.file.read(1024 * 1024):
            size += len(chunk)
            if size > MAX_UPLOAD_BYTES:
                out.close()
                dest.unlink()
                raise HTTPException(413, "File too large")
            out.write(chunk)

    with get_conn() as conn:
        cur = conn.execute(
            "INSERT INTO files (storage_key, original_name, content_type, size_bytes, status) "
            "VALUES (?, ?, ?, ?, ?)",
            (key, file.filename, file.content_type, size, "stored"),
        )
        file_id = cur.lastrowid

    return {"id": file_id, "storage_key": key, "size_bytes": size}


@app.get("/files")
def list_files():
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT id, original_name, content_type, size_bytes, status, created_at "
            "FROM files ORDER BY id DESC"
        ).fetchall()
    return [dict(r) for r in rows]


@app.get("/files/{file_id}")
def download_file(file_id: int):
    with get_conn() as conn:
        row = conn.execute(
            "SELECT storage_key, original_name, content_type FROM files WHERE id = ?",
            (file_id,),
        ).fetchone()
    if row is None:
        raise HTTPException(404, "File not found")
    return FileResponse(
        UPLOAD_DIR / row["storage_key"],
        media_type=row["content_type"],
        filename=row["original_name"],
    )
