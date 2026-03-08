import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

import 'node_model.dart';
import 'widgets/node_card.dart';

class NodeCanvasDemoState extends ChangeNotifier {
  NodeCanvasDemoState({required this.canvasController}) {
    canvasController.camera.renderStatsListenable.addListener(
      _onRenderStatsChanged,
    );
    _seedInitialNodes();
  }

  static const int initialNodeCount = 320;
  static const int gridColumns = 30;
  static const double gridSpacingX = 235.0;
  static const double gridSpacingY = 185.0;
  static const double worldOriginX = -3600.0;
  static const double worldOriginY = -2800.0;

  final CanvasController canvasController;

  final List<DemoNode> nodes = <DemoNode>[];
  final List<CanvasItem> nodeItems = <CanvasItem>[];
  bool nodesDraggable = true;
  int nodeCount = 0;
  double zoom = 1.0;
  String lastEvent = '-';

  int _nextNodeIndex = 0;

  final Map<String, Offset> _resizeStartGlobalByNode = <String, Offset>{};
  final Map<String, Size> _resizeStartSizeByNode = <String, Size>{};
  static const bool _enableN0BuildProbe = false;
  static const bool _traceCullingStats = false;
  int _n0BuildCount = 0;
  bool _disposed = false;
  int _lastVisibleItems = -1;
  int _lastTotalItems = -1;

  Listenable linksRepaintListenable() {
    return Listenable.merge([
      ...nodes.map((n) => n.position),
      ...nodes.map((n) => n.size),
    ]);
  }

  Offset worldPositionFor(DemoNode node) => node.position.value;

  void _seedInitialNodes() {
    final initial = List<DemoNode>.generate(initialNodeCount, _createNode);
    nodes.addAll(initial);
    _nextNodeIndex = nodes.length;
    nodeCount = nodes.length;
    _rebuildNodeItems();
  }

  void updateZoom(double value) {
    if ((value - zoom).abs() < 1e-6) return;
    zoom = value;
  }

  void spawnOne() => _spawn(1);
  void spawnHundred() => _spawn(100);
  void spawnThousand() => _spawn(1000, spreadMultiplier: 1.8);
  void spawnTiltedOne() => _spawn(1, tilted: true);

  void fitAllNodes({
    double paddingFraction = 0.08,
    double worldPadding = 120.0,
  }) {
    canvasController.camera.fitAllItems(
      paddingFraction: paddingFraction,
      worldPadding: worldPadding,
    );
    lastEvent = 'fit nodes';
    notifyListeners();
  }

  void jumpToN0({double? zoom}) {
    final node = _targetNodeForCamera();
    if (node == null) return;
    canvasController.camera.jumpToWorldTopLeft(node.position.value, zoom: zoom);
    lastEvent = 'jump ${node.id}';
    notifyListeners();
  }

  void animateToN0({
    double? zoom,
    Duration duration = const Duration(milliseconds: 380),
  }) {
    final node = _targetNodeForCamera();
    if (node == null) return;
    unawaited(
      canvasController.camera.animateToWorldTopLeft(
        node.position.value,
        zoom: zoom,
        duration: duration,
      ),
    );
    lastEvent = 'animate ${node.id}';
    notifyListeners();
  }

  void animateToN0Center({
    double? zoom,
    Duration duration = const Duration(milliseconds: 380),
  }) {
    final node = _targetNodeForCamera();
    if (node == null) return;
    unawaited(
      canvasController.camera.animateToWorldCenter(
        node.position.value,
        zoom: zoom,
        duration: duration,
      ),
    );
    lastEvent = 'animate center ${node.id}';
    notifyListeners();
  }

  void setNodesDraggable(bool enabled) {
    if (nodesDraggable == enabled) return;
    nodesDraggable = enabled;
    for (final n in nodes) {
      if (n.resizing.value) continue;
      canvasController.items.setDragEnabled(n.id, enabled);
    }
    notifyListeners();
  }

