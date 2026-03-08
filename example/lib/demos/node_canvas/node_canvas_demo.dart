import 'dart:math' as math;

import 'package:infinity_canvas/infinity_canvas.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

part 'node_widgets/node_card.dart';

class _Node {
  final String id;
  final ValueNotifier<Offset> position;
  final ValueNotifier<bool> dragging;
  final ValueNotifier<bool> resizing;
  final ValueNotifier<bool> dragEnabled;
  final ValueNotifier<Size> size;
  final Color color;
  final double tiltRadians;

  _Node({
    required this.id,
    required Offset initialPosition,
    required Size initialSize,
    required this.color,
    this.tiltRadians = 0.0,
  }) : position = ValueNotifier<Offset>(initialPosition),
       dragging = ValueNotifier<bool>(false),
       resizing = ValueNotifier<bool>(false),
       dragEnabled = ValueNotifier<bool>(true),
       size = ValueNotifier<Size>(initialSize);
}

enum _PainterHitTarget { body, button, resize }

class _PainterNodeHit {
  final _Node node;
  final _PainterHitTarget target;

  const _PainterNodeHit({required this.node, required this.target});
}

class NodeCanvasDemoPage extends StatefulWidget {
  const NodeCanvasDemoPage({super.key});

  @override
  State<NodeCanvasDemoPage> createState() => _NodeCanvasDemoPageState();
}

class _NodeCanvasDemoPageState extends State<NodeCanvasDemoPage> {
  static const double _plateHalfExtent = 50000.0;
  final CanvasController _controller = CanvasController(
    minZoom: 0.02,
    maxZoom: 5.0,
  );
  static const int _initialNodeCount = 320;
  static const int _gridColumns = 30;
  static const double _gridSpacingX = 235.0;
  static const double _gridSpacingY = 185.0;
  static const double _worldOriginX = -3600.0;
  static const double _worldOriginY = -2800.0;

  late final List<_Node> _nodes;
  late final List<CanvasItem> _canvasItems;
  int _nextNodeIndex = 0;
  int _nodesRevision = 0;

  final ValueNotifier<int> _canvasRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> _nodeCount = ValueNotifier<int>(0);
  final ValueNotifier<double> _zoom = ValueNotifier<double>(1.0);
  final ValueNotifier<String> _lastEvent = ValueNotifier<String>('-');
  final ValueNotifier<int> _n0Builds = ValueNotifier<int>(0);
  final ValueNotifier<String> _n0Diagnostics = ValueNotifier<String>('-');
  final ValueNotifier<bool> _nodesDraggable = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _usePainterNodes = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _hoveredPainterNodeId = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<Offset> _paintedPlateOrigin = ValueNotifier<Offset>(
    const Offset(-_plateHalfExtent, -_plateHalfExtent),
  );
  final ValueNotifier<int> _painterOrderRevision = ValueNotifier<int>(0);
  final Map<String, int> _resizeMoveCounts = <String, int>{};
  final Map<String, Offset> _resizeStartGlobalByNode = <String, Offset>{};
  final Map<String, Size> _resizeStartSizeByNode = <String, Size>{};
  int? _painterActivePointer;
  String? _painterDragNodeId;
  String? _painterResizeNodeId;
  String? _painterPressedButtonNodeId;
  Offset _painterDragGrabOffsetWorld = Offset.zero;

