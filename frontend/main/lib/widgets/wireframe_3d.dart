import 'dart:math';
import 'package:flutter/material.dart';

/// A simple 3D point.
class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);
}

/// A wireframe object: a set of vertices plus edges (pairs of vertex indices).
class Object3D {
  final List<Vec3> vertices;
  final List<List<int>> edges;

  const Object3D(this.vertices, this.edges);

  /// A square-based pyramid.
  factory Object3D.pyramid({double size = 1}) {
    final vertices = [
      Vec3(0, -size, 0), // apex (0)
      Vec3(-size, size, -size), // base (1)
      Vec3(size, size, -size), // base (2)
      Vec3(size, size, size), // base (3)
      Vec3(-size, size, size), // base (4)
    ];
    final edges = [
      [0, 1], [0, 2], [0, 3], [0, 4], // apex to each base corner
      [1, 2], [2, 3], [3, 4], [4, 1], // base perimeter
    ];
    return Object3D(vertices, edges);
  }

  /// A lat/long wireframe sphere.
  factory Object3D.sphere({int latSteps = 8, int lonSteps = 12, double radius = 1}) {
    final vertices = <Vec3>[];
    final edges = <List<int>>[];

    for (int i = 0; i <= latSteps; i++) {
      final theta = pi * i / latSteps; // 0 (top) .. pi (bottom)
      for (int j = 0; j < lonSteps; j++) {
        final phi = 2 * pi * j / lonSteps;
        final x = radius * sin(theta) * cos(phi);
        final y = radius * cos(theta);
        final z = radius * sin(theta) * sin(phi);
        vertices.add(Vec3(x, y, z));
      }
    }

    for (int i = 0; i <= latSteps; i++) {
      for (int j = 0; j < lonSteps; j++) {
        final current = i * lonSteps + j;
        final nextInRing = i * lonSteps + (j + 1) % lonSteps;
        edges.add([current, nextInRing]); // latitude ring
        if (i < latSteps) {
          final nextRing = (i + 1) * lonSteps + j;
          edges.add([current, nextRing]); // meridian line
        }
      }
    }

    return Object3D(vertices, edges);
  }
}

/// Projects and paints a wireframe object with simple perspective projection.
class Wireframe3DPainter extends CustomPainter {
  final Object3D object;
  final double rotationX;
  final double rotationY;
  final Color color;
  final double strokeWidth;
  final double perspective; // "focal length" — lower = more dramatic depth
  final double depthOffset; // pushes the object away from the camera

  Wireframe3DPainter({
    required this.object,
    required this.rotationX,
    required this.rotationY,
    this.color = const Color(0xFF22D3EE),
    this.strokeWidth = 1.1,
    this.perspective = 2.6,
    this.depthOffset = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.shortestSide / 2.3;

    final projected = <Offset>[];
    final depths = <double>[];

    final cosY = cos(rotationY), sinY = sin(rotationY);
    final cosX = cos(rotationX), sinX = sin(rotationX);

    for (final v in object.vertices) {
      // Rotate around Y axis.
      final x1 = v.x * cosY + v.z * sinY;
      final z1 = -v.x * sinY + v.z * cosY;

      // Rotate around X axis.
      final y2 = v.y * cosX - z1 * sinX;
      final z2 = v.y * sinX + z1 * cosX;

      final z3 = z2 + depthOffset;
      final p = perspective / z3;

      projected.add(Offset(center.dx + x1 * scale * p, center.dy + y2 * scale * p));
      depths.add(z3);
    }

    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final edge in object.edges) {
      final a = projected[edge[0]];
      final b = projected[edge[1]];
      final avgDepth = (depths[edge[0]] + depths[edge[1]]) / 2;

      // Nearer edges are drawn a little brighter than far ones.
      final t = ((avgDepth - (depthOffset - 1)) / 2).clamp(0.0, 1.0);
      final opacity = ((1.0 - t) * 0.5 + 0.15).clamp(0.12, 0.65);
      paint.color = color.withOpacity(opacity);

      canvas.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(covariant Wireframe3DPainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.color != color;
  }
}

enum WireframeShapeType { pyramid, sphere }

/// A continuously tumbling 3D wireframe shape, for use as ambient
/// decoration in empty page margins.
class AnimatedWireframeShape extends StatefulWidget {
  final WireframeShapeType type;
  final double size;
  final Color color;
  final Duration rotationSpeed;
  final double tiltX;

  const AnimatedWireframeShape({
    super.key,
    required this.type,
    this.size = 140,
    this.color = const Color(0xFF22D3EE),
    this.rotationSpeed = const Duration(seconds: 16),
    this.tiltX = 0.5,
  });

  @override
  State<AnimatedWireframeShape> createState() => _AnimatedWireframeShapeState();
}

class _AnimatedWireframeShapeState extends State<AnimatedWireframeShape>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Object3D _object;

  @override
  void initState() {
    super.initState();
    _object = widget.type == WireframeShapeType.pyramid
        ? Object3D.pyramid()
        : Object3D.sphere();
    _controller = AnimationController(vsync: this, duration: widget.rotationSpeed)..repeat();
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
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * 2 * pi;
            return CustomPaint(
              painter: Wireframe3DPainter(
                object: _object,
                rotationY: t,
                rotationX: widget.tiltX + sin(t) * 0.18,
                color: widget.color,
              ),
            );
          },
        ),
      ),
    );
  }
}
