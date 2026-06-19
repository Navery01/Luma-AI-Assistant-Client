
from fastapi import FastAPI, WebSocket
from starlette.websockets import WebSocketDisconnect
import asyncio
import os
from websockets.asyncio.client import connect
from websockets.exceptions import ConnectionClosed
import uvicorn
import logging

logging.basicConfig(level=logging.INFO)

app = FastAPI()

SERVER_WEBSOCKET_URI = os.getenv("SERVER_WEBSOCKET_URI")


async def _pump_client_to_upstream(client_ws: WebSocket, upstream_ws):
    """Forward client frames/messages to upstream until client disconnects."""
    while True:
        message = await client_ws.receive()
        message_type = message.get("type")

        if message_type == "websocket.disconnect":
            break

        byte_data = message.get("bytes")
        text_data = message.get("text")

        if byte_data is not None:
            await upstream_ws.send(byte_data)
            logging.info(f"Forwarded {len(byte_data)} bytes client -> upstream")
        elif text_data is not None:
            await upstream_ws.send(text_data)
            logging.info("Forwarded text message client -> upstream")


async def _pump_upstream_to_client(upstream_ws, client_ws: WebSocket):
    """Forward upstream messages back to client until upstream closes."""
    async for upstream_message in upstream_ws:
        if isinstance(upstream_message, bytes):
            await client_ws.send_bytes(upstream_message)
            logging.info(f"Forwarded {len(upstream_message)} bytes upstream -> client")
        else:
            await client_ws.send_text(upstream_message)
            logging.info("Forwarded text message upstream -> client")

@app.websocket("/ws/audio/")
async def websocket_endpoint(websocket: WebSocket):
    """Websocket endpoint that bridges between client and upstream server."""
    await websocket.accept()

    if not SERVER_WEBSOCKET_URI:
        await websocket.close(code=1011, reason="SERVER_WEBSOCKET_URI is not configured")
        return

    try:
        async with connect(SERVER_WEBSOCKET_URI) as server_ws:
            client_to_upstream = asyncio.create_task(
                _pump_client_to_upstream(websocket, server_ws)
            )
            upstream_to_client = asyncio.create_task(
                _pump_upstream_to_client(server_ws, websocket)
            )

            done, pending = await asyncio.wait(
                {client_to_upstream, upstream_to_client},
                return_when=asyncio.FIRST_COMPLETED,
            )

            for task in pending:
                task.cancel()

            await asyncio.gather(*pending, return_exceptions=True)

            for task in done:
                exc = task.exception()
                if exc and not isinstance(exc, (WebSocketDisconnect, ConnectionClosed)):
                    raise exc

    except WebSocketDisconnect:
        logging.info("Client websocket disconnected")
    except ConnectionClosed:
        logging.info("Upstream websocket disconnected")
    except Exception:
        logging.exception("Unexpected websocket bridge error")
        if websocket.client_state.name != "DISCONNECTED":
            await websocket.close(code=1011, reason="Bridge error")

def run():
    uvicorn.run(app, host="0.0.0.0", port=8001)