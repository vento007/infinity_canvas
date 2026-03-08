import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'schema_models.dart';

class DbSchemaBackgroundPainter extends CustomPainter {
  final Matrix4 transform;
  final double Function() readTimeSeconds;
  final Listenable repaint;

  DbSchemaBackgroundPainter({
    required this.transform,
    required this.readTimeSeconds,
    required this.repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final t = readTimeSeconds();
    final screenRect = Offset.zero & size;

    canvas.drawRect(
      screenRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF070D18), Color(0xFF0B1323), Color(0xFF0C1426)],
        ).createShader(screenRect),
    );

    final visibleWorld = _visibleWorldRect(transform, size).inflate(220);
    final zoom = transform.storage[0].abs().clamp(0.001, 1000.0);

    canvas.save();
    canvas.transform(transform.storage);

    final minorGrid = Paint()
      ..color = const Color(0xFF213450).withValues(alpha: 0.14)
      ..strokeWidth = 1 / zoom;
    final majorGrid = Paint()
      ..color = const Color(0xFF4A6C9D).withValues(alpha: 0.24)
      ..strokeWidth = 1.6 / zoom;

    const minor = 120.0;
    const major = 600.0;

    final startMinorX = (visibleWorld.left / minor).floor() * minor;
    for (var x = startMinorX; x <= visibleWorld.right; x += minor) {
      canvas.drawLine(
        Offset(x, visibleWorld.top),
        Offset(x, visibleWorld.bottom),
        minorGrid,
      );
    }
    final startMinorY = (visibleWorld.top / minor).floor() * minor;
    for (var y = startMinorY; y <= visibleWorld.bottom; y += minor) {
      canvas.drawLine(
        Offset(visibleWorld.left, y),
        Offset(visibleWorld.right, y),
        minorGrid,
      );
    }

    final startMajorX = (visibleWorld.left / major).floor() * major;
    for (var x = startMajorX; x <= visibleWorld.right; x += major) {
      canvas.drawLine(
        Offset(x, visibleWorld.top),
        Offset(x, visibleWorld.bottom),
        majorGrid,
      );
    }
    final startMajorY = (visibleWorld.top / major).floor() * major;
    for (var y = startMajorY; y <= visibleWorld.bottom; y += major) {
      canvas.drawLine(
        Offset(visibleWorld.left, y),
        Offset(visibleWorld.right, y),
        majorGrid,
      );
    }

    final pulse = 0.5 + 0.5 * math.sin(t * 0.35);
    final originGlow = Paint()
      ..color = const Color(0xFF7FDBFF).withValues(alpha: 0.06 + pulse * 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(Offset.zero, 680, originGlow);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DbSchemaBackgroundPainter oldDelegate) {
    return oldDelegate.transform != transform;
  }
}

class DbSchemaRelationsPainter extends CustomPainter {
  final Matrix4 transform;
  final List<DbRelation> relations;
  final Map<String, DbTableDef> tablesById;
  final String? selectedTableId;
  final double Function() readTimeSeconds;
  final Listenable repaint;