  @override
  void initState() {
    super.initState();
    _nodes = _generateNodes(_initialNodeCount);
    _canvasItems = <CanvasItem>[];
    for (final n in _nodes) {
      _appendNodeToCanvasLists(n);
    }
    _nextNodeIndex = _nodes.length;
    _nodeCount.value = _nodes.length;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.camera.setScale(0.32, focalWorld: Offset.zero);
      _controller.camera.translateWorld(const Offset(760, 620));
    });
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.position.dispose();
      n.dragging.dispose();
      n.resizing.dispose();
      n.dragEnabled.dispose();
      n.size.dispose();
    }
    _zoom.dispose();
    _canvasRevision.dispose();
    _nodeCount.dispose();
    _lastEvent.dispose();
    _n0Builds.dispose();
    _n0Diagnostics.dispose();
    _nodesDraggable.dispose();
    _usePainterNodes.dispose();
    _hoveredPainterNodeId.dispose();
    _paintedPlateOrigin.dispose();
    _painterOrderRevision.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<_Node> _generateNodes(int count) {
    return List<_Node>.generate(count, (i) => _createNode(i));
  }

  _Node _createNode(
    int index, {
    Offset? initialPosition,
    double tiltRadians = 0.0,
  }) {
    final rng = math.Random(42 + (index * 7919));
    final col = index % _gridColumns;
    final row = index ~/ _gridColumns;
    final jitterX = (rng.nextDouble() - 0.5) * 40;
    final jitterY = (rng.nextDouble() - 0.5) * 24;

    return _Node(
      id: 'N$index',
      initialPosition:
          initialPosition ??
          Offset(
            _worldOriginX + col * _gridSpacingX + jitterX,
            _worldOriginY + row * _gridSpacingY + jitterY,
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

  Offset _spawnAnchorWorld() {
    final stats = _controller.camera.renderStats;
    if (stats == null || stats.viewportSize.isEmpty) {
      return const Offset(0, 0);
    }
    final screenCenter = Offset(
      stats.viewportSize.width * 0.5,
      stats.viewportSize.height * 0.5,
    );
    return _controller.camera.screenToWorld(screenCenter);
  }

  void _spawnNodes(int count, {bool tilted = false}) {
    if (count <= 0) return;
    final anchor = _spawnAnchorWorld();
    final added = <_Node>[];
    for (var i = 0; i < count; i++) {
      final index = _nextNodeIndex++;
      final spread = Offset(
        ((index % 17) - 8) * 26,
        (((index ~/ 17) % 13) - 6) * 22,
      );
      final tilt = tilted ? (((index % 2) == 0 ? 1 : -1) * 0.14) : 0.0;
      final node = _createNode(
        index,
        initialPosition: anchor + spread,
        tiltRadians: tilt,
      );
      node.dragEnabled.value = _nodesDraggable.value;
      added.add(node);
    }
    _nodes.addAll(added);
    for (final n in added) {
      _appendNodeToCanvasLists(n);
    }
    _nodesRevision++;
    _nodeCount.value = _nodes.length;
    _canvasRevision.value++;
    _lastEvent.value = tilted ? 'spawn tilt +$count' : 'spawn +$count';
  }

  void _spawnOneNode() => _spawnNodes(1);

  void _spawnHundredNodes() => _spawnNodes(100);

  void _spawnTiltNode() => _spawnNodes(1, tilted: true);

  void _spawnThousandNodes() => _spawnNodes(1000);

  void _onNodeBuilt(String id) {
    if (id != 'N0') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final next = _n0Builds.value + 1;
      _n0Builds.value = next;
    });
  }

  void _startNodeResize(_Node node, Offset globalPosition) {
    if (node.resizing.value) return;
    node.resizing.value = true;
    node.dragging.value = false;
    node.dragEnabled.value = false;
    _controller.items.setDragEnabled(node.id, false);
    _controller.camera.disablePan();
    _resizeMoveCounts[node.id] = 0;
    _resizeStartGlobalByNode[node.id] = globalPosition;
    _resizeStartSizeByNode[node.id] = node.size.value;
    _lastEvent.value = 'resize start ${node.id}';
  }

  void _updateNodeResize(_Node node, Offset globalPosition) {
    if (!node.resizing.value) return;
    final startGlobal = _resizeStartGlobalByNode[node.id];
    final startSize = _resizeStartSizeByNode[node.id];
    if (startGlobal == null || startSize == null) return;
    final count = (_resizeMoveCounts[node.id] ?? 0) + 1;
    _resizeMoveCounts[node.id] = count;
    final zoom = _controller.camera.scale.clamp(1e-6, double.infinity);
    final screenDelta = globalPosition - startGlobal;
    final worldDelta = Offset(screenDelta.dx / zoom, screenDelta.dy / zoom);
    final next = Size(
      (startSize.width + worldDelta.dx).clamp(120.0, 420.0).toDouble(),
      (startSize.height + worldDelta.dy).clamp(96.0, 320.0).toDouble(),
    );
    if (next == node.size.value) return;
    node.size.value = next;
    // if (node.id == 'N0') {
    //   _updateN0Diagnostics();
    // }
  }

  void _endNodeResize(_Node node, {required bool canceled}) {
    if (!node.resizing.value && node.dragEnabled.value) return;
    node.resizing.value = false;
    node.dragEnabled.value = _nodesDraggable.value;
    _controller.items.setDragEnabled(node.id, _nodesDraggable.value);
    _controller.camera.enablePan();
    _resizeMoveCounts.remove(node.id);
    _resizeStartGlobalByNode.remove(node.id);
    _resizeStartSizeByNode.remove(node.id);
    _lastEvent.value = canceled
        ? 'resize cancel ${node.id}'
        : 'resize end ${node.id}';
  }

  _Node? _findNodeById(String id) {
    for (final n in _nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  Offset _rotateOffset(Offset value, double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Offset(
      (value.dx * c) - (value.dy * s),
      (value.dx * s) + (value.dy * c),
    );
  }

  Offset _painterPointerToNodeLocal(_Node node, Offset pointerScreen) {
    final pointerWorld = _controller.camera.screenToWorld(pointerScreen);
    final size = node.size.value;
    var local = pointerWorld - node.position.value;
    if (node.tiltRadians != 0.0) {
      final center = Offset(size.width * 0.5, size.height * 0.5);
      local = _rotateOffset(local - center, -node.tiltRadians) + center;
    }
    return local;
  }

  Rect _painterButtonLocalRect(Size size) {
    return Rect.fromLTWH(
      8,
      size.height - 50,
      (size.width - 16).clamp(0.0, double.infinity),
      24,
    );
  }

  Rect _painterResizeHandleLocalRect(Size size) {
    const handleSize = 20.0;
    const pad = 4.0;
    return Rect.fromLTWH(
      size.width - pad - handleSize,
      size.height - pad - handleSize,
      handleSize,
      handleSize,
    );
  }

  _PainterNodeHit? _painterHitTest(Offset localPosition) {
    for (var i = _nodes.length - 1; i >= 0; i--) {
      final node = _nodes[i];
      final size = node.size.value;
      final point = _painterPointerToNodeLocal(node, localPosition);
      final nodeRect = Rect.fromLTWH(0, 0, size.width, size.height);
      if (!nodeRect.contains(point)) continue;
      if (_painterResizeHandleLocalRect(size).contains(point)) {
        return _PainterNodeHit(node: node, target: _PainterHitTarget.resize);
      }
      if (_painterButtonLocalRect(size).contains(point)) {
        return _PainterNodeHit(node: node, target: _PainterHitTarget.button);
      }
      return _PainterNodeHit(node: node, target: _PainterHitTarget.body);
    }
    return null;
  }

  void _setPainterHovered(String? id) {
    if (_hoveredPainterNodeId.value == id) return;
    _hoveredPainterNodeId.value = id;
  }

  void _bringNodeToFront(_Node node) {
    final index = _nodes.indexOf(node);
    if (index < 0 || index == _nodes.length - 1) return;
    _nodes.removeAt(index);
    _nodes.add(node);
    _nodesRevision++;
    if (_usePainterNodes.value) {
      _painterOrderRevision.value = _painterOrderRevision.value + 1;
      return;
    }
    _rebuildCanvasItems();
  }

  void _resetPainterInteractionState({required bool canceled}) {
    if (_painterDragNodeId case final dragId?) {
      final node = _findNodeById(dragId);
      if (node != null) {
        node.dragging.value = false;
        _lastEvent.value = canceled
            ? 'drag cancel $dragId'
            : 'drag end $dragId';
      }
      _painterDragNodeId = null;
    }
    if (_painterResizeNodeId case final resizeId?) {
      final node = _findNodeById(resizeId);
      if (node != null) {
        _endNodeResize(node, canceled: canceled);
      }
      _painterResizeNodeId = null;
    }
    _painterPressedButtonNodeId = null;
    _painterActivePointer = null;
    _controller.camera.enablePan();
  }

  void _onPainterPointerHover(PointerHoverEvent event) {
    if (!_usePainterNodes.value) return;
    if (_painterActivePointer != null) return;
    final hit = _painterHitTest(event.localPosition);
    _setPainterHovered(hit?.node.id);
  }

  void _onPainterPointerDown(PointerDownEvent event) {
    if (!_usePainterNodes.value) return;
    if (_painterActivePointer != null) return;
    final hit = _painterHitTest(event.localPosition);
    _setPainterHovered(hit?.node.id);
    if (hit == null) return;

    _painterActivePointer = event.pointer;
    final node = hit.node;
    _bringNodeToFront(node);

    switch (hit.target) {
      case _PainterHitTarget.resize:
        _painterResizeNodeId = node.id;
        _startNodeResize(node, event.localPosition);
        break;
      case _PainterHitTarget.button:
        _painterPressedButtonNodeId = node.id;
        _controller.camera.disablePan();
        break;
      case _PainterHitTarget.body:
        if (!_nodesDraggable.value || !node.dragEnabled.value) {
          _painterActivePointer = null;
          return;
        }
        _painterDragNodeId = node.id;
        node.dragging.value = true;
        _controller.camera.disablePan();
        final pointerWorld = _controller.camera.screenToWorld(
          event.localPosition,
        );
        _painterDragGrabOffsetWorld = node.position.value - pointerWorld;
        _lastEvent.value = 'drag start ${node.id}';
        break;
    }
  }

  void _onPainterPointerMove(PointerMoveEvent event) {
    if (!_usePainterNodes.value) return;
    if (_painterActivePointer != event.pointer) return;

    if (_painterResizeNodeId case final resizeId?) {
      final node = _findNodeById(resizeId);
      if (node != null) {
        _updateNodeResize(node, event.localPosition);
      }
      return;
    }

    if (_painterDragNodeId case final dragId?) {
      final node = _findNodeById(dragId);
      if (node == null) return;
      final pointerWorld = _controller.camera.screenToWorld(
        event.localPosition,
      );
      final next = pointerWorld + _painterDragGrabOffsetWorld;
      if (next != node.position.value) {
        node.position.value = next;
        _lastEvent.value = 'drag move ${node.id}';
      }
      return;
    }

    final hit = _painterHitTest(event.localPosition);
    _setPainterHovered(hit?.node.id);
  }

  void _onPainterPointerUp(PointerUpEvent event) {
    if (!_usePainterNodes.value) return;
    if (_painterActivePointer != event.pointer) return;

    if (_painterPressedButtonNodeId case final buttonId?) {
      final hit = _painterHitTest(event.localPosition);
      if (hit != null &&
          hit.node.id == buttonId &&
          hit.target == _PainterHitTarget.button) {
        _lastEvent.value = 'button $buttonId';
      }
    }

    _resetPainterInteractionState(canceled: false);
    final hit = _painterHitTest(event.localPosition);
    _setPainterHovered(hit?.node.id);
  }

  void _onPainterPointerCancel(PointerCancelEvent event) {
    if (_painterActivePointer != event.pointer) return;
    _resetPainterInteractionState(canceled: true);
    _setPainterHovered(null);
  }

  Widget _buildNodeChild(_Node n) {
    Widget child = _NodeCard(
      node: n,
      paintedSkin: false,
      enableHover: true,
      useMaterialActionButton: false,
      onBuilt: () => _onNodeBuilt(n.id),
      onResizeStart: (globalPosition) => _startNodeResize(n, globalPosition),
      onResizeUpdate: (globalPosition) => _updateNodeResize(n, globalPosition),
      onResizeEnd: (canceled) => _endNodeResize(n, canceled: canceled),
      onActionTap: () => _lastEvent.value = 'button ${n.id}',
    );
    if (n.tiltRadians != 0) {
      child = Transform.rotate(
        angle: n.tiltRadians,
        alignment: Alignment.center,
        child: child,
      );
    }
    return child;
  }

  CanvasItem _buildCanvasItem(_Node n) {
    return CanvasItem(
      id: n.id,
      worldPosition: n.position.value,
      size: CanvasItemSize.auto(),
      dragEnabled: n.dragEnabled.value,
      behavior: const CanvasItemBehavior(
        draggable: true,
        bringToFront: CanvasBringToFrontBehavior.onTapOrDragStart,
      ),
      onDragStart: (_) {
        n.dragging.value = true;
        _lastEvent.value = 'drag start ${n.id}';
      },
      onDragUpdate: (event) {
        n.position.value = event.worldPosition;
        _lastEvent.value = 'drag move ${n.id}';
      },
      onDragEnd: (event) {
        n.dragging.value = false;
        n.position.value = event.worldPosition;
        _lastEvent.value = 'drag end ${n.id}';
      },
      onDragCancel: (event) {
        n.dragging.value = false;
        n.position.value = event.worldPosition;
        _lastEvent.value = 'drag cancel ${n.id}';
      },
      child: _buildNodeChild(n),
    );
  }

  void _appendNodeToCanvasLists(_Node node) {
    final item = _buildCanvasItem(node);
    _canvasItems.add(item);
  }

  void _rebuildCanvasItems() {
    _canvasItems.clear();
    for (final n in _nodes) {
      _appendNodeToCanvasLists(n);
    }
    _canvasRevision.value++;
  }

  void _setPainterNodeMode(bool usePainterNodes) {
    if (_usePainterNodes.value == usePainterNodes) return;
    if (!usePainterNodes) {
      _resetPainterInteractionState(canceled: true);
      _setPainterHovered(null);
    }
    _usePainterNodes.value = usePainterNodes;
    _canvasRevision.value++;
    _lastEvent.value = usePainterNodes
        ? 'node layer painter'
        : 'node layer widget';
  }

  CanvasItem _buildPainterBatchItem() {
    final plateSize = _plateHalfExtent * 2;
    return CanvasItem(
      id: 'nodes-painted-batch-item',
      worldPosition: _paintedPlateOrigin.value,
      size: CanvasItemSize.fixed(plateSize, plateSize),
      dragEnabled: false,
      behavior: const CanvasItemBehavior(
        draggable: false,
        bringToFront: CanvasBringToFrontBehavior.never,
      ),
      child: SizedBox(
        width: plateSize,
        height: plateSize,
        child: IgnorePointer(
          child: CustomPaint(
            painter: _SemiRichNodesWorldPainter(
              nodes: _nodes,
              nodesRevision: _nodesRevision,
              plateOrigin: _paintedPlateOrigin.value,
              hoveredNodeId: _hoveredPainterNodeId.value,
              repaint: Listenable.merge([
                _canvasRevision,
                _painterOrderRevision,
                _hoveredPainterNodeId,
                ..._nodes.map((n) => n.position),
                ..._nodes.map((n) => n.size),
                ..._nodes.map((n) => n.dragging),
                ..._nodes.map((n) => n.resizing),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _setGlobalItemDragEnabled(bool enabled) {
    if (_nodesDraggable.value == enabled) return;
    _nodesDraggable.value = enabled;
    if (!enabled && _painterDragNodeId != null) {
      _resetPainterInteractionState(canceled: true);
    }
    for (final n in _nodes) {
      if (!n.resizing.value) {
        n.dragEnabled.value = enabled;
        _controller.items.setDragEnabled(n.id, enabled);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<double>(
                  valueListenable: _zoom,
                  builder: (context, zoom, _) {
                    return Text('Zoom: ${zoom.toStringAsFixed(3)}');
                  },
                ),
                const SizedBox(width: 14),
                ValueListenableBuilder<int>(
                  valueListenable: _nodeCount,
                  builder: (context, count, _) {
                    return Text('Nodes: $count');
                  },
                ),
                const SizedBox(width: 14),
                ValueListenableBuilder<bool>(
                  valueListenable: _usePainterNodes,
                  builder: (context, painted, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(painted ? 'Layer: painter' : 'Layer: widget'),
                        const SizedBox(width: 6),
                        Switch(value: painted, onChanged: _setPainterNodeMode),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 14),
                FilledButton.tonal(
                  onPressed: _spawnOneNode,
                  child: const Text('Spawn +1'),
                ),
                const SizedBox(width: 14),
                FilledButton.tonal(
                  onPressed: _spawnHundredNodes,
                  child: const Text('Spawn +100'),
                ),
                const SizedBox(width: 14),
                FilledButton.tonal(
                  onPressed: _spawnThousandNodes,
                  child: const Text('Spawn +1000'),
                ),
                const SizedBox(width: 14),
                FilledButton.tonal(
                  onPressed: _spawnTiltNode,
                  child: const Text('Spawn Tilt'),
                ),
                const SizedBox(width: 14),
                ValueListenableBuilder<bool>(
                  valueListenable: _nodesDraggable,
                  builder: (context, draggable, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(draggable ? 'Drag: on' : 'Drag: off'),
                        const SizedBox(width: 6),
                        Switch(
                          value: draggable,
                          onChanged: _setGlobalItemDragEnabled,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 14),
                ValueListenableBuilder<int>(
                  valueListenable: _n0Builds,
                  builder: (context, count, _) {
                    return Text('N0 builds: $count');
                  },
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: ValueListenableBuilder<String>(
                    valueListenable: _n0Diagnostics,
                    builder: (context, info, _) {
                      return Text(
                        info,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _lastEvent,
                    builder: (context, last, _) {
                      return Text(
                        'Last: $last',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _canvasRevision,
              builder: (context, _, __) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _usePainterNodes,
                  builder: (context, usePainterNodes, _) {
                    return ClipRect(
                      child: InfinityCanvas(
                        controller: _controller,
                        enableCulling: false,
                        onZoomChanged: (z) {
                          _zoom.value = z;
                          // _updateN0Diagnostics();
                        },
                        layers: [
                          CanvasLayer.painter(
                            id: 'bg-grid',
                            painterBuilder: (transform) =>
                                _InfiniteGridPainter(transform: transform),
                          ),
                          CanvasLayer.painter(
                            id: 'links',
                            painterBuilder: (transform) => _NodeLinksPainter(
                              nodes: _nodes,
                              nodesRevision: _nodesRevision,
                              transform: transform,
                              columns: _gridColumns,
                              repaint: Listenable.merge([
                                _canvasRevision,
                                ..._nodes.map((n) => n.position),
                                ..._nodes.map((n) => n.size),
                              ]),
                              lineColor: const Color(0x6609A9C8),
                            ),
                          ),
                          if (!usePainterNodes)
                            CanvasLayer.positionedItems(
                              id: 'nodes',
                              items: _canvasItems,
                            ),
                          if (usePainterNodes)
                            CanvasLayer.positionedItems(
                              id: 'nodes-painted-batch',
                              items: [_buildPainterBatchItem()],
                            ),
                          if (usePainterNodes)
                            CanvasLayer.overlay(
                              id: 'nodes-painted-interaction',
                              ignorePointer: false,
                              builder: (context, transform, controller) {
                                return MouseRegion(
                                  opaque: false,
                                  onHover: _onPainterPointerHover,
                                  onExit: (_) => _setPainterHovered(null),
                                  child: Listener(
                                    behavior: HitTestBehavior.translucent,
                                    onPointerDown: _onPainterPointerDown,
                                    onPointerMove: _onPainterPointerMove,
                                    onPointerUp: _onPainterPointerUp,
                                    onPointerCancel: _onPainterPointerCancel,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InfiniteGridPainter extends CustomPainter {
  final Matrix4 transform;

  const _InfiniteGridPainter({required this.transform});

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

    // Keep visual density stable while zooming.
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
  bool shouldRepaint(covariant _InfiniteGridPainter oldDelegate) {
    return oldDelegate.transform != transform;
  }
}

class _NodeLinksPainter extends CustomPainter {
  final List<_Node> nodes;
  final int nodesRevision;
  final Matrix4 transform;
  final int columns;
  final Color lineColor;

  _NodeLinksPainter({
    required this.nodes,
    required this.nodesRevision,
    required this.transform,
    required this.columns,
    required this.lineColor,
    required Listenable repaint,
  }) : super(repaint: repaint);

  Offset _worldToScreen(Offset world) {
    final m = transform.storage;
    return Offset(
      world.dx * m[0] + world.dy * m[4] + m[12],
      world.dx * m[1] + world.dy * m[5] + m[13],
    );
  }

  Offset _nodeCenter(_Node n) {
    final p = n.position.value;
    final s = n.size.value;
    return Offset(p.dx + (s.width * 0.5), p.dy + (s.height * 0.5));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty || columns <= 0) return;
    final p = Paint()
      ..color = lineColor
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
  bool shouldRepaint(covariant _NodeLinksPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.nodesRevision != nodesRevision ||
        oldDelegate.nodes != nodes ||
        oldDelegate.columns != columns ||
        oldDelegate.lineColor != lineColor;
  }
}

class _SemiRichNodesWorldPainter extends CustomPainter {
  final List<_Node> nodes;
  final int nodesRevision;
  final Offset plateOrigin;
  final String? hoveredNodeId;

  _SemiRichNodesWorldPainter({
    required this.nodes,
    required this.nodesRevision,
    required this.plateOrigin,
    required this.hoveredNodeId,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;
    final visible = Offset.zero & size;

    for (final n in nodes) {
      final worldPos = n.position.value;
      final nodeSize = n.size.value;
      final localTopLeft = worldPos - plateOrigin;
      final approxBounds = Rect.fromLTWH(
        localTopLeft.dx,
        localTopLeft.dy,
        nodeSize.width,
        nodeSize.height,
      ).inflate(40);
      if (!visible.overlaps(approxBounds)) continue;

      canvas.save();
      canvas.translate(localTopLeft.dx, localTopLeft.dy);
      if (n.tiltRadians != 0) {
        canvas.translate(nodeSize.width * 0.5, nodeSize.height * 0.5);
        canvas.rotate(n.tiltRadians);
        canvas.translate(-nodeSize.width * 0.5, -nodeSize.height * 0.5);
      }

      final cardRect = Rect.fromLTWH(0, 0, nodeSize.width, nodeSize.height);
      const radius = Radius.circular(10.0);
      final card = RRect.fromRectAndRadius(cardRect, radius);

      final fill = Paint()..color = n.color.withValues(alpha: 0.92);
      final hotState =
          n.dragging.value || n.resizing.value || hoveredNodeId == n.id;
      final border = Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      final headerFill = Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      final chipFill = Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      final activeFill = Paint()
        ..color = hotState ? const Color(0xFFFEA91D) : const Color(0xFF42C67B);

      canvas.drawRRect(card.shift(const Offset(0, 1.2)), shadow);
      canvas.drawRRect(card, fill);
      canvas.drawRRect(card, border);

      final headerRect = Rect.fromLTWH(0, 0, nodeSize.width, 26.0);
      final header = RRect.fromRectAndCorners(
        headerRect,
        topLeft: radius,
        topRight: radius,
      );
      canvas.drawRRect(header, headerFill);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(8, 34, nodeSize.width * 0.32, 12),
          const Radius.circular(6),
        ),
        chipFill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(8, 53, nodeSize.width * 0.54, 12),
          const Radius.circular(6),
        ),
        chipFill,
      );

      canvas.drawCircle(Offset(nodeSize.width - 15, 15), 7, activeFill);

      final tp = TextPainter(
        text: TextSpan(
          text: n.id,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: nodeSize.width - 30);
      tp.paint(canvas, Offset(8, (26 - tp.height) * 0.5));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SemiRichNodesWorldPainter oldDelegate) {
    return oldDelegate.nodesRevision != nodesRevision ||
        oldDelegate.nodes != nodes ||
        oldDelegate.plateOrigin != plateOrigin ||
        oldDelegate.hoveredNodeId != hoveredNodeId;
  }
}
