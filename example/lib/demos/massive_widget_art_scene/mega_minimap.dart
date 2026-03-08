import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

import 'mega_components.dart';
import 'mega_engine.dart';

const Size tdMegaMiniMapSize = Size(260, 176);
const EdgeInsets tdMegaMiniMapMargin = EdgeInsets.all(14);

class TdMegaMiniMapOverlay extends StatefulWidget {
  final TdMegaMapEngine engine;
  final CanvasLayerController controller;
  final Listenable repaint;

  const TdMegaMiniMapOverlay({
    super.key,
    required this.engine,
    required this.controller,
    required this.repaint,
  });

  @override
  State<TdMegaMiniMapOverlay> createState() => _TdMegaMiniMapOverlayState();
}

class _TdMegaMiniMapOverlayState extends State<TdMegaMiniMapOverlay> {
  int? _activePointer;
  bool _panWasEnabled = true;

  void _centerCameraAt(Offset localPoint) {
    final projection = _TdMegaMiniProjection.fromEngine(
      size: tdMegaMiniMapSize,
      engine: widget.engine,
      controller: widget.controller,
    );
    if (projection == null) return;

    final viewportSize =
        widget.controller.camera.renderStats?.viewportSize ?? Size.zero;
    if (viewportSize.isEmpty) return;

    final targetWorld = projection.miniToWorld(
      localPoint,
      clampToContent: true,
    );
    final viewportCenter = Offset(
      viewportSize.width * 0.5,
      viewportSize.height * 0.5,
    );
    final currentScreen = widget.controller.camera.worldToScreen(targetWorld);
    final deltaScreen = viewportCenter - currentScreen;
    final worldDelta = widget.controller.camera.deltaScreenToWorld(deltaScreen);
    widget.controller.camera.translateWorld(worldDelta);
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointer = event.pointer;
    _panWasEnabled = widget.controller.camera.panEnabled;
    if (_panWasEnabled) {
      widget.controller.camera.disablePan();
    }
    _centerCameraAt(event.localPosition);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) return;
    _centerCameraAt(event.localPosition);
  }

  void _onPointerEnd(int pointer) {
    if (_activePointer != pointer) return;
    _activePointer = null;
    if (_panWasEnabled) {
      widget.controller.camera.enablePan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: tdMegaMiniMapMargin,
        child: SizedBox(
          width: tdMegaMiniMapSize.width,
          height: tdMegaMiniMapSize.height,
          child: RepaintBoundary(
            child: MouseRegion(
              cursor: _activePointer == null
                  ? SystemMouseCursors.grab
                  : SystemMouseCursors.grabbing,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: (event) => _onPointerEnd(event.pointer),
                onPointerCancel: (event) => _onPointerEnd(event.pointer),
                child: CustomPaint(
                  painter: _TdMegaMiniMapPainter(
                    engine: widget.engine,
                    controller: widget.controller,
                    repaintListenable: widget.repaint,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TdMegaMiniMapPainter extends CustomPainter {
  final TdMegaMapEngine engine;
  final CanvasLayerController controller;
  final Listenable repaintListenable;

  _TdMegaMiniMapPainter({
    required this.engine,
    required this.controller,
    required this.repaintListenable,
  }) : super(repaint: repaintListenable);

  static const double _panelRadius = 10;
  static const double _panelPadding = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final panelRect = Offset.zero & size;
    final panelRRect = RRect.fromRectAndRadius(
      panelRect.deflate(0.5),
      const Radius.circular(_panelRadius),
    );
    canvas.drawRRect(panelRRect, Paint()..color = const Color(0xBC0A1020));
    canvas.drawRRect(
      panelRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0x66B6E0FF),
    );

    final projection = _TdMegaMiniProjection.fromEngine(
      size: size,
      engine: engine,
      controller: controller,
    );
    if (projection == null) return;

    _drawLanes(canvas, projection);
    _drawPads(canvas, projection);
    _drawTowers(canvas, projection);
    _drawCreeps(canvas, projection);
    _drawViewport(canvas, projection);
    _drawBadge(canvas);
  }

  void _drawLanes(Canvas canvas, _TdMegaMiniProjection projection) {
    for (var i = 0; i < engine.lanes.length; i++) {
      final lane = engine.lanes[i];
      if (lane.points.length < 2) continue;
      final first = projection.worldToMini(lane.points.first);
      final path = Path()..moveTo(first.dx, first.dy);
      for (var pIndex = 1; pIndex < lane.points.length; pIndex++) {
        final p = projection.worldToMini(lane.points[pIndex]);
        path.lineTo(p.dx, p.dy);
      }
      final hue = (i * (340.0 / math.max(1, engine.lanes.length))) % 360;
      final color = HSLColor.fromAHSL(1.0, hue, 0.74, 0.57).toColor();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: 0.42),
      );
    }
  }

  void _drawPads(Canvas canvas, _TdMegaMiniProjection projection) {
    for (final p in engine.towerPads) {
      canvas.drawCircle(
        projection.worldToMini(p),
        1.8,
        Paint()..color = const Color(0xFF4A6789),
      );
    }
  }

  void _drawTowers(Canvas canvas, _TdMegaMiniProjection projection) {
    for (final q in engine.world.query2<MegaPositionC, MegaTowerC>()) {
      final p = projection.worldToMini(q.component1.offset);
      canvas.drawCircle(p, 2.0, Paint()..color = const Color(0xFF38BDF8));
    }
  }

  void _drawCreeps(Canvas canvas, _TdMegaMiniProjection projection) {
    const creepDotRadius = 0.16;
    for (final q in engine.world.query2<MegaPositionC, MegaCreepC>()) {
      final p = projection.worldToMini(q.component1.offset);
      canvas.drawCircle(
        p,
        creepDotRadius,
        Paint()..color = const Color(0xFFFF5C8A),
      );
    }
  }

  void _drawViewport(Canvas canvas, _TdMegaMiniProjection projection) {
    final viewportSize =
        controller.camera.renderStats?.viewportSize ?? Size.zero;
    if (viewportSize.isEmpty) return;

    final visibleWorld = controller.camera.getVisibleWorldRect(viewportSize);
    final miniViewport = projection
        .worldRectToMini(visibleWorld)
        .intersect(projection.contentRect);
    if (miniViewport.isEmpty) return;

    canvas.drawRect(miniViewport, Paint()..color = const Color(0x5500C2FF));
    canvas.drawRect(
      miniViewport,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..color = const Color(0xFF8CE8FF),
    );
  }

  void _drawBadge(Canvas canvas) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );
    final text = TextPainter(
      text: const TextSpan(text: 'MEGA CAM', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final badgeRect = Rect.fromLTWH(8, 8, text.width + 12, text.height + 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(6)),
      Paint()..color = const Color(0x5544B0E2),
    );
    text.paint(canvas, Offset(badgeRect.left + 6, badgeRect.top + 3));
  }

  @override
  bool shouldRepaint(covariant _TdMegaMiniMapPainter oldDelegate) {
    return oldDelegate.engine != engine ||
        oldDelegate.controller != controller ||
        oldDelegate.repaintListenable != repaintListenable;
  }
}

class _TdMegaMiniProjection {
  final Rect contentRect;
  final Rect worldRect;
  final double scale;
  final Offset miniOrigin;

  const _TdMegaMiniProjection({
    required this.contentRect,
    required this.worldRect,
    required this.scale,
    required this.miniOrigin,
  });

  static _TdMegaMiniProjection? fromEngine({
    required Size size,
    required TdMegaMapEngine engine,
    required CanvasLayerController controller,
  }) {
    final contentRect = _contentRectFor(size);
    if (contentRect.isEmpty) return null;

    var left = engine.boardBounds.left - 180;
    var top = engine.boardBounds.top - 180;
    var right = engine.boardBounds.right + 180;
    var bottom = engine.boardBounds.bottom + 180;

    final viewportSize =
        controller.camera.renderStats?.viewportSize ?? Size.zero;
    if (!viewportSize.isEmpty) {
      final visible = controller.camera.getVisibleWorldRect(viewportSize);
      left = math.min(left, visible.left);
      top = math.min(top, visible.top);
      right = math.max(right, visible.right);
      bottom = math.max(bottom, visible.bottom);
    }

    var worldWidth = right - left;
    var worldHeight = bottom - top;
    if (worldWidth.abs() < 1e-6) worldWidth = 1;
    if (worldHeight.abs() < 1e-6) worldHeight = 1;

    final scale = math.min(
      contentRect.width / worldWidth,
      contentRect.height / worldHeight,
    );
    final projectedWidth = worldWidth * scale;
    final projectedHeight = worldHeight * scale;
    final miniOrigin = Offset(
      contentRect.left + ((contentRect.width - projectedWidth) * 0.5),
      contentRect.top + ((contentRect.height - projectedHeight) * 0.5),
    );

    return _TdMegaMiniProjection(
      contentRect: contentRect,
      worldRect: Rect.fromLTRB(left, top, right, bottom),
      scale: scale,
      miniOrigin: miniOrigin,
    );
  }

  Offset worldToMini(Offset world) {
    return Offset(
      miniOrigin.dx + ((world.dx - worldRect.left) * scale),
      miniOrigin.dy + ((world.dy - worldRect.top) * scale),
    );
  }

  Offset miniToWorld(Offset mini, {required bool clampToContent}) {
    final sampled = clampToContent
        ? Offset(
            mini.dx.clamp(contentRect.left, contentRect.right).toDouble(),
            mini.dy.clamp(contentRect.top, contentRect.bottom).toDouble(),
          )
        : mini;
    return Offset(
      worldRect.left + ((sampled.dx - miniOrigin.dx) / scale),
      worldRect.top + ((sampled.dy - miniOrigin.dy) / scale),
    );
  }

  Rect worldRectToMini(Rect world) {
    final tl = worldToMini(world.topLeft);
    final br = worldToMini(world.bottomRight);
    return Rect.fromLTRB(tl.dx, tl.dy, br.dx, br.dy);
  }
}

Rect _contentRectFor(Size size) {
  return Rect.fromLTWH(
    _TdMegaMiniMapPainter._panelPadding,
    _TdMegaMiniMapPainter._panelPadding,
    size.width - (_TdMegaMiniMapPainter._panelPadding * 2),
    size.height - (_TdMegaMiniMapPainter._panelPadding * 2),
  );
}
