import 'dart:math';
import 'package:flutter/material.dart';

/// A single node in the graph, with a fixed "home" position and a
/// phase offset so it drifts independently of the others.
class _GraphNode {
  final Offset home;
  final double phase;
  final double driftRadius;
  final double radius; // visual dot size

  const _GraphNode({
    required this.home,
    required this.phase,
    required this.driftRadius,
    required this.radius,
  });
}

/// Paints nodes as small glowing dots and draws lines between nodes
/// that are close enough to each other, fading out with distance.
class NodeGraphPainter extends CustomPainter {
  final List<_GraphNode> nodes;
  final double t; // animation progress, 0..1 looping
  final Color color;
  final double connectDistance;

  NodeGraphPainter({
    required this.nodes,
    required this.t,
    required this.connectDistance,
    this.color = const Color(0xFF22D3EE),
  });

  Offset _positionOf(_GraphNode n) {
    final angle = n.phase + t * 2 * pi;
    return n.home +
        Offset(cos(angle) * n.driftRadius, sin(angle * 0.8) * n.driftRadius);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final positions = nodes.map(_positionOf).toList();

    final linePaint = Paint()..style = PaintingStyle.stroke;

    // Connections between nearby nodes.
    for (var i = 0; i < positions.length; i++) {
      for (var j = i + 1; j < positions.length; j++) {
        final dist = (positions[i] - positions[j]).distance;
        if (dist <= connectDistance) {
          final strength = (1 - dist / connectDistance).clamp(0.0, 1.0);
          linePaint
            ..color = color.withOpacity(0.06 + strength * 0.22)
            ..strokeWidth = 0.8 + strength * 0.6;
          canvas.drawLine(positions[i], positions[j], linePaint);
        }
      }
    }

    // Nodes themselves: a soft outer glow plus a solid core dot.
    final glowPaint = Paint()..style = PaintingStyle.fill;
    final corePaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < positions.length; i++) {
      final p = positions[i];
      final r = nodes[i].radius;

      glowPaint.color = color.withOpacity(0.12);
      canvas.drawCircle(p, r * 3, glowPaint);

      corePaint.color = color.withOpacity(0.75);
      canvas.drawCircle(p, r, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant NodeGraphPainter oldDelegate) => oldDelegate.t != t;
}

/// An ambient animated node graph: a cluster of dots that drift slowly
/// and connect with lines when close together, like a small network
/// diagram. Purely decorative — wrap in `IgnorePointer` if placed over
/// interactive content (already ignores pointers internally).
class AnimatedNodeGraph extends StatefulWidget {
  final double width;
  final double height;
  final int nodeCount;
  final Color color;
  final Duration driftSpeed;
  final double connectDistance;
  final int seed;

  const AnimatedNodeGraph({
    super.key,
    this.width = 220,
    this.height = 420,
    this.nodeCount = 14,
    this.color = const Color(0xFF22D3EE),
    this.driftSpeed = const Duration(seconds: 20),
    this.connectDistance = 110,
    this.seed = 3,
  });

  @override
  State<AnimatedNodeGraph> createState() => _AnimatedNodeGraphState();
}

class _AnimatedNodeGraphState extends State<AnimatedNodeGraph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<_GraphNode> _nodes;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.driftSpeed)
      ..repeat();
    _nodes = _generateNodes();
  }

  List<_GraphNode> _generateNodes() {
    final random = Random(widget.seed);
    return List.generate(widget.nodeCount, (_) {
      return _GraphNode(
        home: Offset(
          random.nextDouble() * widget.width,
          random.nextDouble() * widget.height,
        ),
        phase: random.nextDouble() * 2 * pi,
        driftRadius: 6 + random.nextDouble() * 14,
        radius: 2.0 + random.nextDouble() * 2.0,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: NodeGraphPainter(
                nodes: _nodes,
                t: _controller.value,
                color: widget.color,
                connectDistance: widget.connectDistance,
              ),
            );
          },
        ),
      ),
    );
  }
}
