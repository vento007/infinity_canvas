import 'package:flutter/foundation.dart' show Listenable, ValueListenable;
import 'package:flutter/material.dart';

typedef CanvasLayerId = String;

class CanvasItemSize {
  final Size? estimatedSize;

  const CanvasItemSize.auto() : estimatedSize = null;

  CanvasItemSize.fixed(double width, double height)
    : assert(width > 0, 'width must be > 0.'),
      assert(height > 0, 'height must be > 0.'),
      estimatedSize = Size(width, height);

  CanvasItemSize.fromSize(Size size)
    : assert(size.width > 0, 'width must be > 0.'),
      assert(size.height > 0, 'height must be > 0.'),
      estimatedSize = size;
}

sealed class CanvasItemPosition {
  const CanvasItemPosition();
}

final class CanvasItemWorldPosition extends CanvasItemPosition {
  final Offset value;

  const CanvasItemWorldPosition(this.value);
}

final class CanvasItemScreenPosition extends CanvasItemPosition {
  final Offset value;

  const CanvasItemScreenPosition(this.value);
}

class CanvasItemDragEvent {
  final String id;
  final Offset worldPosition;
  final Offset? worldDelta;
  final Offset? pointerGlobalPosition;

  const CanvasItemDragEvent({
    required this.id,
    required this.worldPosition,
    this.worldDelta,
    this.pointerGlobalPosition,
  });
}

enum CanvasBringToFrontBehavior { never, onTap, onDragStart, onTapOrDragStart }

class CanvasItemBehavior {
  final bool draggable;
  final CanvasBringToFrontBehavior bringToFront;

  const CanvasItemBehavior({
    this.draggable = true,
    this.bringToFront = CanvasBringToFrontBehavior.never,
  });

  const CanvasItemBehavior.nodeEditor()
    : draggable = true,
      bringToFront = CanvasBringToFrontBehavior.onTapOrDragStart;
}

class CanvasItem {
  final String id;
  final Offset worldPosition;
  final CanvasItemSize size;
  final Widget child;
  final CanvasItemBehavior behavior;
  final bool dragEnabled;
  final ValueChanged<bool>? onHoverChanged;

  /// Whether the item's visual transform should affect pointer hit testing.
  ///
  /// Defaults to `false` for stable interaction while animating transformed
  /// visuals at scale.
  final bool transformHitTests;
  final ValueChanged<CanvasItemDragEvent>? onDragStart;
  final ValueChanged<CanvasItemDragEvent>? onDragUpdate;
  final ValueChanged<CanvasItemDragEvent>? onDragEnd;
  final ValueChanged<CanvasItemDragEvent>? onDragCancel;

  const CanvasItem({
    required this.id,
    required this.worldPosition,
    this.size = const CanvasItemSize.auto(),
    required this.child,
    this.behavior = const CanvasItemBehavior(),
    this.dragEnabled = true,
    this.onHoverChanged,
    this.transformHitTests = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
  });
}

class CanvasInputBehavior {
  final bool enablePan;
  final bool enableWheelZoom;
  final bool enablePinchZoom;

  const CanvasInputBehavior({
    this.enablePan = true,
    this.enableWheelZoom = true,
    this.enablePinchZoom = true,
  });

  const CanvasInputBehavior.desktop()
    : enablePan = true,
      enableWheelZoom = true,
      enablePinchZoom = true;

  const CanvasInputBehavior.touch()
    : enablePan = true,
      enableWheelZoom = false,
      enablePinchZoom = true;

  const CanvasInputBehavior.locked()
    : enablePan = false,
      enableWheelZoom = false,
      enablePinchZoom = false;

  CanvasInputBehavior copyWith({
    bool? enablePan,
    bool? enableWheelZoom,
    bool? enablePinchZoom,
  }) {
    return CanvasInputBehavior(
      enablePan: enablePan ?? this.enablePan,
      enableWheelZoom: enableWheelZoom ?? this.enableWheelZoom,
      enablePinchZoom: enablePinchZoom ?? this.enablePinchZoom,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CanvasInputBehavior &&
        other.enablePan == enablePan &&
        other.enableWheelZoom == enableWheelZoom &&
        other.enablePinchZoom == enablePinchZoom;
  }

  @override
  int get hashCode => Object.hash(enablePan, enableWheelZoom, enablePinchZoom);
}

abstract interface class CanvasCameraApi {
  Matrix4 get transform;
  double get scale;
  bool get panEnabled;

  /// Throttled render statistics for the current viewport.
  ///
  /// These values are not updated on every frame. They are sampled on a
  /// best-effort cadence suitable for diagnostics and overlays.
  ValueListenable<CanvasKitRenderStats?> get renderStatsListenable;
  CanvasKitRenderStats? get renderStats;

