import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

import 'components.dart';
import 'engine.dart';

const Size tdMiniMapSize = Size(236, 162);
const EdgeInsets tdMiniMapMargin = EdgeInsets.all(14);

class TdMiniMapOverlay extends StatefulWidget {
  final TdGameEngine engine;
  final CanvasLayerController controller;
  final Listenable repaint;

  const TdMiniMapOverlay({
    super.key,
    required this.engine,
    required this.controller,
    required this.repaint,
  });

  @override
  State<TdMiniMapOverlay> createState() => _TdMiniMapOverlayState();
}

class _TdMiniMapOverlayState extends State<TdMiniMapOverlay> {
  int? _activePointer;
  bool _panWasEnabled = true;

  void _centerCameraAt(Offset localPoint) {
    final projection = _TdMiniProjection.fromEngine(
      size: tdMiniMapSize,
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
        padding: tdMiniMapMargin,
        child: SizedBox(
          width: tdMiniMapSize.width,
          height: tdMiniMapSize.height,
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
                  painter: _TdMiniMapPainter(
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

class _TdMiniMapPainter extends CustomPainter {
  final TdGameEngine engine;
  final CanvasLayerController controller;
  final Listenable repaintListenable;
  static const bool _traceMiniMap = false;
  static DateTime? _traceWindowStart;
  static int _tracePaints = 0;

  _TdMiniMapPainter({
    required this.engine,
    required this.controller,
    required this.repaintListenable,
  }) : super(repaint: repaintListenable);

  static const double _panelRadius = 10;
  static const double _panelPadding = 10;
  static const Color _accent = Color(0xFF83F3B8);

  @override
  void paint(Canvas canvas, Size size) {
    _tracePaints++;
    final panelRect = Offset.zero & size;
    final panelRRect = RRect.fromRectAndRadius(
      panelRect.deflate(0.5),
      const Radius.circular(_panelRadius),
    );

    canvas.drawRRect(panelRRect, Paint()..color = const Color(0xB3111826));
    canvas.drawRRect(
      panelRRect,
      Paint()
        ..color = _accent.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    _drawModeBadge(canvas);

    final projection = _TdMiniProjection.fromEngine(
      size: size,
      engine: engine,
      controller: controller,
    );
    if (projection == null) {
      _drawEmptyHint(canvas, _contentRectFor(size));
      return;
    }

    _drawPath(canvas, projection);
    _drawPads(canvas, projection);
    _drawEntities(canvas, projection);
    _drawViewport(canvas, projection);
  }

  void _drawPath(Canvas canvas, _TdMiniProjection projection) {
    final points = engine.pathPoints;
    if (points.length < 2) return;
    final first = projection.worldToMini(points.first);
    final p = Path()..moveTo(first.dx, first.dy);
    for (var i = 1; i < points.length; i++) {
      final pt = projection.worldToMini(points[i]);
      p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = const Color(0x66FF4DD2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      p,
      Paint()
        ..color = const Color(0x88AEEBFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawPads(Canvas canvas, _TdMiniProjection projection) {
    for (final q in engine.world.query2<PositionC, TowerPadC>()) {
      final center = projection.worldToMini(q.component1.offset);
      canvas.drawCircle(
        center,
        2.1,
        Paint()
          ..color = q.component2.occupied
              ? const Color(0xFF94A3B8)
              : const Color(0xFF4B5563),
      );
    }
  }

  void _drawEntities(Canvas canvas, _TdMiniProjection projection) {
    final creeps = engine.world.query2<PositionC, CreepC>().toList(
      growable: false,
    );
    final towers = engine.world.query2<PositionC, TowerC>().toList(
      growable: false,
    );
    final projectiles = engine.world.query2<PositionC, ProjectileC>().toList(
      growable: false,
    );

    var projectilesInContent = 0;

    for (final q in creeps) {
      canvas.drawCircle(
        projection.worldToMini(q.component1.offset),
        1.8,
        Paint()..color = const Color(0xFFF43F5E),
      );
    }

    for (final q in towers) {
      canvas.drawCircle(
        projection.worldToMini(q.component1.offset),
        2.0,
        Paint()..color = const Color(0xFF4EA8DE),
      );
    }

    for (final q in projectiles) {
      final mini = projection.worldToMini(q.component1.offset);
      if (projection.contentRect.contains(mini)) {
        projectilesInContent++;
      }
      canvas.drawCircle(mini, 1.45, Paint()..color = const Color(0xFFFFF7D6));
      canvas.drawCircle(mini, 2.3, Paint()..color = const Color(0x55F59E0B));
    }

    _trace(
      projection: projection,
      creeps: creeps.length,
      towers: towers.length,
      projectiles: projectiles.length,
      projectilesInContent: projectilesInContent,
    );
  }

  void _drawViewport(Canvas canvas, _TdMiniProjection projection) {
    final viewportSize =
        controller.camera.renderStats?.viewportSize ?? Size.zero;
    if (viewportSize.isEmpty) return;
    final worldVisible = controller.camera.getVisibleWorldRect(viewportSize);
    final miniViewport = projection
        .worldRectToMini(worldVisible)
        .intersect(projection.contentRect);
    if (miniViewport.isEmpty) return;

    canvas.drawRect(miniViewport, Paint()..color = const Color(0x6600C2FF));
    canvas.drawRect(
      miniViewport,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..color = const Color(0xFF8CE8FF),
    );
  }

  void _drawModeBadge(Canvas canvas) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );
    final painter = TextPainter(
      text: const TextSpan(text: 'CAM', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final badgeRect = Rect.fromLTWH(
      8,
      8,
      painter.width + 12,
      painter.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(6)),
      Paint()..color = _accent.withValues(alpha: 0.28),
    );
    painter.paint(canvas, Offset(badgeRect.left + 6, badgeRect.top + 3));
  }

  void _drawEmptyHint(Canvas canvas, Rect contentRect) {
    canvas.drawRect(
      contentRect,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _trace({
    required _TdMiniProjection projection,
    required int creeps,
    required int towers,
    required int projectiles,
    required int projectilesInContent,
  }) {
    if (!_traceMiniMap) return;
    final now = DateTime.now();
    final windowStart = _traceWindowStart ?? now;
    final elapsedMs = now.difference(windowStart).inMilliseconds;
    if (elapsedMs < 1000) return;

    final viewportSize =
        controller.camera.renderStats?.viewportSize ?? Size.zero;
    Rect? visibleWorld;
    if (!viewportSize.isEmpty) {
      visibleWorld = controller.camera.getVisibleWorldRect(viewportSize);
    }

    // ignore: avoid_print
    print(
      'td mini dbg '
      'paints=$_tracePaints '
      'creeps=$creeps towers=$towers projectiles=$projectiles '
      'projInMini=$projectilesInContent '
      'scale=${projection.scale.toStringAsFixed(4)} '
      'world=(${projection.worldRect.left.toStringAsFixed(1)},'
      '${projection.worldRect.top.toStringAsFixed(1)})-'
      '(${projection.worldRect.right.toStringAsFixed(1)},'
      '${projection.worldRect.bottom.toStringAsFixed(1)}) '
      'visible=${visibleWorld == null ? 'none' : '${visibleWorld.left.toStringAsFixed(1)},${visibleWorld.top.toStringAsFixed(1)} -> ${visibleWorld.right.toStringAsFixed(1)},${visibleWorld.bottom.toStringAsFixed(1)}'}',
    );

    _traceWindowStart = now;
    _tracePaints = 0;
  }

  @override
  bool shouldRepaint(covariant _TdMiniMapPainter oldDelegate) {
    return oldDelegate.engine != engine ||
        oldDelegate.controller != controller ||
        oldDelegate.repaintListenable != repaintListenable;
  }
}

class _TdMiniProjection {
  final Rect contentRect;
  final Rect worldRect;
  final double scale;
  final Offset miniOrigin;

  const _TdMiniProjection({
    required this.contentRect,
    required this.worldRect,
    required this.scale,
    required this.miniOrigin,
  });

  static _TdMiniProjection? fromEngine({
    required Size size,
    required TdGameEngine engine,
    required CanvasLayerController controller,
  }) {
    final contentRect = _contentRectFor(size);
    if (contentRect.isEmpty) return null;

    var left = engine.boardBounds.left - 120;
    var top = engine.boardBounds.top - 120;
    var right = engine.boardBounds.right + 120;
    var bottom = engine.boardBounds.bottom + 120;

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

    return _TdMiniProjection(
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
    _TdMiniMapPainter._panelPadding,
    _TdMiniMapPainter._panelPadding,
    size.width - (_TdMiniMapPainter._panelPadding * 2),
    size.height - (_TdMiniMapPainter._panelPadding * 2),
  );
}
