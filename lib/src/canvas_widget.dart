import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show Listenable, ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'camera_store.dart';
import 'controller.dart';
import 'item_store.dart';
import 'layer_store.dart';
import 'models.dart';

class InfinityCanvas extends StatefulWidget {
  final List<CanvasLayer> layers;
  final CanvasController controller;
  final CanvasInputBehavior inputBehavior;
  final bool enableCulling;
  final double cullPadding;
  final Clip clipBehavior;
  final bool enableBringToFrontOrdering;

  final Function(double currentZoom)? onZoomChanged;

  InfinityCanvas({
    super.key,
    required this.layers,
    required this.controller,
    this.inputBehavior = const CanvasInputBehavior.desktop(),
    this.enableCulling = false,
    this.cullPadding = 250.0,
    this.clipBehavior = Clip.hardEdge,
    this.enableBringToFrontOrdering = true,
    this.onZoomChanged,
  }) : assert(
         CanvasLayerStore.hasUniqueLayerIds(layers),
         'Canvas layer ids must be unique',
       ),
       assert(
         CanvasLayerStore.hasUniqueItemIds(layers),
         'Canvas item ids must be unique',
       );

  @override
  State<InfinityCanvas> createState() => _InfinityCanvasState();
}

class _InfinityCanvasState extends State<InfinityCanvas> {
  CanvasController? _controller;
  late final CanvasCameraStore _cameraStore;
  late final CanvasItemStore _itemStore;
  late CanvasLayerStore _layerStore;
  final GlobalKey _canvasAreaKey = GlobalKey();
  int _activeDragCount = 0;
  final Stopwatch _renderStatsStopwatch = Stopwatch()..start();
  bool _renderStatsQueued = false;
  Timer? _renderStatsTimer;
  static const Duration _renderStatsMinInterval = Duration(milliseconds: 120);
  double? _gestureStartScale;
  Offset? _gestureReferenceFocalWorld;
  int _cachedVisibleWorldTransformRevision = -1;
  Size _cachedVisibleWorldViewport = Size.zero;
  double _cachedVisibleWorldPadding = double.nan;
  Rect _cachedVisibleWorldRect = Rect.zero;

