import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'node_model.dart';

class InfiniteGridPainter extends CustomPainter {
  final Matrix4 transform;

  const InfiniteGridPainter({required this.transform});

  Offset _worldToScreen(Offset world) {
    final m = transform.storage;
    return Offset(
      world.dx * m[0] + world.dy * m[4] + m[12],
      world.dx * m[1] + world.dy * m[5] + m[13],
    );
  }

  Offset _screenToWorld(Offset screen) {
    final m = transform.storage;
    final sx = m[0];
    final sy = m[5];
    final tx = m[12];
    final ty = m[13];
    if (sx.abs() > 1e-9 && sy.abs() > 1e-9) {
      return Offset((screen.dx - tx) / sx, (screen.dy - ty) / sy);
    }
    return screen;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color.fromARGB(255, 238, 239, 240),
    );

    final sx = transform.storage[0].abs();
    final sy = transform.storage[5].abs();
    final scale = ((sx + sy) * 0.5).clamp(1e-6, double.infinity);

    double spacing = 50.0;
    while (spacing * scale < 28.0) {
      spacing *= 2.0;
    }
    while (spacing * scale > 120.0) {
      spacing /= 2.0;
    }

    final corners = <Offset>[
      _screenToWorld(Offset.zero),
      _screenToWorld(Offset(size.width, 0)),
      _screenToWorld(Offset(0, size.height)),
      _screenToWorld(Offset(size.width, size.height)),
    ];
    final left = corners.map((p) => p.dx).reduce(math.min);
    final right = corners.map((p) => p.dx).reduce(math.max);
    final top = corners.map((p) => p.dy).reduce(math.min);
    final bottom = corners.map((p) => p.dy).reduce(math.max);

    final minorPaint = Paint()
      ..color = const Color(0x18000000)
      ..strokeWidth = 1.0;
    final majorPaint = Paint()
      ..color = const Color(0x28000000)
      ..strokeWidth = 1.2;
    final axisPaint = Paint()
      ..color = const Color(0x66000000)
      ..strokeWidth = 1.5;

    const majorEvery = 5;

    final startX = (left / spacing).floor() - 1;
    final endX = (right / spacing).ceil() + 1;
    for (var i = startX; i <= endX; i++) {
      final x = i * spacing;
      final a = _worldToScreen(Offset(x, top));
      final b = _worldToScreen(Offset(x, bottom));
      final paint = i == 0
          ? axisPaint
          : (i % majorEvery == 0 ? majorPaint : minorPaint);
      canvas.drawLine(a, b, paint);
    }

    final startY = (top / spacing).floor() - 1;
    final endY = (bottom / spacing).ceil() + 1;
    for (var j = startY; j <= endY; j++) {
      final y = j * spacing;
      final a = _worldToScreen(Offset(left, y));
      final b = _worldToScreen(Offset(right, y));
      final paint = j == 0
          ? axisPaint
          : (j % majorEvery == 0 ? majorPaint : minorPaint);
      canvas.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(covariant InfiniteGridPainter oldDelegate) {
    return oldDelegate.transform != transform;
  }
}

class NodeLinksPainter extends CustomPainter {
  final List<DemoNode> nodes;
  final int columns;
  final Offset Function(DemoNode node) worldPositionOf;
  final Matrix4 transform;
  final Listenable repaintListenable;

  NodeLinksPainter({
    required this.nodes,
    required this.columns,
    required this.worldPositionOf,
    required this.transform,
    required this.repaintListenable,
  }) : super(repaint: repaintListenable);

  Offset _worldToScreen(Offset world) {
    final m = transform.storage;
    return Offset(
      world.dx * m[0] + world.dy * m[4] + m[12],
      world.dx * m[1] + world.dy * m[5] + m[13],
    );
  }

  Offset _nodeCenter(DemoNode n) {
    final p = worldPositionOf(n);
    final s = n.size.value;
    return Offset(p.dx + (s.width * 0.5), p.dy + (s.height * 0.5));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty || columns <= 0) return;
    final p = Paint()
      ..color = const Color(0x6609A9C8)
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke;

    final visible = Offset.zero & size;
    final padded = visible.inflate(80);
    final count = nodes.length;

    for (var i = 0; i < count; i++) {
      final row = i ~/ columns;
      final col = i % columns;
      final a = _worldToScreen(_nodeCenter(nodes[i]));

      void drawLink(int j) {
        if (j >= count) return;
        final b = _worldToScreen(_nodeCenter(nodes[j]));
        final segmentBounds = Rect.fromPoints(a, b).inflate(8);
        if (!padded.overlaps(segmentBounds)) return;
        canvas.drawLine(a, b, p);
      }

      if (col + 1 < columns) {
        drawLink(i + 1);
      }
      drawLink(i + columns);
      if (row % 2 == 0 && col + 2 < columns) {
        drawLink(i + 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant NodeLinksPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.columns != columns ||
        oldDelegate.worldPositionOf != worldPositionOf ||
        oldDelegate.transform != transform ||
        oldDelegate.repaintListenable != repaintListenable;
  }
}
