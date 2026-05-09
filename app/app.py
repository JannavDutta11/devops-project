from fastapi import FastAPI
import socket
import os
from datetime import datetime
 
app = FastAPI()
 
@app.get("/")
def home():
    return {"message": "App is running v2 🚀 - CI/CD deployed!"}
 
@app.get("/health")
def health():
    return {
        "status": "UP",
        "timestamp": datetime.now().isoformat()
    }
 
@app.get("/info")
def info():
    return {
        "app": "DevOps App",
        "version": "2.0",
        "hostname": socket.gethostname(),
        "env": os.getenv("ENV", "dev")
    }