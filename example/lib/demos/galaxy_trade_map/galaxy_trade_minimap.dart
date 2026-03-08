import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

import 'galaxy_trade_models.dart';

const Size _galaxyMiniMapSize = Size(244, 170);
const EdgeInsets _galaxyMiniMapMargin = EdgeInsets.all(14);
const double _galaxyMiniMapPanelRadius = 12;
const double _galaxyMiniMapPanelPadding = 10;

class GalaxyTradeMiniMapOverlay extends StatefulWidget {
  final GalaxyTradeScene scene;
  final CanvasLayerController controller;
  final ValueListenable<String?> selectedSystemId;
  final ValueListenable<String?> hoveredSystemId;

  const GalaxyTradeMiniMapOverlay({
    super.key,
    required this.scene,
    required this.controller,
    required this.selectedSystemId,
    required this.hoveredSystemId,
  });

  @override
  State<GalaxyTradeMiniMapOverlay> createState() =>
      _GalaxyTradeMiniMapOverlayState();
}

class _GalaxyTradeMiniMapOverlayState extends State<GalaxyTradeMiniMapOverlay> {
  int? _activePointer;
  bool _panWasEnabled = true;

  void _moveCameraToMiniPoint(Offset localPoint) {
    final projection = _GalaxyMiniMapProjection.fromScene(
      size: _galaxyMiniMapSize,
      scene: widget.scene,
    );
    if (projection == null) return;
    final targetWorld = projection.miniToWorld(
      localPoint,
      clampToContent: true,
    );
    widget.controller.camera.jumpToWorldCenter(targetWorld);
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointer = event.pointer;
    _panWasEnabled = widget.controller.camera.panEnabled;
    if (_panWasEnabled) {
      widget.controller.camera.disablePan();
    }
    _moveCameraToMiniPoint(event.localPosition);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) return;
    _moveCameraToMiniPoint(event.localPosition);
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
    final controllerRepaint = widget.controller is Listenable
        ? widget.controller as Listenable
        : widget.controller.renderStatsListenable;
    final repaint = Listenable.merge([
      controllerRepaint,
      widget.selectedSystemId,
      widget.hoveredSystemId,
    ]);

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: _galaxyMiniMapMargin,
        child: SizedBox(
          width: _galaxyMiniMapSize.width,
          height: _galaxyMiniMapSize.height,
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
                  painter: _GalaxyTradeMiniMapPainter(
                    scene: widget.scene,
                    controller: widget.controller,
                    selectedSystemId: widget.selectedSystemId,
                    hoveredSystemId: widget.hoveredSystemId,
                    repaintListenable: repaint,
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

class _GalaxyTradeMiniMapPainter extends CustomPainter {
  final GalaxyTradeScene scene;
  final CanvasLayerController controller;
  final ValueListenable<String?> selectedSystemId;
  final ValueListenable<String?> hoveredSystemId;
  final Listenable repaintListenable;

  _GalaxyTradeMiniMapPainter({
    required this.scene,
    required this.controller,
    required this.selectedSystemId,
    required this.hoveredSystemId,
    required this.repaintListenable,
  }) : super(repaint: repaintListenable);

  static const Color _panelBg = Color(0xD3060C18);
  static const Color _panelBorder = Color(0xFF294B79);
  static const Color _viewportFill = Color(0x4428C9FF);
  static const Color _viewportStroke = Color(0xFF98EDFF);

  @override
  void paint(Canvas canvas, Size size) {
    final panelRect = Offset.zero & size;
    final panelRRect = RRect.fromRectAndRadius(
      panelRect.deflate(0.5),
      const Radius.circular(_galaxyMiniMapPanelRadius),
    );

    canvas.drawRRect(panelRRect, Paint()..color = _panelBg);
    canvas.drawRRect(
      panelRRect,
      Paint()
        ..color = _panelBorder.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15,
    );

    final projection = _GalaxyMiniMapProjection.fromScene(
      size: size,
      scene: scene,
    );
    if (projection == null) {
      _drawBadge(canvas, 'MAP');
      return;
    }

    _drawGalaxyGlow(canvas, projection);
    _drawRoutes(canvas, projection);
    _drawSystems(canvas, projection);
    _drawViewport(canvas, projection);
    _drawBadge(canvas, 'GAL');
  }

  void _drawGalaxyGlow(Canvas canvas, _GalaxyMiniMapProjection projection) {
    final content = projection.contentRect;
    final center = projection.worldToMini(scene.bounds.center);
    final haloRect = Rect.fromCenter(
      center: center,
      width: content.width * 0.82,
      height: content.height * 0.54,
    );
    canvas.drawOval(
      haloRect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            const Color(0xFF355FBA).withValues(alpha: 0.22),
            const Color(0xFF1C355F).withValues(alpha: 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(haloRect),
    );

    canvas.drawRect(
      content,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _drawRoutes(Canvas canvas, _GalaxyMiniMapProjection projection) {
    final selectedId = selectedSystemId.value;
    final hoveredId = hoveredSystemId.value;

    for (final route in scene.routes) {
      final from = scene.systems[route.fromIndex];
      final to = scene.systems[route.toIndex];
      final isActive =
          from.id == selectedId ||
          to.id == selectedId ||
          from.id == hoveredId ||
          to.id == hoveredId;
      final t = (route.capacity / 1.6).clamp(0.0, 1.0);
      final stroke = isActive ? 1.35 : (0.55 + t * 0.55);
      final alpha = isActive ? (0.30 + t * 0.30) : (0.08 + t * 0.11);
      canvas.drawLine(
        projection.worldToMini(from.center),
        projection.worldToMini(to.center),
        Paint()
          ..color = route.color.withValues(alpha: alpha.clamp(0.05, 0.65))
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawSystems(Canvas canvas, _GalaxyMiniMapProjection projection) {
    final selectedId = selectedSystemId.value;
    final hoveredId = hoveredSystemId.value;

    for (final system in scene.systems) {
      final mini = projection.worldToMini(system.center);
      final radius = 1.2 + (system.influence.clamp(0.0, 1.0) * 1.4);
      final active = system.id == selectedId || system.id == hoveredId;
      final fill = Paint()
        ..color = Color.lerp(
          system.factionColor,
          Colors.white,
          0.16,
        )!.withValues(alpha: active ? 0.96 : 0.84);
      canvas.drawCircle(mini, radius, fill);
      canvas.drawCircle(
        mini,
        math.max(0.7, radius * 0.28),
        Paint()..color = Colors.white.withValues(alpha: active ? 0.92 : 0.72),
      );

      if (system.id == selectedId) {
        canvas.drawCircle(
          mini,
          radius + 2.7,
          Paint()
            ..color = const Color(0xFFFFE7A8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      } else if (system.id == hoveredId) {
        canvas.drawCircle(
          mini,
          radius + 1.9,
          Paint()
            ..color = const Color(0xFFAEEBFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }
  }

  void _drawViewport(Canvas canvas, _GalaxyMiniMapProjection projection) {
    final viewportSize =
        controller.camera.renderStats?.viewportSize ?? Size.zero;
    if (viewportSize.isEmpty) return;

    final worldVisible = controller.camera.getVisibleWorldRect(viewportSize);
    final miniViewport = projection
        .worldRectToMini(worldVisible)
        .intersect(projection.contentRect);
    if (miniViewport.isEmpty) return;

    canvas.drawRect(miniViewport, Paint()..color = _viewportFill);
    canvas.drawRect(
      miniViewport,
      Paint()
        ..color = _viewportStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawBadge(Canvas canvas, String text) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.45,
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromLTWH(8, 8, painter.width + 12, painter.height + 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = const Color(0xFF3D6EC8).withValues(alpha: 0.32),
    );
    painter.paint(canvas, Offset(rect.left + 6, rect.top + 3));
  }

  @override
  bool shouldRepaint(covariant _GalaxyTradeMiniMapPainter oldDelegate) {
    return oldDelegate.scene != scene ||
        oldDelegate.controller != controller ||
        oldDelegate.selectedSystemId != selectedSystemId ||
        oldDelegate.hoveredSystemId != hoveredSystemId ||
        oldDelegate.repaintListenable != repaintListenable;
  }
}

class _GalaxyMiniMapProjection {
  final Rect contentRect;
  final Rect worldRect;
  final double scale;
  final Offset miniOrigin;

  const _GalaxyMiniMapProjection({
    required this.contentRect,
    required this.worldRect,
    required this.scale,
    required this.miniOrigin,
  });

  static _GalaxyMiniMapProjection? fromScene({
    required Size size,
    required GalaxyTradeScene scene,
  }) {
    final contentRect = Rect.fromLTWH(
      _galaxyMiniMapPanelPadding,
      _galaxyMiniMapPanelPadding,
      size.width - (_galaxyMiniMapPanelPadding * 2),
      size.height - (_galaxyMiniMapPanelPadding * 2),
    );
    if (contentRect.isEmpty) return null;

    final padding = math.max(
      640.0,
      math.min(scene.bounds.width, scene.bounds.height) * 0.08,
    );
    final worldRect = scene.bounds.inflate(padding);
    final worldWidth = math.max(1.0, worldRect.width);
    final worldHeight = math.max(1.0, worldRect.height);
    final scale = math.min(
      contentRect.width / worldWidth,
      contentRect.height / worldHeight,
    );
    final projectedWidth = worldWidth * scale;
    final projectedHeight = worldHeight * scale;
    final miniOrigin = Offset(
      contentRect.left + (contentRect.width - projectedWidth) * 0.5,
      contentRect.top + (contentRect.height - projectedHeight) * 0.5,
    );

    return _GalaxyMiniMapProjection(
      contentRect: contentRect,
      worldRect: worldRect,
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