  void setPanEnabled(bool enabled);
  void enablePan();
  void disablePan();
  void setTransform(Matrix4 next);
  void jumpToWorldTopLeft(Offset worldTopLeft, {double? zoom});
  void jumpToWorldCenter(Offset worldCenter, {double? zoom});
  Future<void> animateToWorldTopLeft(
    Offset worldTopLeft, {
    double? zoom,
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeOutCubic,
  });
  Future<void> animateToWorldCenter(
    Offset worldCenter, {
    double? zoom,
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeOutCubic,
  });
  void fitWorldRect(Rect worldRect, {double paddingFraction = 0.08});
  void fitAllItems({
    double paddingFraction = 0.08,
    double worldPadding = 120.0,
    Iterable<String>? itemIds,
  });
  void translateWorld(Offset worldDelta);
  void setScale(double nextScale, {Offset focalWorld = Offset.zero});
  Offset deltaScreenToWorld(Offset screenDelta);
  Offset screenToWorld(Offset screenPoint);
  Offset worldToScreen(Offset worldPoint);
  Rect getVisibleWorldRect(Size viewportSize);
}

abstract interface class CanvasItemsApi {
  CanvasKitItemDiagnostics? getDiagnostics(String itemId);
  Offset? getWorldPosition(String itemId);
  ValueListenable<Offset>? positionListenable(String itemId);
  Size? getMeasuredSize(String itemId);
  Size? getEffectiveSize(String itemId);
  Rect? getScreenRect(String itemId);
  bool setWorldPosition(String itemId, Offset worldPosition);
  int setWorldPositions(Map<String, Offset> worldPositionsById);
  bool setTransform(String itemId, Matrix4? transform);
  bool mutateTransform(String itemId, void Function(Matrix4 transform) mutator);
  bool clearTransform(String itemId);
  bool setDragEnabled(String itemId, bool enabled);
  bool bringToFront(String itemId);
}

abstract interface class CanvasLayersApi {
  int get revision;
  bool isVisible(CanvasLayerId layerId);
  void setVisible(CanvasLayerId layerId, bool visible);
  void toggleVisible(CanvasLayerId layerId);
}

abstract interface class CanvasLayerController {
  Matrix4 get transform;
  double get scale;

  /// Throttled render statistics for the current viewport.
  ///
  /// These values are intended for diagnostics and overlays, not exact
  /// frame-perfect visibility decisions.
  ValueListenable<CanvasKitRenderStats?> get renderStatsListenable;
  CanvasKitRenderStats? get renderStats;

  /// Throttled visible item count from [renderStats].
  int get visibleItems;

  /// Throttled total item count from [renderStats].
  int get totalItems;
  CanvasCameraApi get camera;
  CanvasItemsApi get items;
  CanvasLayersApi get layers;
}

typedef CanvasTransformWidgetBuilder =
    Widget Function(
      BuildContext context,
      Matrix4 transform,
      CanvasLayerController controller,
    );
typedef CanvasTransformPainterBuilder =
    CustomPainter Function(Matrix4 transform);

sealed class CanvasLayer {
  final CanvasLayerId id;

  const CanvasLayer({required this.id});

  const factory CanvasLayer.overlay({
    required CanvasLayerId id,
    required CanvasTransformWidgetBuilder builder,
    bool ignorePointer,
    Listenable? listenable,
  }) = CanvasOverlayLayer;

  const factory CanvasLayer.painter({
    required CanvasLayerId id,
    required CanvasTransformPainterBuilder painterBuilder,
  }) = CanvasPainterLayer;

  const factory CanvasLayer.positionedItems({
    required CanvasLayerId id,
    required List<CanvasItem> items,
  }) = CanvasPositionedItemsLayer;
}

final class CanvasOverlayLayer extends CanvasLayer {
  final CanvasTransformWidgetBuilder builder;
  final bool ignorePointer;
  final Listenable? listenable;

  const CanvasOverlayLayer({
    required super.id,
    required this.builder,
    this.ignorePointer = true,
    this.listenable,
  });
}

final class CanvasPainterLayer extends CanvasLayer {
  final CanvasTransformPainterBuilder painterBuilder;

  const CanvasPainterLayer({required super.id, required this.painterBuilder});
}

final class CanvasPositionedItemsLayer extends CanvasLayer {
  final List<CanvasItem> items;

  const CanvasPositionedItemsLayer({required super.id, required this.items});
}

class CanvasKitRenderStats {
  final int totalItems;
  final int visibleItems;
  final double scale;
  final Size viewportSize;

  const CanvasKitRenderStats({
    required this.totalItems,
    required this.visibleItems,
    required this.scale,
    required this.viewportSize,
  });
}

class CanvasKitItemDiagnostics {
  final String id;
  final Offset worldPosition;
  final bool draggable;
  final Size? estimatedSize;
  final Size? measuredSize;
  final Size? effectiveSize;
  final Rect? screenRect;

  const CanvasKitItemDiagnostics({
    required this.id,
    required this.worldPosition,
    required this.draggable,
    required this.estimatedSize,
    required this.measuredSize,
    required this.effectiveSize,
    required this.screenRect,
  });
}
