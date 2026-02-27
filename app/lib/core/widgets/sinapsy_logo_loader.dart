import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated Sinapsy login logo reused for loading states.
class SinapsyAnimatedLogo extends StatefulWidget {
  const SinapsyAnimatedLogo({super.key, required this.size});

  final double size;

  @override
  State<SinapsyAnimatedLogo> createState() => _SinapsyAnimatedLogoState();
}

class _SinapsyAnimatedLogoState extends State<SinapsyAnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 9200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _AtomLogoPainter(progress: _controller.value),
        );
      },
    );
  }
}

class SinapsyLogoLoader extends StatelessWidget {
  const SinapsyLogoLoader({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SinapsyAnimatedLogo(size: size),
    );
  }
}

class _AtomLogoPainter extends CustomPainter {
  const _AtomLogoPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final spin = progress * math.pi * 2;
    final minSide = size.shortestSide;
    final orbitA = minSide * 0.34;
    final orbitB = minSide * 0.13;
    final nucleusRadius = minSide * 0.09;
    final orbitStroke = math.max(0.95, minSide * 0.012);
    final electronRadius = math.max(1.0, minSide * 0.017);
    final orbitAngles = <double>[0, math.pi / 3, -math.pi / 3];
    final globalRotation = spin;
    final pulse = 0.92 + 0.08 * math.sin(spin);

    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF76A9FF).withValues(alpha: 0.2 * pulse),
          const Color(0xFF76A9FF).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: minSide * 0.48));
    canvas.drawCircle(center, minSide * 0.48, haloPaint);

    final orbitGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = orbitStroke * 1.9
      ..color = const Color(0xFF7DAFFF).withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = orbitStroke
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5FAFF), Color(0xFFD3E7FF), Color(0xFF74A8FF)],
      ).createShader(Rect.fromCircle(center: center, radius: orbitA));

    for (int i = 0; i < orbitAngles.length; i++) {
      final rotation = orbitAngles[i] + globalRotation;
      _drawOrbit(
        canvas: canvas,
        center: center,
        a: orbitA,
        b: orbitB,
        rotation: rotation,
        paint: orbitGlowPaint,
      );
      _drawOrbit(
        canvas: canvas,
        center: center,
        a: orbitA,
        b: orbitB,
        rotation: rotation,
        paint: orbitPaint,
      );

      final electronAngle = spin + (i * (math.pi * 2 / orbitAngles.length));
      final electron = _ellipsePoint(
        center: center,
        a: orbitA,
        b: orbitB,
        angle: electronAngle,
        rotation: rotation,
      );
      final electronGlow = Paint()
        ..color = const Color(0xFFDCEAFF).withValues(alpha: 0.88)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(electron, electronRadius * 1.6, electronGlow);
      canvas.drawCircle(
        electron,
        electronRadius,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }

    final coreDotGlow = Paint()
      ..color = const Color(0xFFDCEAFF).withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final coreDot = Paint()
      ..color = const Color(0xFFF8FBFF).withValues(alpha: 0.95);
    canvas.drawCircle(center, nucleusRadius * 0.52, coreDotGlow);
    canvas.drawCircle(center, nucleusRadius * 0.3, coreDot);
  }

  void _drawOrbit({
    required Canvas canvas,
    required Offset center,
    required double a,
    required double b,
    required double rotation,
    required Paint paint,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: a * 2, height: b * 2),
      paint,
    );
    canvas.restore();
  }

  Offset _ellipsePoint({
    required Offset center,
    required double a,
    required double b,
    required double angle,
    required double rotation,
  }) {
    final x = a * math.cos(angle);
    final y = b * math.sin(angle);
    final xr = x * math.cos(rotation) - y * math.sin(rotation);
    final yr = x * math.sin(rotation) + y * math.cos(rotation);
    return Offset(center.dx + xr, center.dy + yr);
  }

  @override
  bool shouldRepaint(covariant _AtomLogoPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
