import 'package:flutter/material.dart';

/// A row that reveals by sliding in from both the left and right edges
/// of its parent and meeting in the middle, and does the reverse
/// (splitting back apart towards the edges) when the animation runs
/// backwards — e.g. while the page holding it is being left.
///
/// Wrap each row's content in this widget and drive it with a single
/// [animation] value: 0.0 is fully split apart (off to the sides),
/// 1.0 is fully joined (rendered normally, in place).
class SplitRevealRow extends StatelessWidget {
  const SplitRevealRow({
    super.key,
    required this.animation,
    required this.child,
  });

  /// 0.0 -> split apart (entrance not yet played / exit fully played)
  /// 1.0 -> fully joined, rendered normally
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value.clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            // How far each half still has to travel to meet in the
            // middle. At t = 0 this is the full half-width (fully off
            // to the side); at t = 1 this is 0 (fully joined).
            final travel = (1 - t) * (width / 2);

            return Opacity(
              // Fade alongside the slide so the split reads as one row
              // assembling, not two static crops sliding past each other.
              opacity: t,
              child: Stack(
                children: [
                  // Left half: clipped to the left side of the row,
                  // slides in from further left.
                  ClipRect(
                    clipper: _HalfClipper(side: _Side.left),
                    child: Transform.translate(
                      offset: Offset(-travel, 0),
                      child: child,
                    ),
                  ),
                  // Right half: clipped to the right side of the row,
                  // slides in from further right.
                  ClipRect(
                    clipper: _HalfClipper(side: _Side.right),
                    child: Transform.translate(
                      offset: Offset(travel, 0),
                      child: child,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

enum _Side { left, right }

class _HalfClipper extends CustomClipper<Rect> {
  _HalfClipper({required this.side});

  final _Side side;

  @override
  Rect getClip(Size size) {
    final half = size.width / 2;
    return side == _Side.left
        ? Rect.fromLTWH(0, 0, half, size.height)
        : Rect.fromLTWH(half, 0, half, size.height);
  }

  @override
  bool shouldReclip(covariant _HalfClipper oldClipper) {
    return oldClipper.side != side;
  }
}

/// Drives a list of [SplitRevealRow]s with a staggered entrance and,
/// symmetrically, a staggered exit — so leaving the page splits the
/// rows back apart in the same rhythm they arrived in, rather than
/// just cutting away.
///
/// Mix this into any State that already has a TickerProvider
/// (SingleTickerProviderStateMixin or TickerProviderStateMixin).
mixin SplitTableMixin<T extends StatefulWidget> on State<T> {
  late final AnimationController _controller;

  /// How many rows are being staggered. Override this — typically
  /// your list's length.
  int get rowCount;

  /// Total duration of the full staggered entrance/exit.
  Duration get splitDuration => const Duration(milliseconds: 1200);

  /// Call once in initState, after rowCount's backing data is ready
  /// (or 0 is fine — call restartSplitEntrance() once data loads).
  void initSplitTable(TickerProvider vsync) {
    _controller = AnimationController(
      vsync: vsync,
      duration: splitDuration,
    );
    _controller.forward();
  }

  /// Call this if row data finishes loading after initState (e.g.
  /// once an async backend call resolves) to (re)play the entrance.
  void restartSplitEntrance() {
    _controller.forward(from: 0);
  }

  void disposeSplitTable() {
    _controller.dispose();
  }

  /// The per-row animation to hand to [SplitRevealRow]. Rows stagger in
  /// order, each occupying a window of the full timeline.
  Animation<double> rowAnimation(int index) {
    final start = (rowCount == 0) ? 0.0 : (index / rowCount) * 0.7;
    final end = (start + 0.4).clamp(0.0, 1.0);

    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
      reverseCurve: Interval(start, end, curve: Curves.easeInCubic),
    );
  }

  /// Call this instead of Navigator.pop wherever the page's back
  /// button currently pops. Plays the split-apart exit to completion,
  /// then pops — so the rows visibly separate before the page leaves.
  Future<void> leaveWithSplit(BuildContext context, [Object? result]) async {
    await _controller.reverse();
    if (context.mounted) {
      Navigator.pop(context, result);
    }
  }
}