  void onActionTap(String id) {
    lastEvent = 'button $id';
    notifyListeners();
  }

  void onResizeStart(DemoNode node, Offset globalPosition) {
    if (node.resizing.value) return;
    node.resizing.value = true;
    node.dragging.value = false;
    canvasController.items.setDragEnabled(node.id, false);
    canvasController.camera.disablePan();
    _resizeStartGlobalByNode[node.id] = globalPosition;
    _resizeStartSizeByNode[node.id] = node.size.value;
    lastEvent = 'resize start ${node.id}';
  }

  void onResizeUpdate(DemoNode node, Offset globalPosition) {
    if (!node.resizing.value) return;
    final startGlobal = _resizeStartGlobalByNode[node.id];
    final startSize = _resizeStartSizeByNode[node.id];
    if (startGlobal == null || startSize == null) return;
    final safeZoom = canvasController.camera.scale.clamp(1e-6, double.infinity);
    final screenDelta = globalPosition - startGlobal;
    final worldDelta = Offset(
      screenDelta.dx / safeZoom,
      screenDelta.dy / safeZoom,
    );
    final next = Size(
      (startSize.width + worldDelta.dx).clamp(120.0, 420.0).toDouble(),
      (startSize.height + worldDelta.dy).clamp(96.0, 320.0).toDouble(),
    );
    if (next == node.size.value) return;
    node.size.value = next;
  }

  void onResizeEnd(DemoNode node, {required bool canceled}) {
    if (!node.resizing.value) return;
    node.resizing.value = false;
    canvasController.items.setDragEnabled(node.id, nodesDraggable);
    canvasController.camera.enablePan();
    _resizeStartGlobalByNode.remove(node.id);
    _resizeStartSizeByNode.remove(node.id);
    lastEvent = canceled ? 'resize cancel ${node.id}' : 'resize end ${node.id}';
  }

  Widget buildNodeWidget(DemoNode node) {
    void handleActionTap() => onActionTap(node.id);
    void handleResizeStart(Offset g) => onResizeStart(node, g);
    void handleResizeUpdate(Offset g) => onResizeUpdate(node, g);
    void handleResizeEnd(bool canceled) =>
        onResizeEnd(node, canceled: canceled);
    Widget child = NodeCard(
      node: node,
      onBuilt: () => _onNodeBuilt(node.id),
      onActionTap: handleActionTap,
      onResizeStart: handleResizeStart,
      onResizeUpdate: handleResizeUpdate,
      onResizeEnd: handleResizeEnd,
    );
    if (node.tiltRadians != 0) {
      child = Transform.rotate(
        angle: node.tiltRadians,
        alignment: Alignment.center,
        child: child,
      );
    }
    return child;
  }

  @override
  void dispose() {
    _disposed = true;
    canvasController.camera.renderStatsListenable.removeListener(
      _onRenderStatsChanged,
    );
    for (final n in nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _onNodeBuilt(String id) {
    if (!_enableN0BuildProbe) return;
    if (id != 'N0') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      final next = ++_n0BuildCount;
      // ignore: avoid_print
      print('probeNodeBuild id=N0 count=$next zoom=${zoom.toStringAsFixed(3)}');
    });
  }

  void _onRenderStatsChanged() {
    final stats = canvasController.camera.renderStats;
    if (stats == null) return;
    final visible = stats.visibleItems;
    final total = stats.totalItems;
    if (visible == _lastVisibleItems && total == _lastTotalItems) return;
    _lastVisibleItems = visible;
    _lastTotalItems = total;
    if (_traceCullingStats) {
      // ignore: avoid_print
      print(
        'culling visible=$visible total=$total zoom=${stats.scale.toStringAsFixed(3)}',
      );
    }
  }

