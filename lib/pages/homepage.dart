
import 'package:ai_assistant_client/widgets/painters.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../widgets/themes.dart';
import '../services/speech_to_text_service.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    const webSocketUri = String.fromEnvironment('APP_WEBSOCKET_URI');
    () async {
      final ws = WebSocketChannel.connect(Uri.parse(webSocketUri));
      await SpeechToTextService(ws: ws).startStreaming();
    }();

  }

  @override
  void dispose() {
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