  DbSchemaRelationsPainter({
    required this.transform,
    required this.relations,
    required this.tablesById,
    required this.selectedTableId,
    required this.readTimeSeconds,
    required this.repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final t = readTimeSeconds();
    final visibleWorld = _visibleWorldRect(transform, size).inflate(260);
    final zoom = transform.storage[0].abs().clamp(0.001, 1000.0);

    canvas.save();
    canvas.transform(transform.storage);

    for (final relation in relations) {
      final fromTable = tablesById[relation.fromTableId];
      final toTable = tablesById[relation.toTableId];
      if (fromTable == null || toTable == null) continue;

      final fromRect = Rect.fromLTWH(
        fromTable.position.value.dx,
        fromTable.position.value.dy,
        fromTable.size.width,
        fromTable.size.height,
      );
      final toRect = Rect.fromLTWH(
        toTable.position.value.dx,
        toTable.position.value.dy,
        toTable.size.width,
        toTable.size.height,
      );

      final relationBounds = relation.selfReference
          ? fromRect.inflate(140)
          : Rect.fromPoints(fromRect.center, toRect.center).inflate(140);
      if (!visibleWorld.overlaps(relationBounds)) continue;

      final selected =
          selectedTableId != null &&
          (relation.fromTableId == selectedTableId ||
              relation.toTableId == selectedTableId);

      final lineColor = selected
          ? const Color(0xFFFFD66E)
          : const Color(0xFF66CCFF);
      final glowColor = selected
          ? const Color(0xFFFFC247)
          : const Color(0xFF67B8FF);

      final laneOffset = (((relation.id.hashCode & 0x7fffffff) % 5) - 2) * 10.0;
      final path = relation.selfReference
          ? _buildSelfLoopPath(
              fromRect,
              _columnCenterY(fromTable, relation.fromColumnName),
            )
          : _buildBetweenTablesPath(
              fromRect: fromRect,
              toRect: toRect,
              fromY: _columnCenterY(fromTable, relation.fromColumnName),
              toY: _columnCenterY(toTable, relation.toColumnName),
              laneOffset: laneOffset,
            );

      canvas.drawPath(
        path,
        Paint()
          ..color = glowColor.withValues(alpha: selected ? 0.28 : 0.09)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (selected ? 5.8 : 4.2) / zoom
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor.withValues(alpha: selected ? 0.95 : 0.58)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (selected ? 2.5 : 1.6) / zoom
          ..strokeCap = StrokeCap.round,
      );

      _drawArrowHead(canvas, path, zoom, lineColor.withValues(alpha: 0.95));
      _drawFlowDot(canvas, path, relation.id, t, zoom, lineColor);
    }

    canvas.restore();
  }

  double _columnCenterY(DbTableDef table, String columnName) {
    final rowIndex = table.columns.indexWhere((c) => c.name == columnName);
    final index = rowIndex < 0 ? 0 : rowIndex;
    return table.position.value.dy +
        SchemaCardMetrics.headerHeight +
        index * SchemaCardMetrics.rowHeight +
        SchemaCardMetrics.rowHeight * 0.5;
  }

  Path _buildBetweenTablesPath({
    required Rect fromRect,
    required Rect toRect,
    required double fromY,
    required double toY,
    required double laneOffset,
  }) {
    final toRight = toRect.center.dx >= fromRect.center.dx;
    final start = Offset(toRight ? fromRect.right : fromRect.left, fromY);
    final end = Offset(toRight ? toRect.left : toRect.right, toY);
    final dir = toRight ? 1.0 : -1.0;
    final midX = (start.dx + end.dx) * 0.5;
    final branchX = toRight
        ? math.max(start.dx + 90.0, midX)
        : math.min(start.dx - 90.0, midX);
    final y1 = start.dy + laneOffset;
    final y2 = end.dy + laneOffset;

    return Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(start.dx + dir * 34.0, start.dy)
      ..lineTo(branchX, y1)
      ..lineTo(branchX, y2)
      ..lineTo(end.dx - dir * 34.0, end.dy)
      ..lineTo(end.dx, end.dy);
  }

  Path _buildSelfLoopPath(Rect tableRect, double rowY) {
    final start = Offset(tableRect.right, rowY);
    final cp1 = Offset(tableRect.right + 96, rowY - 22);
    final cp2 = Offset(tableRect.right + 98, rowY + 58);
    final end = Offset(tableRect.right, rowY + 28);

    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
  }

  void _drawArrowHead(Canvas canvas, Path path, double zoom, Color color) {
    for (final metric in path.computeMetrics()) {
      final len = metric.length;
      if (len <= 1) continue;
      final tip = metric.getTangentForOffset(len);
      if (tip == null) continue;

      final size = 7 / zoom;
      final angle = tip.angle;
      final p = tip.position;
      final left =
          p + Offset(math.cos(angle + 2.6), math.sin(angle + 2.6)) * size;
      final right =
          p + Offset(math.cos(angle - 2.6), math.sin(angle - 2.6)) * size;

      final tri = Path()
        ..moveTo(p.dx, p.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
      canvas.drawPath(tri, Paint()..color = color);
      break;
    }
  }

  void _drawFlowDot(
    Canvas canvas,
    Path path,
    String id,
    double time,
    double zoom,
    Color color,
  ) {
    final hash = id.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    final phase = (hash % 1000) / 1000.0;
    final speed = 0.08 + (hash % 7) * 0.025;

    for (final metric in path.computeMetrics()) {
      if (metric.length <= 6) continue;
      final p = (phase + time * speed) % 1.0;
      final tangent = metric.getTangentForOffset(metric.length * p);
      if (tangent == null) continue;
      canvas.drawCircle(
        tangent.position,
        3.6 / zoom,
        Paint()..color = color.withValues(alpha: 0.96),
      );
      break;
    }
  }

  @override
  bool shouldRepaint(covariant DbSchemaRelationsPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.selectedTableId != selectedTableId ||
        oldDelegate.relations != relations ||
        oldDelegate.tablesById != tablesById;
  }
}

Rect _visibleWorldRect(Matrix4 transform, Size viewport) {
  final inv = Matrix4.tryInvert(transform);
  if (inv == null || viewport.isEmpty) {
    return Rect.fromLTWH(0, 0, 0, 0);
  }

  final p0 = MatrixUtils.transformPoint(inv, Offset.zero);
  final p1 = MatrixUtils.transformPoint(inv, Offset(viewport.width, 0));
  final p2 = MatrixUtils.transformPoint(inv, Offset(0, viewport.height));
  final p3 = MatrixUtils.transformPoint(
    inv,
    Offset(viewport.width, viewport.height),
  );

  final left = math.min(math.min(p0.dx, p1.dx), math.min(p2.dx, p3.dx));
  final right = math.max(math.max(p0.dx, p1.dx), math.max(p2.dx, p3.dx));
  final top = math.min(math.min(p0.dy, p1.dy), math.min(p2.dy, p3.dy));
  final bottom = math.max(math.max(p0.dy, p1.dy), math.max(p2.dy, p3.dy));

  return Rect.fromLTRB(left, top, right, bottom);
}
