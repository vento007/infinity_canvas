import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

import '../node_model.dart';
import '../node_scene.dart';

const Size _miniMapSize = Size(236, 162);
const double _miniMapPanelRadius = 10;
const double _miniMapPanelPadding = 10;
const double _miniMapWorldPadding = 220;
const double _miniMapMinNodeSize = 1.4;

enum MiniMapBoundsMode { contentAnchored, cameraAware }

CanvasTransformWidgetBuilder buildMiniMapLayerBuilder(
  NodeCanvasDemoState demoState, {
  MiniMapBoundsMode boundsMode = MiniMapBoundsMode.contentAnchored,
}) {
  return (context, _, controller) {
    final nodeRepaint = demoState.linksRepaintListenable();
    final Listenable cameraRepaint = controller is Listenable
        ? controller as Listenable
        : controller.camera.renderStatsListenable;
    final repaint = Listenable.merge([cameraRepaint, nodeRepaint]);

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: _miniMapSize.width,
          height: _miniMapSize.height,
          child: RepaintBoundary(
            child: _MiniMapInteractive(
              nodes: demoState.nodes,
              worldPositionOf: demoState.worldPositionFor,
              controller: controller,
              repaint: repaint,
              boundsMode: boundsMode,
            ),
          ),
        ),
      ),
    );
  };
}

class NodeMiniMapPainter extends CustomPainter {
  final List<DemoNode> nodes;
  final Offset Function(DemoNode node) worldPositionOf;
  final CanvasLayerController controller;
  final Listenable repaintListenable;
  final MiniMapBoundsMode boundsMode;

  NodeMiniMapPainter({
    required this.nodes,
    required this.worldPositionOf,
    required this.controller,
    required this.repaintListenable,
    required this.boundsMode,
  }) : super(repaint: repaintListenable);

  @override
  void paint(Canvas canvas, Size size) {
    final panelRect = Offset.zero & size;
    final accent = boundsMode == MiniMapBoundsMode.cameraAware
        ? const Color(0xFF83F3B8)
        : const Color(0xFF4AC3FF);
    final panelRRect = RRect.fromRectAndRadius(
      panelRect.deflate(0.5),
      const Radius.circular(_miniMapPanelRadius),
    );

    canvas.drawRRect(panelRRect, Paint()..color = const Color(0xB3111826));
    canvas.drawRRect(
      panelRRect,
      Paint()
        ..color = accent.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    _drawModeBadge(canvas, accent);

    final projection = _MiniMapProjection.fromNodes(
      size: size,
      nodes: nodes,
      worldPositionOf: worldPositionOf,
      controller: controller,
      boundsMode: boundsMode,
    );
    if (projection == null) {
      _drawEmptyHint(canvas, _contentRectFor(size));
      return;
    }

    final nodePaint = Paint()
      ..color = const Color(0xFFAEEBFF).withValues(alpha: 0.78)
      ..style = PaintingStyle.fill;

    for (final node in nodes) {
      final pos = worldPositionOf(node);
      final nodeSize = node.size.value;
      final mapped = projection.worldRectToMini(
        Rect.fromLTWH(pos.dx, pos.dy, nodeSize.width, nodeSize.height),
      );
      final drawRect = Rect.fromCenter(
        center: mapped.center,
        width: math.max(_miniMapMinNodeSize, mapped.width),
        height: math.max(_miniMapMinNodeSize, mapped.height),
      );
      canvas.drawRect(drawRect, nodePaint);
    }

    final viewportSize =
        controller.camera.renderStats?.viewportSize ?? Size.zero;
    if (!viewportSize.isEmpty) {
      final worldVisible = controller.camera.getVisibleWorldRect(viewportSize);
      final miniViewport = projection
          .worldRectToMini(worldVisible)
          .intersect(projection.contentRect);
      if (!miniViewport.isEmpty) {
        canvas.drawRect(miniViewport, Paint()..color = const Color(0x6600C2FF));
        canvas.drawRect(
          miniViewport,
          Paint()
            ..color = const Color(0xFF8CE8FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.25,
        );
      }
    }
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

  void _drawModeBadge(Canvas canvas, Color accent) {
    final text = boundsMode == MiniMapBoundsMode.cameraAware ? 'CAM' : 'CNT';
    const style = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
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
      Paint()..color = accent.withValues(alpha: 0.28),
    );
    painter.paint(canvas, Offset(badgeRect.left + 6, badgeRect.top + 3));
  }

  @override
  bool shouldRepaint(covariant NodeMiniMapPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.worldPositionOf != worldPositionOf ||
        oldDelegate.controller != controller ||
        oldDelegate.repaintListenable != repaintListenable ||
        oldDelegate.boundsMode != boundsMode;
  }
}

class _MiniMapInteractive extends StatefulWidget {
  final List<DemoNode> nodes;
  final Offset Function(DemoNode node) worldPositionOf;
  final CanvasLayerController controller;
  final Listenable repaint;
  final MiniMapBoundsMode boundsMode;

  const _MiniMapInteractive({
    required this.nodes,
    required this.worldPositionOf,
    required this.controller,
    required this.repaint,
    required this.boundsMode,
  });

  @override
  State<_MiniMapInteractive> createState() => _MiniMapInteractiveState();
}

class _MiniMapInteractiveState extends State<_MiniMapInteractive> {
  int? _activePointer;
  bool _panWasEnabled = true;

  void _moveCameraToMiniPoint(Offset localPoint) {
    final projection = _MiniMapProjection.fromNodes(
      size: _miniMapSize,
      nodes: widget.nodes,
      worldPositionOf: widget.worldPositionOf,
      controller: widget.controller,
      boundsMode: widget.boundsMode,
    );
    if (projection == null) return;
    final stats = widget.controller.camera.renderStats;
    final viewportSize = stats?.viewportSize ?? Size.zero;
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
    return MouseRegion(
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
          painter: NodeMiniMapPainter(
            nodes: widget.nodes,
            worldPositionOf: widget.worldPositionOf,
            controller: widget.controller,
            repaintListenable: widget.repaint,
            boundsMode: widget.boundsMode,
          ),
        ),
      ),
    );
  }
}

