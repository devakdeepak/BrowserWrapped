import 'dart:math' as math;
import 'package:flutter/material.dart';

const kInk = Color(0xFF070B0C);
const kCyan = Color(0xFF22D3EE);

class DynamicBackground extends StatefulWidget {
  const DynamicBackground({super.key});

  @override
  State<DynamicBackground> createState() => _DynamicBackgroundState();
}

class _DynamicBackgroundState extends State<DynamicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    // Controls both movement and curve deformation.
    // The movement itself remains linear.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _FlowingLinesPainter(
                progress: _controller.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FlowingLinesPainter extends CustomPainter {
  final double progress;

  _FlowingLinesPainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = kInk,
    );

    _drawLine(
      canvas,
      size,
      y: 0.12,
      amplitude: 50,
      wavelength: 520,
      movementSpeed: 1.0,
      curveSpeed: 1.0,
      opacity: 0.10,
    );

    _drawLine(
      canvas,
      size,
      y: 0.27,
      amplitude: 70,
      wavelength: 620,
      movementSpeed: 0.75,
      curveSpeed: 1.35,
      opacity: 0.055,
    );

    _drawLine(
      canvas,
      size,
      y: 0.43,
      amplitude: 45,
      wavelength: 450,
      movementSpeed: 1.15,
      curveSpeed: 0.9,
      opacity: 0.08,
    );

    _drawLine(
      canvas,
      size,
      y: 0.59,
      amplitude: 80,
      wavelength: 700,
      movementSpeed: 0.65,
      curveSpeed: 1.5,
      opacity: 0.045,
    );

    _drawLine(
      canvas,
      size,
      y: 0.73,
      amplitude: 55,
      wavelength: 500,
      movementSpeed: 0.9,
      curveSpeed: 1.2,
      opacity: 0.075,
    );

    _drawLine(
      canvas,
      size,
      y: 0.88,
      amplitude: 75,
      wavelength: 650,
      movementSpeed: 0.8,
      curveSpeed: 1.4,
      opacity: 0.05,
    );
  }

  void _drawLine(
    Canvas canvas,
    Size size, {
    required double y,
    required double amplitude,
    required double wavelength,
    required double movementSpeed,
    required double curveSpeed,
    required double opacity,
  }) {
    final path = Path();

    // ------------------------------------------------------------
    // HORIZONTAL MOVEMENT
    // ------------------------------------------------------------

    final movement =
        progress * wavelength * movementSpeed;

    final startX =
        -wavelength + movement;

    // ------------------------------------------------------------
    // CURVE MOVEMENT
    // ------------------------------------------------------------

    // This controls how quickly the actual shape of the
    // curve changes.
    final curveTime =
        progress *
        math.pi *
        2 *
        curveSpeed;

    const resolution = 220;

    for (int i = 0; i <= resolution; i++) {
      final x =
          startX +
          (size.width + wavelength) *
              i /
              resolution;

      final normalizedX =
          x / wavelength;

      // Main curve.
      final wave1 = math.sin(
        normalizedX * math.pi * 2.0 +
            curveTime,
      );

      // Secondary curve.
      final wave2 = math.sin(
        normalizedX * math.pi * 4.0 -
            curveTime * 0.7,
      );

      // Third smaller deformation.
      final wave3 = math.sin(
        normalizedX * math.pi * 7.0 +
            curveTime * 1.3,
      );

      final wave =
          wave1 * 0.65 +
          wave2 * 0.25 +
          wave3 * 0.10;

      final baseY =
          size.height * y;

      final currentY =
          baseY +
          wave * amplitude;

      if (i == 0) {
        path.moveTo(x, currentY);
      } else {
        path.lineTo(x, currentY);
      }
    }

    // ------------------------------------------------------------
    // GLOW
    // ------------------------------------------------------------

    final glowPaint = Paint()
      ..color = kCyan.withOpacity(
        opacity * 0.22,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        8,
      );

    canvas.drawPath(
      path,
      glowPaint,
    );

    // ------------------------------------------------------------
    // MAIN LINE
    // ------------------------------------------------------------

    final paint = Paint()
      ..color = kCyan.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      path,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _FlowingLinesPainter oldDelegate,
  ) {
    return oldDelegate.progress != progress;
  }
}