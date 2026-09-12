import 'dart:math' as math;
import 'package:flutter/material.dart';

const Color kInk = Color(0xFF070B0C);
const Color kCyan = Color(0xFF22D3EE);

class RippleTransition extends StatefulWidget {
  final VoidCallback onComplete;

  const RippleTransition({
    super.key,
    required this.onComplete,
  });

  @override
  State<RippleTransition> createState() => _RippleTransitionState();
}

class _RippleTransitionState extends State<RippleTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _barToBall;
  late final Animation<double> _ballScale;
  late final Animation<double> _ballOpacity;
  late final Animation<double> _rippleProgress;
  late final Animation<double> _rippleOpacity;
  late final Animation<double> _screenFlash;

  bool _completed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );

    // ------------------------------------------------------------
    // 0.00 - 0.25
    // Loading bar transforms into a ball.
    // ------------------------------------------------------------
    _barToBall = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.00,
          0.25,
          curve: Curves.easeInOut,
        ),
      ),
    );

    // ------------------------------------------------------------
    // Ball starts large and rapidly shrinks away from the screen.
    // ------------------------------------------------------------
    _ballScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.08,
        ).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 0.04,
        ).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 88,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.18,
          0.68,
        ),
      ),
    );

    // Ball fades very slightly as it travels away.
    _ballOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.50,
          0.70,
          curve: Curves.easeIn,
        ),
      ),
    );

    // ------------------------------------------------------------
    // Water ripple expands from the point where the ball vanished.
    // ------------------------------------------------------------
    _rippleProgress = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.55,
          1.0,
          curve: Curves.easeOut,
        ),
      ),
    );

    _rippleOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ),
        weight: 80,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.55,
          1.0,
        ),
      ),
    );

    // Brief cyan flash as the ripple takes over the screen.
    _screenFlash = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 0.18,
        ),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.18,
          end: 0.0,
        ),
        weight: 65,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.72,
          1.0,
        ),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_completed) {
        _completed = true;

        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RipplePainter(
              barProgress: _barToBall.value,
              ballScale: _ballScale.value,
              ballOpacity: _ballOpacity.value,
              rippleProgress: _rippleProgress.value,
              rippleOpacity: _rippleOpacity.value,
              screenFlash: _screenFlash.value,
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// PAINTER
// ============================================================================

class _RipplePainter extends CustomPainter {
  final double barProgress;
  final double ballScale;
  final double ballOpacity;
  final double rippleProgress;
  final double rippleOpacity;
  final double screenFlash;

  _RipplePainter({
    required this.barProgress,
    required this.ballScale,
    required this.ballOpacity,
    required this.rippleProgress,
    required this.rippleOpacity,
    required this.screenFlash,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    // ------------------------------------------------------------
    // LOADING BAR → BALL
    // ------------------------------------------------------------

    if (barProgress > 0) {
      final maxBarWidth = math.min(
        size.width * 0.75,
        500.0,
      );

      final barWidth = maxBarWidth * barProgress;

      // The bar gets thicker as it turns into the ball.
      final thickness = 6.0 + (40.0 * (1.0 - barProgress));

      final barRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: barWidth,
          height: thickness,
        ),
        Radius.circular(thickness / 2),
      );

      final barPaint = Paint()
        ..color = kCyan
        ..style = PaintingStyle.fill;

      // Glow
      final glowPaint = Paint()
        ..color = kCyan.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          18,
        );

      canvas.drawRRect(barRect, glowPaint);
      canvas.drawRRect(barRect, barPaint);
    }

    // ------------------------------------------------------------
    // CYAN BALL
    // ------------------------------------------------------------

    if (barProgress < 0.9 && ballOpacity > 0) {
      final radius = 42.0 * ballScale;

      final glowPaint = Paint()
        ..color = kCyan.withOpacity(
          0.30 * ballOpacity,
        )
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          25,
        );

      final ballPaint = Paint()
        ..color = kCyan.withOpacity(ballOpacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        center,
        radius + 4,
        glowPaint,
      );

      canvas.drawCircle(
        center,
        radius,
        ballPaint,
      );
    }

    // ------------------------------------------------------------
    // WATER RIPPLE
    // ------------------------------------------------------------

    if (rippleProgress > 0) {
      _drawWaterRipples(
        canvas,
        size,
        center,
      );
    }

    // ------------------------------------------------------------
    // CYAN SCREEN FLASH
    // ------------------------------------------------------------

    if (screenFlash > 0) {
      final flashPaint = Paint()
        ..color = kCyan.withOpacity(screenFlash)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Offset.zero & size,
        flashPaint,
      );
    }
  }

  void _drawWaterRipples(
    Canvas canvas,
    Size size,
    Offset center,
  ) {
    final maxRadius = math.sqrt(
          size.width * size.width +
              size.height * size.height,
        ) *
        0.75;

    // Several rings at different distances.
    for (int i = 0; i < 6; i++) {
      final offset = i * 0.11;

      double progress =
          (rippleProgress - offset) / (1.0 - offset);

      progress = progress.clamp(0.0, 1.0);

      if (progress <= 0) continue;

      final radius = maxRadius * progress;

      final opacity =
          rippleOpacity * (1.0 - progress) * 0.45;

      final paint = Paint()
        ..color = kCyan.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + (1.0 - progress) * 3.0;

      canvas.drawCircle(
        center,
        radius,
        paint,
      );
    }

    // A few softer secondary ripples.
    for (int i = 0; i < 4; i++) {
      final offset = i * 0.17;

      double progress =
          (rippleProgress - offset) / (1.0 - offset);

      progress = progress.clamp(0.0, 1.0);

      if (progress <= 0) continue;

      final radius = maxRadius * progress * 0.82;

      final paint = Paint()
        ..color = kCyan.withOpacity(
          rippleOpacity *
              (1.0 - progress) *
              0.16,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0;

      canvas.drawCircle(
        center,
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.barProgress != barProgress ||
        oldDelegate.ballScale != ballScale ||
        oldDelegate.ballOpacity != ballOpacity ||
        oldDelegate.rippleProgress != rippleProgress ||
        oldDelegate.rippleOpacity != rippleOpacity ||
        oldDelegate.screenFlash != screenFlash;
  }
}