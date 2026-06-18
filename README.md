# Luma AI Assistant Client

Flutter client and Python sidecar for real-time microphone capture, wake-word driven flow, and streaming speech-to-text.

## Project Overview

This workspace contains two cooperating apps:

1. Flutter app (`ai_assistant_client`):
	- Captures microphone audio using the `record` package.
	- Streams audio frames over WebSocket.
	- Hosts the user-facing UI and wake-state experience.

2. Python sidecar (`sidecar`):
	- Runs a lightweight FastAPI WebSocket service.
	- Receives streaming audio from the Flutter app.
	- Intended to route audio to an upstream STT provider (Deepgram) and return transcript events.

## High-Level Architecture

1. User speaks near device microphone.
2. Flutter captures PCM frames and sends binary WebSocket frames.
3. Python-based sidecar validates and forwards audio stream to Deepgram live transcription.
4. Sidecar emits transcript events back to the client.

## Repository Layout

- `lib/main.dart`: Flutter app entrypoint.
- `lib/pages/homepage.dart`: Main screen and startup stream wiring.
- `lib/services/speech_to_text_service.dart`: Audio capture and frame streaming.
- `sidecar/src/sidecar/main.py`: FastAPI WebSocket endpoint for audio ingress.
- `sidecar/pyproject.toml`: Sidecar Python dependencies and runtime metadata.

## Local Development

### Prerequisites

- Flutter SDK (matching your Dart SDK constraints in `pubspec.yaml`).
- Python 3.13+.
- `uv` for sidecar environment and package management.

### Run Flutter Client

```bash
flutter pub get
flutter run --dart-define=APP_WEBSOCKET_URI=ws://127.0.0.1:8000/ws/audio/
```

### Run Sidecar

```bash
cd sidecar
uv sync
uv run -m sidecar
```

## Audio Streaming Contract (v1)

The sidecar and Flutter app will use a strict binary-only audio contract optimized for Deepgram real-time STT.

### Goals

- Low latency, stable live transcription.
- Simple transport contract with no per-frame schema parsing.
- Deterministic validation and failure handling.

### Transport

- Protocol: WebSocket.
- Endpoint: `ws://localhost:8000/ws/audio/`.
- Frame type: binary frames only.
- Text frames: rejected.

### Audio Format

- Encoding: `linear16` (PCM signed 16-bit little-endian).
- Sample rate: `16000` Hz.
- Channels: `1` (mono).
- Byte order: little-endian.
- Container: none (raw PCM bytes, no WAV header).

### Frame Size and Cadence

- Target frame duration: `20 ms` (recommended for lower perceived latency).
- Bytes per frame: `16000 samples/s * 0.02 s * 2 bytes/sample * 1 channel = 640 bytes`.
- Acceptable frame duration range: `20-100 ms`.
- Rule: each frame length must be divisible by 2 bytes.

### Session Metadata

Because frames are binary-only, metadata is set during connection setup.

Recommended query parameters:

- `encoding=linear16`
- `sample_rate=16000`
- `channels=1`
- `model=nova-3`
- `language=en`
- `interim_results=true`
- `punctuate=true`
- `smart_format=true`
- `endpointing=300`

### End-of-Stream

- Client signals completion by closing the WebSocket with code `1000`.
- No JSON stop message is sent on the audio socket.

### Server Validation Rules

On each received frame, sidecar must:

1. Reject non-binary frames (close `1003`, unsupported data).
2. Reject empty frames only if policy forbids them.
3. Reject malformed payload length not divisible by 2 (close `1008`, policy violation).
4. Log and close on repeated invalid frames.

### Deepgram Live STT Mapping

Equivalent Deepgram stream settings should match the contract exactly:

- `encoding=linear16`
- `sample_rate=16000`
- `channels=1`

Typical live options for conversational latency:

- `model=nova-3`
- `interim_results=true`
- `endpointing=300`
- `utterance_end_ms=1000`
- `smart_format=true`
- `punctuate=true`

## Protocol Example

1. Flutter opens `ws://127.0.0.1:8000/ws/audio/?encoding=linear16&sample_rate=16000&channels=1&model=nova-3`.
2. Flutter sends continuous binary PCM frames at 20 ms cadence.
3. Sidecar forwards bytes to Deepgram websocket stream.
4. Sidecar receives transcript events and routes them to the assistant pipeline.
5. Flutter closes websocket with code 1000 at end-of-utterance/session.

## Implementation Notes

The current codebase is close to this design, but should be aligned to this contract:

1. Ensure capture sample rate is set to `16000` in `SpeechToTextService`.
2. Remove JSON/text stop payloads on the binary audio socket.
3. Enforce binary-only validation in the sidecar websocket handler.
4. Avoid reading from the websocket twice per loop iteration.

## Why This Format For Deepgram

- `linear16` mono 16 kHz is a first-class input format for speech workloads.
- Raw PCM avoids container parsing overhead.
- 20 ms chunking is a practical low-latency tradeoff between packet overhead and responsiveness.
- Binary-only framing keeps protocol handling simple and predictable.
