import 'package:flutter/material.dart';

class LuxuryNeonBackdrop extends StatelessWidget {
  const LuxuryNeonBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF05080E), Color(0xFF0A111B), Color(0xFF0E1724)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: const [
          Positioned.fill(child: _ShadowBands()),
          Positioned(
            top: -70,
            right: -150,
            child: _ShadowPanel(
              width: 560,
              height: 160,
              angle: -0.38,
              color: Color(0xAA254264),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -180,
            child: _ShadowPanel(
              width: 620,
              height: 170,
              angle: 0.34,
              color: Color(0xAA1B3553),
            ),
          ),
          Positioned(
            top: 160,
            left: -220,
            child: _ShadowPanel(
              width: 500,
              height: 120,
              angle: 0.18,
              color: Color(0x99264366),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShadowBands extends StatelessWidget {
  const _ShadowBands();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _ShadowBandsPainter()));
  }
}

class _ShadowBandsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final band = Paint()
      ..color = const Color(0xFF6C87A7).withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const gap = 38.0;
    for (double x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), band);
    }

    final softVignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.92,
        colors: [
          const Color(0x00000000),
          const Color(0xFF000000).withValues(alpha: 0.28),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, softVignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShadowPanel extends StatelessWidget {
  const _ShadowPanel({
    required this.width,
    required this.height,
    required this.angle,
    required this.color,
  });

  final double width;
  final double height;
  final double angle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(120),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [color.withValues(alpha: 0.18), Colors.transparent],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 80,
              spreadRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}