  @override
  void initState() {
    super.initState();

    _cameraStore = CanvasCameraStore();
    _itemStore = CanvasItemStore(
      frontOrderingEnabled: widget.enableBringToFrontOrdering,
    );
    _layerStore = CanvasLayerStore(widget.layers);

    _controller = widget.controller;
    _controller!.addListener(_onControllerChanged);
    _controller!.attachItemAccessors(
      readDiagnostics: _readItemDiagnostics,
      readPositionListenable: _readItemPositionListenable,
      setWorldPosition: _setItemWorldPosition,
      setWorldPositions: _setItemWorldPositions,
      setTransform: _setItemTransform,
      mutateTransform: _mutateItemTransform,
      setDragEnabled: _setItemDragEnabled,
      bringToFront: _bringItemToFront,
      readWorldBounds: _readItemWorldBounds,
      hasLayerId: _layerStore.hasLayerId,
    );
    _itemStore.syncForItems(
      items: _layerStore.allItems,
      layerIds: _layerStore.itemLayers.map((layer) => layer.id),
      onAnyItemPositionChanged: _onTrackedItemPositionChanged,
    );
    _cameraStore.resetTracking(_controller!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestRenderStats(immediate: true);
    });
  }

  @override
  void didUpdateWidget(covariant InfinityCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _controller?.detachItemAccessors();
      _controller?.removeListener(_onControllerChanged);
      _controller = widget.controller;
      _controller!.addListener(_onControllerChanged);
      _controller!.attachItemAccessors(
        readDiagnostics: _readItemDiagnostics,
        readPositionListenable: _readItemPositionListenable,
        setWorldPosition: _setItemWorldPosition,
        setWorldPositions: _setItemWorldPositions,
        setTransform: _setItemTransform,
        mutateTransform: _mutateItemTransform,
        setDragEnabled: _setItemDragEnabled,
        bringToFront: _bringItemToFront,
        readWorldBounds: _readItemWorldBounds,
        hasLayerId: _layerStore.hasLayerId,
      );
      _cameraStore.resetTracking(_controller!);
    }

    _layerStore.replaceLayers(widget.layers);
    if (oldWidget.enableBringToFrontOrdering !=
        widget.enableBringToFrontOrdering) {
      _itemStore.setFrontOrderingEnabled(widget.enableBringToFrontOrdering);
    }
    _itemStore.syncForItems(
      items: _layerStore.allItems,
      layerIds: _layerStore.itemLayers.map((layer) => layer.id),
      onAnyItemPositionChanged: _onTrackedItemPositionChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestRenderStats(immediate: true);
    });
  }

  @override
  void dispose() {
    _renderStatsTimer?.cancel();
    _cameraStore.dispose();
    _itemStore.dispose();
    _controller?.detachItemAccessors();
    _controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final changed = _cameraStore.handleControllerChanged(
      controller: _controller!,
      onZoomChanged: widget.onZoomChanged,
    );
    if (!changed) return;
    if (_cameraStore.lastLayerChanged) {
      setState(() {});
    }
    _requestRenderStats();
  }

  int _visibleItemCount(Rect screenVisible) {
    if (!widget.enableCulling) {
      var count = 0;
      for (final layer in _layerStore.itemLayers) {
        if (_isLayerVisible(layer.id)) {
          count += layer.items.length;
        }
      }
      return count;
    }

    final visibleWorld = _readVisibleWorldRectForCulling();
    int visible = 0;
    for (final layer in _layerStore.itemLayers) {
      if (!_isLayerVisible(layer.id)) continue;
      for (final item in layer.items) {
        final baseSize = _itemBaseSize(item);
        if (baseSize == null) {
          visible++;
          continue;
        }
        final pos = _itemStore.worldPositionFor(item.id) ?? item.worldPosition;
        final rect = _transformedWorldRect(
          worldPos: pos,
          baseSize: baseSize,
          transform: _itemStore.transformFor(item.id),
        );
        if (visibleWorld.overlaps(rect)) {
          visible++;
        }
      }
    }
    return visible;
  }

  Size? _itemBaseSize(CanvasItem node) {
    return _itemStore.baseSizeFor(node);
  }

  Rect _readVisibleWorldRectForCulling() {
    final viewportSize = _cameraStore.viewportSize;
    if (viewportSize.isEmpty) return Rect.zero;
    final transformRevision = _controller!.camera.transformRevision;
    final scale = _controller!.camera.scale;
    final safeScale = scale.abs() < 1e-6 ? 1e-6 : scale.abs();
    final worldCullPadding = widget.cullPadding / safeScale;

    if (_cachedVisibleWorldTransformRevision == transformRevision &&
        _cachedVisibleWorldViewport == viewportSize &&
        _cachedVisibleWorldPadding == worldCullPadding) {
      return _cachedVisibleWorldRect;
    }

    _cachedVisibleWorldTransformRevision = transformRevision;
    _cachedVisibleWorldViewport = viewportSize;
    _cachedVisibleWorldPadding = worldCullPadding;
    _cachedVisibleWorldRect = _controller!.camera
        .getVisibleWorldRect(viewportSize)
        .inflate(worldCullPadding);
    return _cachedVisibleWorldRect;
  }

  CanvasItem? _itemById(String id) {
    return _layerStore.itemById(id);
  }

  CanvasKitItemDiagnostics? _readItemDiagnostics(String id) {
    final node = _itemById(id);
    if (node == null) return null;

    final worldPosition = _itemStore.worldPositionFor(id) ?? node.worldPosition;
    final estimatedSize = node.size.estimatedSize;
    final measuredSize = _itemStore.measuredSizeFor(id);
    final effectiveSize = estimatedSize ?? measuredSize;

    Rect? screenRect;
    if (effectiveSize != null) {
      final topLeft = _controller!.camera.worldToScreen(worldPosition);
      final scale = _controller!.camera.scale;
      screenRect = Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        effectiveSize.width * scale,
        effectiveSize.height * scale,
      );
    }

    return CanvasKitItemDiagnostics(
      id: id,
      worldPosition: worldPosition,
      draggable: node.behavior.draggable && _itemStore.isDragEnabled(id),
      estimatedSize: estimatedSize,
      measuredSize: measuredSize,
      effectiveSize: effectiveSize,
      screenRect: screenRect,
    );
  }

  bool _setItemWorldPosition(String id, Offset worldPosition) {
    return _itemStore.setWorldPosition(id, worldPosition);
  }

  int _setItemWorldPositions(Map<String, Offset> worldPositionsById) {
    return _itemStore.setWorldPositions(worldPositionsById);
  }

  bool _setItemTransform(String id, Matrix4? transform) {
    return _itemStore.setTransform(id, transform);
  }

  bool _mutateItemTransform(
    String id,
    void Function(Matrix4 transform) mutator,
  ) {
    return _itemStore.mutateTransform(id, mutator);
  }

  bool _setItemDragEnabled(String id, bool enabled) {
    return _itemStore.setDragEnabled(id, enabled);
  }

  ValueListenable<Offset>? _readItemPositionListenable(String id) {
    return _itemStore.positionListenableFor(id);
  }

  bool _bringItemToFront(String id) {
    if (_itemById(id) == null) return false;
    final changed = _itemStore.bringToFront(id);
    if (changed && mounted) {
      setState(() {});
    }
    return changed;
  }

  Rect? _readItemWorldBounds({
    Iterable<String>? itemIds,
    double worldPadding = 0.0,
  }) {
    final includeIds = itemIds?.toSet();
    var hasAny = false;
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;

    for (final item in _layerStore.allItems) {
      if (includeIds != null && !includeIds.contains(item.id)) continue;
      final pos = _itemStore.worldPositionFor(item.id) ?? item.worldPosition;
      final baseSize = _itemBaseSize(item);
      final l = pos.dx;
      final t = pos.dy;
      final r = pos.dx + (baseSize?.width ?? 0.0);
      final b = pos.dy + (baseSize?.height ?? 0.0);
      left = l < left ? l : left;
      top = t < top ? t : top;
      right = r > right ? r : right;
      bottom = b > bottom ? b : bottom;
      hasAny = true;
    }

    if (!hasAny) return null;
    var rect = Rect.fromLTRB(left, top, right, bottom);
    if (worldPadding != 0.0) {
      rect = rect.inflate(worldPadding);
    }
    return rect;
  }

  void _onTrackedItemPositionChanged() {
    if (!mounted || !widget.enableCulling) return;
    if (_activeDragCount > 0) return;
    _requestRenderStats();
  }

  Offset _toCanvasLocal(Offset globalPosition) {
    final renderObject = _canvasAreaKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.globalToLocal(globalPosition);
    }
    return globalPosition;
  }

  void _onEntityDragStart() {
    _activeDragCount++;
  }

  void _onEntityDragEnd() {
    if (_activeDragCount > 0) {
      _activeDragCount--;
    }
    if (_activeDragCount == 0) {
      _requestRenderStats(immediate: true);
    }
  }

  void _onItemMeasured(String id, Size size) {
    if (!mounted) return;
    final changed = _itemStore.updateMeasuredSize(id, size);
    if (!changed) {
      return;
    }
    _cameraStore.markVisualStateChanged();
    _requestRenderStats();
  }

  bool get _isPanEnabled {
    return widget.inputBehavior.enablePan &&
        _controller!.camera.panEnabled &&
        _activeDragCount == 0;
  }

  bool get _isPinchZoomEnabled {
    return widget.inputBehavior.enablePinchZoom && _activeDragCount == 0;
  }

  bool _isLayerVisible(CanvasLayerId layerId) {
    return _controller!.layers.isVisible(layerId);
  }

  _PlateGeometry _computePlateGeometry() {
    // Fixed, very large logical plate to avoid hit-test edge falloff caused by
    // finite dynamic bounds during pan/zoom. This keeps the plate subtree
    // stable while providing an effectively infinite interaction surface.
    const half = 50000.0;
    return const _PlateGeometry(
      origin: Offset(-half, -half),
      size: Size(half * 2, half * 2),
    );
  }

  void _publishRenderStats() {
    if (!mounted || _controller == null) return;
    _cameraStore.publishRenderStats(
      controller: _controller!,
      cullPadding: widget.cullPadding,
      totalItems: _layerStore.totalItemCount,
      visibleItemCount: _visibleItemCount,
    );
  }

  void _requestRenderStats({bool immediate = false}) {
    if (!mounted || _controller == null) return;
    if (immediate) {
      _renderStatsTimer?.cancel();
      _renderStatsQueued = false;
      _renderStatsStopwatch.reset();
      _publishRenderStats();
      return;
    }

    final elapsed = _renderStatsStopwatch.elapsed;
    if (elapsed >= _renderStatsMinInterval) {
      _renderStatsStopwatch.reset();
      _publishRenderStats();
      return;
    }

    if (_renderStatsQueued) return;
    _renderStatsQueued = true;
    final remaining = _renderStatsMinInterval - elapsed;
    _renderStatsTimer = Timer(remaining, () {
      _renderStatsQueued = false;
      if (!mounted || _controller == null) return;
      _renderStatsStopwatch.reset();
      _publishRenderStats();
    });
  }

  Widget _buildWidgetLayer(CanvasOverlayLayer layer) {
    Widget buildLayer(BuildContext context) {
      final transform = _controller!.camera.transform;
      final widgetLayer = layer.builder(context, transform, _controller!);
      if (!layer.ignorePointer) return widgetLayer;
      return IgnorePointer(child: widgetLayer);
    }

    if (layer.listenable == null) {
      return Positioned.fill(child: Builder(builder: buildLayer));
    }

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: layer.listenable!,
        builder: (context, _) {
          return buildLayer(context);
        },
      ),
    );
  }

  Widget _buildPainterLayer(CanvasPainterLayer layer) {
    return Positioned.fill(
      child: ValueListenableBuilder<int>(
        valueListenable: _cameraStore.tick,
        builder: (context, _, __) {
          final painter = layer.painterBuilder(_controller!.camera.transform);
          return IgnorePointer(child: CustomPaint(painter: painter));
        },
      ),
    );
  }

  Widget _buildItemsLayer(CanvasPositionedItemsLayer layer) {
    return _buildPlateItemsLayer(layer);
  }

  Widget _buildPlateLayer({
    required Widget worldStack,
    required _PlateGeometry plateGeometry,
  }) {
    return Positioned(
      left: 0,
      top: 0,
      width: plateGeometry.size.width,
      height: plateGeometry.size.height,
      child: ValueListenableBuilder<int>(
        valueListenable: _cameraStore.tick,
        child: worldStack,
        builder: (context, _, child) {
          final transform = _controller!.camera.transform
            ..translate(plateGeometry.origin.dx, plateGeometry.origin.dy);
          return Transform(
            alignment: Alignment.topLeft,
            transform: transform,
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildPlateItemsLayer(CanvasPositionedItemsLayer layer) {
    final orderedItems = _itemStore.orderedItemsForLayer(
      layerId: layer.id,
      items: layer.items,
    );
    final plateGeometry = _computePlateGeometry();
    final runtime = _PlateItemRuntime(
      plateOrigin: plateGeometry.origin,
      controller: _controller!,
      cameraTick: _cameraStore.tick,
      viewportSize: _cameraStore.viewportSize,
      enableCulling: widget.enableCulling,
      resolveBaseSize: _itemBaseSize,
      onMeasured: _onItemMeasured,
      readVisibleWorldRect: _readVisibleWorldRectForCulling,
      toCanvasLocal: _toCanvasLocal,
      onDragStart: _onEntityDragStart,
      onDragEnd: _onEntityDragEnd,
      setWorldPosition: _setItemWorldPosition,
      onBringToFront: _bringItemToFront,
    );

    final worldStack = SizedBox(
      width: plateGeometry.size.width,
      height: plateGeometry.size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final node in orderedItems)
            _PlateItem(
              key: ValueKey('plate-item-${node.id}'),
              node: node,
              positionListenable: _itemStore.positionListenableFor(node.id)!,
              dragEnabledListenable: _itemStore.dragEnabledListenableFor(
                node.id,
              )!,
              transformListenable: _itemStore.transformListenableFor(node.id)!,
              runtime: runtime,
            ),
        ],
      ),
    );
    return _buildPlateLayer(
      worldStack: worldStack,
      plateGeometry: plateGeometry,
    );
  }

  List<Widget> _buildOrderedLayers() {
    final layers = <Widget>[];
    for (final layer in _layerStore.visibleLayers(_isLayerVisible)) {
      if (layer is CanvasOverlayLayer) {
        layers.add(_buildWidgetLayer(layer));
      } else if (layer is CanvasPainterLayer) {
        layers.add(_buildPainterLayer(layer));
      } else if (layer is CanvasPositionedItemsLayer) {
        layers.add(_buildItemsLayer(layer));
      }
    }
    return layers;
  }

  void _onCanvasScaleStart(ScaleStartDetails details) {
    if (_controller == null || _activeDragCount > 0) return;
    _gestureStartScale = _controller!.camera.scale;
    _gestureReferenceFocalWorld = _controller!.camera.screenToWorld(
      details.localFocalPoint,
    );
  }

  void _onCanvasScaleUpdate(ScaleUpdateDetails details) {
    if (_controller == null || _activeDragCount > 0) return;

    final localFocal = details.localFocalPoint;

    if (details.pointerCount >= 2) {
      if (_isPinchZoomEnabled) {
        final referenceWorld =
            _gestureReferenceFocalWorld ??
            _controller!.camera.screenToWorld(localFocal);
        final startScale = _gestureStartScale ?? _controller!.camera.scale;
        final desiredScale = startScale * details.scale;

        _controller!.camera.setScale(desiredScale, focalWorld: referenceWorld);

        final focalWorldAfter = _controller!.camera.screenToWorld(localFocal);
        final correction = referenceWorld - focalWorldAfter;
        if (correction != Offset.zero) {
          _controller!.camera.translateWorld(correction);
        }
        _gestureReferenceFocalWorld = _controller!.camera.screenToWorld(
          localFocal,
        );
        return;
      }

      if (_isPanEnabled && details.focalPointDelta != Offset.zero) {
        final worldDelta = _controller!.camera.deltaScreenToWorld(
          details.focalPointDelta,
        );
        _controller!.camera.translateWorld(worldDelta);
        _gestureReferenceFocalWorld = _controller!.camera.screenToWorld(
          localFocal,
        );
      }
      return;
    }

    if (_isPanEnabled && details.focalPointDelta != Offset.zero) {
      final worldDelta = _controller!.camera.deltaScreenToWorld(
        details.focalPointDelta,
      );
      _controller!.camera.translateWorld(worldDelta);
      _gestureReferenceFocalWorld = _controller!.camera.screenToWorld(
        localFocal,
      );
    }
  }

  void _onCanvasScaleEnd(ScaleEndDetails details) {
    _gestureStartScale = null;
    _gestureReferenceFocalWorld = null;
  }

  void _onCanvasPointerSignal(PointerSignalEvent event) {
    if (_controller == null) return;

    if (event is PointerScaleEvent) {
      if (!_isPinchZoomEnabled) return;
      final focalWorld = _controller!.camera.screenToWorld(event.localPosition);
      _controller!.camera.setScale(
        _controller!.camera.scale * event.scale,
        focalWorld: focalWorld,
      );
      return;
    }

    if (event is! PointerScrollEvent) return;

    if (event.kind == PointerDeviceKind.trackpad) {
      if (!_isPanEnabled) return;
      final worldDelta = _controller!.camera.deltaScreenToWorld(
        -event.scrollDelta,
      );
      _controller!.camera.translateWorld(worldDelta);
      return;
    }

    if (!widget.inputBehavior.enableWheelZoom &&
        event.kind != PointerDeviceKind.trackpad) {
      return;
    }
    final focalWorld = _controller!.camera.screenToWorld(event.localPosition);
    final scaleChange = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
    _controller!.camera.setScale(
      _controller!.camera.scale * scaleChange,
      focalWorld: focalWorld,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportChanged = _cameraStore.setViewportSize(
          Size(constraints.maxWidth, constraints.maxHeight),
        );
        if (viewportChanged) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _requestRenderStats(immediate: true);
          });
        }

        return Listener(
          key: _canvasAreaKey,
          behavior: HitTestBehavior.translucent,
          onPointerSignal: _onCanvasPointerSignal,
          child: Stack(
            clipBehavior: widget.clipBehavior,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _onCanvasScaleStart,
                  onScaleUpdate: _onCanvasScaleUpdate,
                  onScaleEnd: _onCanvasScaleEnd,
                ),
              ),
              ..._buildOrderedLayers(),
            ],
          ),
        );
      },
    );
  }
}

