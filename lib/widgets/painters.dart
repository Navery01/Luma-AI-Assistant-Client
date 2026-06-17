import 'dart:math' as math;
import 'package:flutter/material.dart';

class CloudPainter extends CustomPainter {
  const CloudPainter({
    required this.progress,
    required this.cloudColor,
    required this.hazeColor,
  });

  final double progress;
  final Color cloudColor;
  final Color hazeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final baseRadius = size.shortestSide * 0.22;

    _paintCloud(
      canvas,
      size,
      centerXFactor: 0.24,
      centerYFactor: 0.32,
      radius: baseRadius,
      xAmplitude: size.width * 0.06,
      yAmplitude: size.height * 0.03,
      phase: 0.0,
      color: cloudColor,
    );

    _paintCloud(
      canvas,
      size,
      centerXFactor: 0.7,
      centerYFactor: 0.5,
      radius: baseRadius * 1.2,
      xAmplitude: size.width * 0.08,
      yAmplitude: size.height * 0.04,
      phase: 1.6,
      color: cloudColor.withValues(alpha: cloudColor.a * 0.85),
    );

    _paintCloud(
      canvas,
      size,
      centerXFactor: 0.45,
      centerYFactor: 0.75,
      radius: baseRadius * 1.1,
      xAmplitude: size.width * 0.07,
      yAmplitude: size.height * 0.025,
      phase: 3.2,
      color: hazeColor,
    );
  }

  void _paintCloud(
    Canvas canvas,
    Size size, {
    required double centerXFactor,
    required double centerYFactor,
    required double radius,
    required double xAmplitude,
    required double yAmplitude,
    required double phase,
    required Color color,
  }) {
    final t = progress * math.pi * 2;
    final center = Offset(
      size.width * centerXFactor + math.sin(t + phase) * xAmplitude,
      size.height * centerYFactor + math.cos(t + (phase * 1.37)) * yAmplitude,
    );

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color,
          color.withValues(alpha: color.a * 0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.6));

    canvas.drawCircle(center, radius * 1.6, paint);
  }

  @override
  bool shouldRepaint(covariant CloudPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.cloudColor != cloudColor || oldDelegate.hazeColor != hazeColor;
  }
}


class CharacterPainter extends CustomPainter {
  const CharacterPainter({
    required this.color,
  });

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawCircle(size.center(Offset.zero), size.shortestSide * 0.3, paint);
    canvas.drawOval(
      Rect.fromCenter(
        center: size.center(Offset.fromDirection(math.pi / -1.3, size.shortestSide * 0.15)),
        width: size.shortestSide * 0.05,
        height: size.shortestSide * 0.15,
      ), paint
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: size.center(Offset.fromDirection(math.pi / 1.3, size.shortestSide * -0.15)),
        width: size.shortestSide * 0.05,
        height: size.shortestSide * 0.15,
      ),
      paint,
    );
  canvas.drawLine(
    size.center(Offset.fromDirection(math.pi / 1.3, size.shortestSide * 0.15)),
    size.center(Offset.fromDirection(math.pi / -1.3, size.shortestSide * -0.15)),
    paint,
  );
  }

  @override
  bool shouldRepaint(covariant CharacterPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}