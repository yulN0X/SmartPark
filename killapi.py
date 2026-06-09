import os
import signal
from fastapi import FastAPI, BackgroundTasks

app = FastAPI()

def self_destruct():
    # Sends an interrupt signal to the current process ID
    os.kill(os.getpid(), signal.SIGINT)

@app.post("/shutdown")
def shutdown_server(background_tasks: BackgroundTasks):
    # Use background tasks so the API can return a response before dying
    background_tasks.add_task(self_destruct)
    return {"message": "Shutting down the server..."}