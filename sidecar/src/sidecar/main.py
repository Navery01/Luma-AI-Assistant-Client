
from fastapi import FastAPI, WebSocket
import os
import uvicorn
import asyncio


app = FastAPI()


@app.websocket("/ws/audio/")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    while True:
        data = await websocket.receive_bytes()
        await websocket.send_text(f"Message text was: {data}")


    

def run():
    uvicorn.run(app, host="0.0.0.0", port=8000)