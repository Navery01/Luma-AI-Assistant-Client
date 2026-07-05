import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';


class AudioBytes extends StreamAudioSource {
  final Uint8List bytes;
  AudioBytes(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final safeStart = start ?? 0;
    final safeEnd = end ?? bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: safeEnd - safeStart,
      offset: safeStart,
      stream: Stream.value(bytes.sublist(safeStart, safeEnd)),
      contentType: 'audio/wav',
    );
  }
}

class AudioService {
  AudioService({required this.ws});
  final WebSocketChannel ws;
  final recorder = AudioRecorder();

  final recordConfig = const RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 48000,
    numChannels: 1,
    echoCancel: true,
    autoGain: true,
  );

  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription? _wsSub;
  final BytesBuilder _micBuffer = BytesBuilder(copy: false);
  final BytesBuilder _playbackBuffer = BytesBuilder(copy: false);
  final Queue<Uint8List> _playbackQueue = Queue<Uint8List>();
  bool _isPlaybackLoopRunning = false;
  bool _isStopping = false;
  static const int playbackSampleRate = 44100;
  static const int playbackChannels = 1;
  static const int playbackBytesPerSample = 4; // pcmf32le
  static const int playbackChunkMs = 500;

  // Outbound mic frame size (PCM16 @ 16kHz, mono, 100ms).
  static const int micFrameBytes = 3200;

    // Play 500ms chunks to reduce frequent source loads that can be inaudible.
    static const int playbackChunkBytes =
      ((playbackSampleRate * playbackChannels * playbackBytesPerSample * playbackChunkMs) ~/ 1000);

  Future<void> startPlayback() async {
    await _player.setVolume(1.0);
    _wsSub = ws.stream.listen((message) {
      if (message is Uint8List) {
        _playbackBuffer.add(message);
        _drainFramesFromWebSocket();
      }
    }, onError: (error, stackTrace) {
      debugPrint('Playback stream error: $error');
      debugPrintStack(stackTrace: stackTrace is StackTrace ? stackTrace : null);
    });
  }

  Future<void> startStreaming() async {
    if (!await recorder.hasPermission()) return;

    final micStream = await recorder.startStream(recordConfig);
    _micSub = micStream.listen((chunk) {
      _micBuffer.add(chunk);
      _drainFramesToWebSocket();
    });
  }

  void _drainFramesToWebSocket() {
    final data = _micBuffer.toBytes();
    int offset = 0;

    while (data.length - offset >= micFrameBytes) {
      final frame = Uint8List.sublistView(data, offset, offset + micFrameBytes);
      ws.sink.add(frame); // send raw binary frame
      offset += micFrameBytes;
    }

    final remaining = data.length - offset;
    _micBuffer.clear();
    if (remaining > 0) {
      _micBuffer.add(Uint8List.sublistView(data, offset));
    }
  }

  Future<void> stopStreaming() async {
    _isStopping = true;
    await _micSub?.cancel();
    _micSub = null;
    await _wsSub?.cancel();
    _wsSub = null;

    // Optional: send end message your API expects
    ws.sink.add('{"type":"stop"}');
    await ws.sink.close();

    if (await recorder.isRecording()) {
      await recorder.stop();
    }

    _micBuffer.clear();
    _playbackBuffer.clear();
    _playbackQueue.clear();
    await _player.stop();
    await _player.dispose();
  }

  void _drainFramesFromWebSocket() {
    final data = _playbackBuffer.toBytes();
    final alignedLength = data.length - (data.length % playbackBytesPerSample);
    int offset = 0;

    while (alignedLength - offset >= playbackChunkBytes) {
      final frame = Uint8List.sublistView(data, offset, offset + playbackChunkBytes);
      _playbackQueue.add(Uint8List.fromList(frame));
      offset += playbackChunkBytes;
    }

    final remaining = data.length - offset;
    _playbackBuffer.clear();
    if (remaining > 0) {
      _playbackBuffer.add(Uint8List.sublistView(data, offset));
    }

    _processPlaybackQueue();
  }

  Future<void> _processPlaybackQueue() async {
    if (_isPlaybackLoopRunning || _isStopping) return;

    _isPlaybackLoopRunning = true;
    try {
      while (_playbackQueue.isNotEmpty && !_isStopping) {
        final frame = _playbackQueue.removeFirst();
        await _playAudioFrame(frame);
      }
    } finally {
      _isPlaybackLoopRunning = false;
    }
  }

  Future<void> _playAudioFrame(Uint8List frame) async {
    try {
      final pcm16Bytes = _pcmf32leToPcm16(frame);
      final wavBytes = _pcm16ToWav(
        pcm16Bytes,
        sampleRate: playbackSampleRate,
        channels: playbackChannels,
      );
      debugPrint('Playing audio frame of size: ${wavBytes.length} bytes');
      await _player.setAudioSource(AudioBytes(wavBytes));
      await _player.play();
    } on PlayerInterruptedException {
      if (!_isStopping) {
        debugPrint('Audio frame playback interrupted by a newer load request');
      }
    } catch (error, stackTrace) {
      debugPrint('Audio frame playback failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Uint8List _pcmf32leToPcm16(Uint8List floatBytes) {
    final int alignedLength = floatBytes.length - (floatBytes.length % 4);
    final int sampleCount = alignedLength ~/ 4;
    final input = ByteData.sublistView(floatBytes, 0, alignedLength);
    final output = ByteData(sampleCount * 2);

    for (int i = 0; i < sampleCount; i++) {
      final sample = input.getFloat32(i * 4, Endian.little);
      final clamped = sample.clamp(-1.0, 1.0);
      final pcm =
          (clamped < 0 ? clamped * 32768.0 : clamped * 32767.0).round();
      output.setInt16(i * 2, pcm, Endian.little);
    }

    return output.buffer.asUint8List();
  }

  Uint8List _pcm16ToWav(
    Uint8List pcmBytes, {
    required int sampleRate,
    required int channels,
  }) {
    const int bitsPerSample = 16;
    const int audioFormat = 1; // WAVE_FORMAT_PCM
    final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final int blockAlign = channels * (bitsPerSample ~/ 8);
    final int subchunk2Size = pcmBytes.length;
    final int chunkSize = 36 + subchunk2Size;

    final header = ByteData(44)
      ..setUint8(0, 0x52) // R
      ..setUint8(1, 0x49) // I
      ..setUint8(2, 0x46) // F
      ..setUint8(3, 0x46) // F
      ..setUint32(4, chunkSize, Endian.little)
      ..setUint8(8, 0x57) // W
      ..setUint8(9, 0x41) // A
      ..setUint8(10, 0x56) // V
      ..setUint8(11, 0x45) // E
      ..setUint8(12, 0x66) // f
      ..setUint8(13, 0x6d) // m
      ..setUint8(14, 0x74) // t
      ..setUint8(15, 0x20) // space
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, audioFormat, Endian.little)
      ..setUint16(22, channels, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, byteRate, Endian.little)
      ..setUint16(32, blockAlign, Endian.little)
      ..setUint16(34, bitsPerSample, Endian.little)
      ..setUint8(36, 0x64) // d
      ..setUint8(37, 0x61) // a
      ..setUint8(38, 0x74) // t
      ..setUint8(39, 0x61) // a
      ..setUint32(40, subchunk2Size, Endian.little);

    return Uint8List.fromList([...header.buffer.asUint8List(), ...pcmBytes]);
  }
}