class _MiniMapProjection {
  final Rect contentRect;
  final Rect worldRect;
  final double scale;
  final Offset miniOrigin;

  const _MiniMapProjection({
    required this.contentRect,
    required this.worldRect,
    required this.scale,
    required this.miniOrigin,
  });

  static _MiniMapProjection? fromNodes({
    required Size size,
    required List<DemoNode> nodes,
    required Offset Function(DemoNode node) worldPositionOf,
    required CanvasLayerController controller,
    required MiniMapBoundsMode boundsMode,
  }) {
    final contentRect = _contentRectFor(size);
    if (contentRect.isEmpty || nodes.isEmpty) return null;

    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;

    for (final node in nodes) {
      final pos = worldPositionOf(node);
      final nodeSize = node.size.value;
      left = math.min(left, pos.dx);
      top = math.min(top, pos.dy);
      right = math.max(right, pos.dx + nodeSize.width);
      bottom = math.max(bottom, pos.dy + nodeSize.height);
    }

    if (!left.isFinite ||
        !top.isFinite ||
        !right.isFinite ||
        !bottom.isFinite) {
      return null;
    }

    left -= _miniMapWorldPadding;
    top -= _miniMapWorldPadding;
    right += _miniMapWorldPadding;
    bottom += _miniMapWorldPadding;

    if (boundsMode == MiniMapBoundsMode.cameraAware) {
      final viewportSize =
          controller.camera.renderStats?.viewportSize ?? Size.zero;
      if (!viewportSize.isEmpty) {
        final visibleWorld = controller.camera.getVisibleWorldRect(
          viewportSize,
        );
        left = math.min(left, visibleWorld.left);
        top = math.min(top, visibleWorld.top);
        right = math.max(right, visibleWorld.right);
        bottom = math.max(bottom, visibleWorld.bottom);
      }
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

    return _MiniMapProjection(
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
    _miniMapPanelPadding,
    _miniMapPanelPadding,
    size.width - (_miniMapPanelPadding * 2),
    size.height - (_miniMapPanelPadding * 2),
  );
}
