
import 'package:ai_assistant_client/widgets/painters.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../widgets/themes.dart';
import '../services/audio_service.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  AudioService? _audioService;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    const webSocketUri = String.fromEnvironment(
      'SIDECAR_WEBSOCKET_URI',
      defaultValue: 'ws://127.0.0.1:8001/ws/audio/',
    );
    _initAudio(webSocketUri);

  }

  Future<void> _initAudio(String webSocketUri) async {
    try {
      final ws = WebSocketChannel.connect(Uri.parse(webSocketUri));
      _audioService = AudioService(ws: ws);
      await _audioService!.startPlayback();
      await _audioService!.startStreaming();
    } catch (error, stackTrace) {
      debugPrint('Audio init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _audioService?.stopStreaming();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.gradient(colorScheme.surface, colorScheme.surfaceTint),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: CloudPainter(
                      progress: _controller.value,
                      cloudColor: colorScheme.onSurface.withValues(alpha: 0.16),
                      hazeColor: colorScheme.primary.withValues(alpha: 0.08),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: CharacterPainter(color: colorScheme.onSurface.withValues(alpha: 0.24)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


