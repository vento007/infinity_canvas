import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mega_components.dart';
import 'mega_engine.dart';

class TdMegaBackdropPainter extends CustomPainter {
  final Matrix4 transform;

  TdMegaBackdropPainter({required this.transform});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0A0F1D),
    );

    final scale = transform.storage[0];
    final tx = transform.storage[12];
    final ty = transform.storage[13];

    const worldStep = 240.0;
    final step = worldStep * scale;
    if (step.abs() < 6) return;

    double firstLine(double spacing, double offset) {
      if (spacing == 0) return 0;
      final m = offset % spacing;
      return m <= 0 ? -m : spacing - m;
    }

    final minor = Paint()
      ..color = const Color(0x18305A84)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = const Color(0x2D4E8DC7)
      ..strokeWidth = 1.1;

    final startX = firstLine(step, tx);
    final startY = firstLine(step, ty);
    final majorStep = step * 5;
    final majorX = firstLine(majorStep, tx);
    final majorY = firstLine(majorStep, ty);

    for (double x = startX; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minor);
    }
    for (double y = startY; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minor);
    }
    for (double x = majorX; x <= size.width; x += majorStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), major);
    }
    for (double y = majorY; y <= size.height; y += majorStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), major);
    }
  }

  @override
  bool shouldRepaint(covariant TdMegaBackdropPainter oldDelegate) {
    return oldDelegate.transform != transform;
  }
}

class TdMegaWorldPainter extends CustomPainter {
  final Matrix4 transform;
  final TdMegaMapEngine engine;
  final bool paintCreeps;

  TdMegaWorldPainter({
    required this.transform,
    required this.engine,
    this.paintCreeps = true,
    required super.repaint,
  });

  Offset _toScreen(Offset world) =>
      MatrixUtils.transformPoint(transform, world);

  double _scaleLength(double worldLen) {
    final a = MatrixUtils.transformPoint(transform, Offset.zero);
    final b = MatrixUtils.transformPoint(transform, Offset(worldLen, 0));
    return (b - a).distance;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawBoardBounds(canvas);
    _drawLanes(canvas);
    _drawPads(canvas);
    _drawTowers(canvas);
    if (paintCreeps) {
      _drawCreeps(canvas);
    }
  }

  void _drawBoardBounds(Canvas canvas) {
    final r = engine.boardBounds;
    final tl = _toScreen(r.topLeft);
    final tr = _toScreen(r.topRight);
    final bl = _toScreen(r.bottomLeft);
    final w = (tr.dx - tl.dx).abs();
    final h = (bl.dy - tl.dy).abs();
    final rect = Rect.fromLTWH(tl.dx, tl.dy, w, h);

    canvas.drawRect(rect, Paint()..color = const Color(0x0E4E89C7));
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0x5580C4FF),
    );
  }

  void _drawLanes(Canvas canvas) {
    final baseWidth = math.max(4.0, _scaleLength(engine.laneWorldWidth));
    for (var i = 0; i < engine.lanes.length; i++) {
      final lane = engine.lanes[i];
      if (lane.points.length < 2) continue;
      final first = _toScreen(lane.points.first);
      final path = Path()..moveTo(first.dx, first.dy);
      for (var pIndex = 1; pIndex < lane.points.length; pIndex++) {
        final p = _toScreen(lane.points[pIndex]);
        path.lineTo(p.dx, p.dy);
      }

      final laneHue = (i * (330.0 / math.max(1, engine.lanes.length))) % 360;
      final coreColor = HSLColor.fromAHSL(1.0, laneHue, 0.72, 0.56).toColor();

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = baseWidth + 8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0x3312182A),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = baseWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = coreColor.withValues(alpha: 0.28),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, baseWidth * 0.09)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withValues(alpha: 0.20),
      );
    }
  }

  void _drawPads(Canvas canvas) {
    final radius = _scaleLength(18).clamp(2.0, 16.0);
    for (final pad in engine.towerPads) {
      final p = _toScreen(pad);
      canvas.drawCircle(p, radius, Paint()..color = const Color(0xFF2C3C55));
      canvas.drawCircle(
        p,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x669CC7EF),
      );
    }
  }

  void _drawTowers(Canvas canvas) {
    for (final q in engine.world.query2<MegaPositionC, MegaTowerC>()) {
      final pos = _toScreen(q.component1.offset);
      final tower = q.component2;
      final radius = _scaleLength(tower.radius).clamp(2.6, 18.0);

      canvas.drawCircle(pos, radius, Paint()..color = const Color(0xFF102738));
      canvas.drawCircle(
        pos,
        radius * 0.62,
        Paint()..color = const Color(0xFF37C6F3),
      );
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0x88BEEAFF),
      );
    }
  }

  void _drawCreeps(Canvas canvas) {
    for (final q in engine.world.query2<MegaPositionC, MegaCreepC>()) {
      final pos = _toScreen(q.component1.offset);
      final creep = q.component2;
      final radius = _scaleLength(creep.radius).clamp(1.2, 8.0);
      final color = HSLColor.fromAHSL(1.0, creep.hue, 0.76, 0.56).toColor();
      canvas.drawCircle(pos, radius, Paint()..color = color);
      canvas.drawCircle(
        pos,
        radius * 1.55,
        Paint()..color = color.withValues(alpha: 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(covariant TdMegaWorldPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.engine != engine ||
        oldDelegate.paintCreeps != paintCreeps;
  }
}
