import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SpeechToTextService {

  SpeechToTextService({required this.ws});
  final WebSocketChannel ws;
  final recorder = AudioRecorder();

  final recordConfig = const RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 48000,
    numChannels: 1,
    echoCancel: true,
    autoGain: true,
  );

  StreamSubscription<Uint8List>? _micSub;
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  // 100ms frames: 16000 samples/sec * 2 bytes/sample * 1 ch * 0.1 sec = 3200
  static const int frameBytes = 3200;

  Future<void> startStreaming() async {
    if (!await recorder.hasPermission()) return;



    final micStream = await recorder.startStream(recordConfig);
    _micSub = micStream.listen((chunk) {
      _buffer.add(chunk);
      _drainFramesToWebSocket();
    });
  }

  void _drainFramesToWebSocket() {
    final data = _buffer.toBytes();
    int offset = 0;

    while (data.length - offset >= frameBytes) {
      final frame = Uint8List.sublistView(data, offset, offset + frameBytes);
      final frameMessage = {
        "type": "bytes",
        "data": frame,
      };
      ws.sink.add(frameMessage); // binary frame
      offset += frameBytes;
    }

    final remaining = data.length - offset;
    _buffer.clear();
    if (remaining > 0) {
      _buffer.add(Uint8List.sublistView(data, offset));
    }
  }

  Future<void> stopStreaming() async {
    await _micSub?.cancel();
    _micSub = null;

    // Optional: send end message your API expects
    ws.sink.add('{"type":"stop"}');
    await ws.sink.close();

    if (await recorder.isRecording()) {
      await recorder.stop();
    }

    _buffer.clear();
  }
}