@immutable
class _PlateGeometry {
  final Offset origin;
  final Size size;

  const _PlateGeometry({required this.origin, required this.size});
}

Rect _transformedWorldRect({
  required Offset worldPos,
  required Size baseSize,
  Matrix4? transform,
}) {
  final raw = Rect.fromLTWH(
    worldPos.dx,
    worldPos.dy,
    baseSize.width,
    baseSize.height,
  );
  if (transform == null) return raw;

  final pivot = Offset(baseSize.width * 0.5, baseSize.height * 0.5);
  Offset mapPoint(Offset local) {
    final centered = local - pivot;
    final v = Vector3(centered.dx, centered.dy, 0)..applyMatrix4(transform);
    return Offset(v.x + pivot.dx + worldPos.dx, v.y + pivot.dy + worldPos.dy);
  }

  final p0 = mapPoint(Offset.zero);
  final p1 = mapPoint(Offset(baseSize.width, 0));
  final p2 = mapPoint(Offset(0, baseSize.height));
  final p3 = mapPoint(Offset(baseSize.width, baseSize.height));
  final left = math.min(math.min(p0.dx, p1.dx), math.min(p2.dx, p3.dx));
  final right = math.max(math.max(p0.dx, p1.dx), math.max(p2.dx, p3.dx));
  final top = math.min(math.min(p0.dy, p1.dy), math.min(p2.dy, p3.dy));
  final bottom = math.max(math.max(p0.dy, p1.dy), math.max(p2.dy, p3.dy));
  return Rect.fromLTRB(left, top, right, bottom);
}

