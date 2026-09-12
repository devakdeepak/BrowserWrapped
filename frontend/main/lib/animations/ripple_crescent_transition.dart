import 'package:flutter/material.dart';

const Color kInk = Color(0xFF121212);
const Color kCyan = Color(0xFF22D3EE);

/// A left-to-right wipe transition: one large crescent-shaped wave,
/// tall enough to touch the top and bottom of the screen, sweeps from
/// the left edge to the right edge. Everything behind it (to its left)
/// is blackened as it passes. A couple of fainter trailing wave lines
/// follow behind the main crescent for a rippling effect.
///
/// No ball, no drop — purely the crescent wave moving through.
class RippleCrescentTransition extends StatefulWidget {
  final VoidCallback onComplete;
  final Color fillColor;
  final Color waveColor;
  final Duration duration;

  const RippleCrescentTransition({
    super.key,
    required this.onComplete,
    this.fillColor = kInk,
    this.waveColor = kCyan,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<RippleCrescentTransition> createState() => _RippleCrescentTransitionState();
}

class _RippleCrescentTransitionState extends State<RippleCrescentTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _completed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_completed) {
          _completed = true;
          widget.onComplete();
        }
      })
      ..forward();
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
        builder: (context, _) {
          return CustomPaint(
            painter: _CrescentWipePainter(
              t: Curves.easeInOut.transform(_controller.value),
              fillColor: widget.fillColor,
              waveColor: widget.waveColor,
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

class _CrescentWipePainter extends CustomPainter {
  final double t; // 0..1, eased progress of the sweep
  final Color fillColor;
  final Color waveColor;

  _CrescentWipePainter({
    required this.t,
    required this.fillColor,
    required this.waveColor,
  });

  /// Builds the curved leading edge: a single big crescent bulging
  /// rightward, anchored at the top and bottom of the screen so it
  /// always spans edge to edge vertically.
  Path _crescentEdge(double leadX, double bulge, Size size) {
    return Path()
      ..moveTo(leadX, 0)
      ..quadraticBezierTo(leadX + bulge, size.height / 2, leadX, size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // How far the crescent's belly pushes out to the right of its
    // top/bottom anchor points. Sized off the screen height so the
    // curve reads as one decently big wave, not a subtle notch.
    final bulge = size.height * 0.55;

    // The crescent travels from fully off the left edge to fully off
    // the right edge, sweeping left -> right.
    final travel = size.width + bulge * 2;
    final leadX = -bulge + t * travel;
    final clampedLeadX = leadX.clamp(0.0, size.width);

    // ------------------------------------------------------------
    // Blackened region: everything already swept, to the left of
    // the crescent's leading edge.
    // ------------------------------------------------------------
    final fillPath = Path()
      ..moveTo(0, 0)
      ..lineTo(clampedLeadX, 0)
      ..quadraticBezierTo(clampedLeadX + bulge, size.height / 2, clampedLeadX, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, Paint()..color = fillColor);

    // ------------------------------------------------------------
    // The main leading crescent wave — bright, glowing, edge to edge.
    // ------------------------------------------------------------
    final leadPath = _crescentEdge(leadX, bulge, size);

    final glowPaint = Paint()
      ..color = waveColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawPath(leadPath, glowPaint);

    final leadPaint = Paint()
      ..color = waveColor.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(leadPath, leadPaint);

    // ------------------------------------------------------------
    // Fainter trailing wave lines following behind the main crescent,
    // already inside the blackened region — the "ripple" feel.
    // ------------------------------------------------------------
    for (var i = 1; i <= 3; i++) {
      final trailX = leadX - i * (bulge * 0.45);
      if (trailX < -bulge || trailX > size.width + bulge) continue;

      final trailBulge = bulge * (1 - i * 0.18);
      final trailPath = _crescentEdge(trailX, trailBulge, size);

      final trailPaint = Paint()
        ..color = waveColor.withOpacity(0.28 / i)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(trailPath, trailPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrescentWipePainter oldDelegate) => oldDelegate.t != t;
}