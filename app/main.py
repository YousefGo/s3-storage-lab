import socket 
from fastapi import FastAPI 

app = FastAPI(title="AWS Storage Lab ")

@app.get("/health")
def health():
    return {"status": "ok", "hostname": socket.gethostname()}