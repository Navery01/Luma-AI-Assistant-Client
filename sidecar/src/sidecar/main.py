
from fastapi import FastAPI, WebSocket
from starlette.websockets import WebSocketDisconnect
import uvicorn
import logging

logging.basicConfig(level=logging.INFO)

app = FastAPI()


@app.websocket("/ws/audio/")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            message = await websocket.receive()
            message_type = message.get("type")

            if message_type == "websocket.disconnect":
                break

            # data = message.get("bytes")
            byte_data = await websocket.receive_bytes()
            if byte_data is None:
                # Some clients send text/control frames; ignore non-binary payloads.
                continue

            await websocket.send_text(f"Received {len(byte_data)} bytes")
            logging.info(f"Received {len(byte_data)} bytes from client.")

    except WebSocketDisconnect:
        pass


    

def run():
    uvicorn.run(app, host="0.0.0.0", port=8000)