  DemoNode _createNode(
    int index, {
    Offset? initialPosition,
    double tiltRadians = 0.0,
  }) {
    final rng = math.Random(42 + (index * 7919));
    final col = index % gridColumns;
    final row = index ~/ gridColumns;
    final jitterX = (rng.nextDouble() - 0.5) * 40;
    final jitterY = (rng.nextDouble() - 0.5) * 24;
    return DemoNode(
      id: 'N$index',
      initialPosition:
          initialPosition ??
          Offset(
            worldOriginX + col * gridSpacingX + jitterX,
            worldOriginY + row * gridSpacingY + jitterY,
          ),
      initialSize: const Size(190, 128),
      color: Color.lerp(
        const Color(0xFF045275),
        const Color(0xFF089099),
        rng.nextDouble(),
      )!,
      tiltRadians: tiltRadians,
    );
  }

  DemoNode? _targetNodeForCamera() {
    for (final n in nodes) {
      if (n.id == 'N0') return n;
    }
    if (nodes.isEmpty) return null;
    return nodes.first;
  }

  Offset _spawnAnchorWorld() {
    final stats = canvasController.camera.renderStats;
    if (stats == null || stats.viewportSize.isEmpty) {
      return Offset.zero;
    }
    final center = Offset(
      stats.viewportSize.width * 0.5,
      stats.viewportSize.height * 0.5,
    );
    return canvasController.camera.screenToWorld(center);
  }

  void _spawn(int count, {bool tilted = false, double spreadMultiplier = 1.0}) {
    if (count <= 0) return;
    final anchor = _spawnAnchorWorld();
    final added = <DemoNode>[];
    final columns = math.max(1, math.sqrt(count).ceil());
    final rows = (count / columns).ceil();
    const baseSpacingX = 230.0;
    const baseSpacingY = 172.0;
    final spacingX = baseSpacingX * spreadMultiplier;
    final spacingY = baseSpacingY * spreadMultiplier;
    final halfCols = (columns - 1) * 0.5;
    final halfRows = (rows - 1) * 0.5;
    for (var i = 0; i < count; i++) {
      final index = _nextNodeIndex++;
      final col = i % columns;
      final row = i ~/ columns;
      final centeredX = (col - halfCols) * spacingX;
      final centeredY = (row - halfRows) * spacingY;
      final rng = math.Random(1337 + (index * 7919));
      final jitter = Offset(
        (rng.nextDouble() - 0.5) * 24.0,
        (rng.nextDouble() - 0.5) * 16.0,
      );
      final spread = Offset(centeredX, centeredY) + jitter;
      final tilt = tilted ? (((index % 2) == 0 ? 1 : -1) * 0.14) : 0.0;
      final node = _createNode(
        index,
        initialPosition: anchor + spread,
        tiltRadians: tilt,
      );
      added.add(node);
    }
    nodes.addAll(added);
    _rebuildNodeItems();
    nodeCount = nodes.length;
    lastEvent = tilted ? 'spawn tilt +$count' : 'spawn +$count';
    notifyListeners();
  }

  void _rebuildNodeItems() {
    nodeItems
      ..clear()
      ..addAll(nodes.map(_buildCanvasItem));
  }

  CanvasItem _buildCanvasItem(DemoNode node) {
    return CanvasItem(
      id: node.id,
      worldPosition: node.position.value,
      size: CanvasItemSize.auto(),
      dragEnabled: nodesDraggable,
      behavior: const CanvasItemBehavior(
        draggable: true,
        bringToFront: CanvasBringToFrontBehavior.onTapOrDragStart,
      ),
      onDragStart: (_) {
        node.dragging.value = true;
        lastEvent = 'drag start ${node.id}';
        notifyListeners();
      },
      onDragUpdate: (event) {
        node.position.value = event.worldPosition;
      },
      onDragEnd: (event) {
        node.dragging.value = false;
        node.position.value = event.worldPosition;
        lastEvent = 'drag end ${node.id}';
        notifyListeners();
      },
      onDragCancel: (event) {
        node.dragging.value = false;
        node.position.value = event.worldPosition;
        lastEvent = 'drag cancel ${node.id}';
        notifyListeners();
      },
      child: buildNodeWidget(node),
    );
  }
}