@immutable
class _PlateItemRuntime {
  final Offset plateOrigin;
  final CanvasController controller;
  final ValueListenable<int> cameraTick;
  final Size viewportSize;
  final bool enableCulling;
  final Size? Function(CanvasItem node) resolveBaseSize;
  final void Function(String id, Size size) onMeasured;
  final Rect Function() readVisibleWorldRect;
  final Offset Function(Offset globalPosition) toCanvasLocal;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final bool Function(String id, Offset worldPosition) setWorldPosition;
  final ValueChanged<String> onBringToFront;

  const _PlateItemRuntime({
    required this.plateOrigin,
    required this.controller,
    required this.cameraTick,
    required this.viewportSize,
    required this.enableCulling,
    required this.resolveBaseSize,
    required this.onMeasured,
    required this.readVisibleWorldRect,
    required this.toCanvasLocal,
    required this.onDragStart,
    required this.onDragEnd,
    required this.setWorldPosition,
    required this.onBringToFront,
  });
}

class _PlateItem extends StatefulWidget {
  final CanvasItem node;
  final ValueListenable<Offset> positionListenable;
  final ValueListenable<bool> dragEnabledListenable;
  final ValueListenable<Matrix4?> transformListenable;
  final _PlateItemRuntime runtime;

  const _PlateItem({
    super.key,
    required this.node,
    required this.positionListenable,
    required this.dragEnabledListenable,
    required this.transformListenable,
    required this.runtime,
  });

  @override
  State<_PlateItem> createState() => _PlateItemState();
}

class _PlateItemState extends State<_PlateItem> {
  bool _dragActive = false;
  bool _hovered = false;
  Offset _grabOffsetWorld = Offset.zero;
  late Listenable _cullingTick;

  bool get _isDragEnabled => widget.dragEnabledListenable.value;
  bool get _isItemDraggable => widget.node.behavior.draggable && _isDragEnabled;

  bool get _bringToFrontOnTap {
    final behavior = widget.node.behavior.bringToFront;
    return behavior == CanvasBringToFrontBehavior.onTap ||
        behavior == CanvasBringToFrontBehavior.onTapOrDragStart;
  }

  bool get _bringToFrontOnDragStart {
    final behavior = widget.node.behavior.bringToFront;
    return behavior == CanvasBringToFrontBehavior.onDragStart ||
        behavior == CanvasBringToFrontBehavior.onTapOrDragStart;
  }

  void _bringToFrontNow() {
    widget.runtime.onBringToFront(widget.node.id);
  }

  void _bringToFrontAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bringToFrontNow();
    });
  }

  void _onDragEnabledChanged() {
    if (!_isItemDraggable && _dragActive) {
      _endDrag(canceled: true);
    }
  }

  void _rebuildCullingTick() {
    _cullingTick = Listenable.merge([
      widget.runtime.cameraTick,
      widget.transformListenable,
    ]);
  }

  void _setHovered(bool hovered) {
    if (_hovered == hovered) return;
    _hovered = hovered;
    widget.node.onHoverChanged?.call(hovered);
  }

  @override
  void initState() {
    super.initState();
    _rebuildCullingTick();
    widget.dragEnabledListenable.addListener(_onDragEnabledChanged);
  }

  void _startDrag(Offset globalPosition) {
    if (!_isItemDraggable || _dragActive) return;
    if (_bringToFrontOnDragStart) {
      _bringToFrontAfterFrame();
    }
    final local = widget.runtime.toCanvasLocal(globalPosition);
    final pointerWorld = widget.runtime.controller.camera.screenToWorld(local);
    _grabOffsetWorld = widget.positionListenable.value - pointerWorld;
    _dragActive = true;
    widget.node.onDragStart?.call(
      CanvasItemDragEvent(
        id: widget.node.id,
        worldPosition: widget.positionListenable.value,
        pointerGlobalPosition: globalPosition,
      ),
    );
    widget.runtime.onDragStart();
  }

  void _updateDrag(Offset globalPosition) {
    if (!_dragActive || !_isItemDraggable) return;
    final current = widget.positionListenable.value;
    final local = widget.runtime.toCanvasLocal(globalPosition);
    final pointerWorld = widget.runtime.controller.camera.screenToWorld(local);
    final next = pointerWorld + _grabOffsetWorld;
    if (next == current) return;
    widget.runtime.setWorldPosition(widget.node.id, next);
    widget.node.onDragUpdate?.call(
      CanvasItemDragEvent(
        id: widget.node.id,
        worldPosition: next,
        worldDelta: next - current,
        pointerGlobalPosition: globalPosition,
      ),
    );
  }

  void _endDrag({required bool canceled, Offset? globalPosition}) {
    if (!_dragActive) return;
    _dragActive = false;
    final event = CanvasItemDragEvent(
      id: widget.node.id,
      worldPosition: widget.positionListenable.value,
      pointerGlobalPosition: globalPosition,
    );
    if (canceled) {
      widget.node.onDragCancel?.call(event);
    } else {
      widget.node.onDragEnd?.call(event);
    }
    widget.runtime.onDragEnd();
  }

  @override
  void didUpdateWidget(covariant _PlateItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dragEnabledListenable != widget.dragEnabledListenable) {
      oldWidget.dragEnabledListenable.removeListener(_onDragEnabledChanged);
      widget.dragEnabledListenable.addListener(_onDragEnabledChanged);
    }
    if (!_isItemDraggable && _dragActive) {
      _endDrag(canceled: true);
    }
    if (oldWidget.runtime.cameraTick != widget.runtime.cameraTick ||
        oldWidget.transformListenable != widget.transformListenable) {
      _rebuildCullingTick();
    }
  }

  @override
  void dispose() {
    if (_hovered) {
      _setHovered(false);
    }
    widget.dragEnabledListenable.removeListener(_onDragEnabledChanged);
    _endDrag(canceled: true);
    super.dispose();
  }

  bool _isVisibleInWorld(Offset worldPos, Size? baseSize, Matrix4? transform) {
    if (!widget.runtime.enableCulling || _dragActive) return true;
    if (widget.runtime.viewportSize.isEmpty) return true;
    if (baseSize == null) return true;

    final visibleWorld = widget.runtime.readVisibleWorldRect();
    final itemRect = _transformedWorldRect(
      worldPos: worldPos,
      baseSize: baseSize,
      transform: transform,
    );
    return visibleWorld.overlaps(itemRect);
  }

  Widget _buildItem({required bool canDrag}) {
    final measuredChild = _MeasureSize(
      onChange: (size) => widget.runtime.onMeasured(widget.node.id, size),
      child: widget.node.child,
    );

    return ValueListenableBuilder<Offset>(
      valueListenable: widget.positionListenable,
      child: measuredChild,
      builder: (context, worldPos, child) {
        final fixedBaseSize = widget.node.size.estimatedSize;
        final effectiveBaseSize = widget.runtime.resolveBaseSize(widget.node);

        Widget itemChild = fixedBaseSize == null
            ? child!
            : SizedBox(
                width: fixedBaseSize.width,
                height: fixedBaseSize.height,
                child: child,
              );

        if (canDrag) {
          itemChild = GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onTapUp: _bringToFrontOnTap ? (_) => _bringToFrontNow() : null,
            onPanStart: (details) => _startDrag(details.globalPosition),
            onPanUpdate: (details) => _updateDrag(details.globalPosition),
            onPanEnd: (_) => _endDrag(canceled: false),
            onPanCancel: () => _endDrag(canceled: true),
            child: itemChild,
          );
        } else if (_bringToFrontOnTap) {
          itemChild = Listener(
            behavior: HitTestBehavior.deferToChild,
            onPointerDown: (_) => _bringToFrontNow(),
            child: itemChild,
          );
        }

        if (widget.node.onHoverChanged != null) {
          itemChild = MouseRegion(
            opaque: true,
            onEnter: (_) => _setHovered(true),
            onExit: (_) => _setHovered(false),
            child: itemChild,
          );
        }

        itemChild = ValueListenableBuilder<Matrix4?>(
          valueListenable: widget.transformListenable,
          child: itemChild,
          builder: (context, transform, child) {
            if (transform == null) return child!;
            return Transform(
              transform: transform,
              alignment: Alignment.center,
              transformHitTests: widget.node.transformHitTests,
              child: child,
            );
          },
        );

        // Keep each node in its own repaint boundary so dragging one node
        // does not force raster repaint of all sibling nodes.
        itemChild = RepaintBoundary(child: itemChild);

        final positioned = Positioned(
          key: ValueKey('item-${widget.node.id}'),
          left: worldPos.dx - widget.runtime.plateOrigin.dx,
          top: worldPos.dy - widget.runtime.plateOrigin.dy,
          width: fixedBaseSize?.width,
          height: fixedBaseSize?.height,
          child: itemChild,
        );

        if (!widget.runtime.enableCulling) {
          return positioned;
        }

        return ListenableBuilder(
          listenable: _cullingTick,
          child: positioned,
          builder: (context, child) {
            if (_isVisibleInWorld(
              worldPos,
              effectiveBaseSize,
              widget.transformListenable.value,
            )) {
              return child!;
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildItem(canDrag: _isItemDraggable);
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;

  const _MeasureSize({required this.onChange, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MeasureSizeRenderObject(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this.onChange);

  ValueChanged<Size> onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = child?.size ?? size;
    if (_oldSize == newSize) return;
    _oldSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(newSize));
  }
}
