import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import 'matrix_utils.dart';
import 'models.dart';

typedef _ReadItemDiagnostics = CanvasKitItemDiagnostics? Function(String id);
typedef _ReadItemPositionListenable =
    ValueListenable<Offset>? Function(String id);
typedef _ReadItemMeasuredSizeListenable =
    ValueListenable<Size?>? Function(String id);
typedef _ReadMeasurementRevision = ValueListenable<int> Function();
typedef _SetItemWorldPosition = bool Function(String id, Offset worldPosition);
typedef _SetItemWorldPositions =
    int Function(Map<String, Offset> worldPositionsById);
typedef _SetItemTransform = bool Function(String id, Matrix4? transform);
typedef _MutateItemTransform =
    bool Function(String id, void Function(Matrix4 transform) mutator);
typedef _SetItemDragEnabled = bool Function(String id, bool enabled);
typedef _BringItemToFront = bool Function(String id);
typedef _ReadItemWorldBounds =
    Rect? Function({Iterable<String>? itemIds, double worldPadding});
typedef _HasLayerId = bool Function(CanvasLayerId layerId);

bool _inNearlyZero(double value, {double epsilon = 1e-9}) {
  return value.abs() <= epsilon;
}

bool _isAxisAlignedScaleTranslate(Matrix4 transform, {double epsilon = 1e-9}) {
  final m = transform.storage;
  return _inNearlyZero(m[1], epsilon: epsilon) &&
      _inNearlyZero(m[4], epsilon: epsilon) &&
      _inNearlyZero(m[2], epsilon: epsilon) &&
      _inNearlyZero(m[6], epsilon: epsilon) &&
      _inNearlyZero(m[8], epsilon: epsilon) &&
      _inNearlyZero(m[9], epsilon: epsilon) &&
      _inNearlyZero(m[3], epsilon: epsilon) &&
      _inNearlyZero(m[7], epsilon: epsilon) &&
      _inNearlyZero(m[11], epsilon: epsilon) &&
      _inNearlyZero(m[14], epsilon: epsilon) &&
      (m[10] - 1.0).abs() <= epsilon &&
      (m[15] - 1.0).abs() <= epsilon;
}

Matrix4 _lerpMatrix4(Matrix4 a, Matrix4 b, double t) {
  final ta = t.clamp(0.0, 1.0);
  final av = a.storage;
  final bv = b.storage;
  final out = List<double>.filled(16, 0.0);
  for (var i = 0; i < 16; i++) {
    out[i] = av[i] + (bv[i] - av[i]) * ta;
  }
  return Matrix4.fromList(out);
}

/// Root controller for infinity_canvas.
///
/// It is split into sub-controllers to keep responsibilities explicit:
/// - [camera] for transform/pan/zoom operations
/// - [items] for item diagnostics and programmatic item position updates
/// - [layers] for layer visibility and order-state controls
class CanvasController extends ChangeNotifier implements CanvasApi {
  Matrix4 _transform;
  final double minZoom;
  final double maxZoom;

  bool _panEnabled = true;
  int _transformRevision = 0;
  int _layerRevision = 0;
  int _cameraAnimationGeneration = 0;
  Completer<void>? _cameraAnimationCompleter;
  final Map<CanvasLayerId, bool> _layerVisibilityOverrides =
      <CanvasLayerId, bool>{};

  final ValueNotifier<CanvasKitRenderStats?> _renderStats =
      ValueNotifier<CanvasKitRenderStats?>(null);
  final ValueNotifier<Size> _viewportSize = ValueNotifier<Size>(Size.zero);

  _ReadItemDiagnostics? _readItemDiagnostics;
  _ReadItemPositionListenable? _readItemPositionListenable;
  _ReadItemMeasuredSizeListenable? _readItemMeasuredSizeListenable;
  _ReadMeasurementRevision? _readMeasurementRevision;
  final ValueNotifier<int> _detachedMeasurementRevision = ValueNotifier<int>(0);
  _SetItemWorldPosition? _setItemWorldPosition;
  _SetItemWorldPositions? _setItemWorldPositions;
  _SetItemTransform? _setItemTransform;
  _MutateItemTransform? _mutateItemTransform;
  _SetItemDragEnabled? _setItemDragEnabled;
  _BringItemToFront? _bringItemToFront;
  _ReadItemWorldBounds? _readItemWorldBounds;
  _HasLayerId? _hasLayerId;

  @override
  late final CanvasCameraController camera = CanvasCameraController._(this);
  @override
  late final CanvasItemController items = CanvasItemController._(this);
  @override
  late final CanvasLayerVisibilityController layers =
      CanvasLayerVisibilityController._(this);

  static Matrix4 buildTransformForWorldTopLeft({
    required double zoom,
    required Offset worldTopLeft,
  }) {
    return Matrix4.identity()
      ..translate(-worldTopLeft.dx * zoom, -worldTopLeft.dy * zoom)
      ..scale(zoom, zoom);
  }

  CanvasController({
    Matrix4? initialTransform,
    Offset initialWorldTopLeft = Offset.zero,
    double initialZoom = 1.0,
    this.minZoom = 0.03,
    this.maxZoom = 8.0,
  }) : assert(
         initialTransform == null ||
             ((initialZoom - 1.0).abs() <= 1e-9 &&
                 initialWorldTopLeft == Offset.zero),
         'Use either initialTransform OR initialWorldTopLeft/initialZoom.',
       ),
       assert(minZoom > 0, 'minZoom must be > 0.'),
       assert(minZoom <= maxZoom, 'minZoom must be <= maxZoom.'),
       assert(
         initialZoom >= minZoom && initialZoom <= maxZoom,
         'initialZoom must be within minZoom..maxZoom.',
       ),
       _transform =
           initialTransform?.clone() ??
           buildTransformForWorldTopLeft(
             zoom: initialZoom,
             worldTopLeft: initialWorldTopLeft,
           );

  @override
  ValueListenable<CanvasKitRenderStats?> get renderStatsListenable =>
      _renderStats;
  @override
  CanvasKitRenderStats? get renderStats => _renderStats.value;
  @override
  Matrix4 get transform => camera.transform;
  @override
  double get scale => camera.scale;
  @override
  int get visibleItems => renderStats?.visibleItems ?? 0;
  @override
  int get totalItems => renderStats?.totalItems ?? 0;

  void _markTransformChanged({bool notify = false}) {
    _transformRevision++;
    if (notify) notifyListeners();
  }

  void _markLayerChanged({bool notify = false}) {
    _layerRevision++;
    if (notify) notifyListeners();
  }

  void _setTransformInternal(
    Matrix4 next, {
    bool notify = false,
    bool takeOwnership = false,
  }) {
    _transform = takeOwnership ? next : next.clone();
    _markTransformChanged(notify: notify);
  }

  void _setPanEnabled(bool enabled) {
    if (_panEnabled == enabled) return;
    _panEnabled = enabled;
    notifyListeners();
  }

  bool _isLayerVisible(CanvasLayerId layerId) {
    assert(_hasLayerId?.call(layerId) ?? true, 'Unknown layer id "$layerId".');
    return _layerVisibilityOverrides[layerId] ?? true;
  }

  void _setLayerVisible(CanvasLayerId layerId, bool visible) {
    assert(_hasLayerId?.call(layerId) ?? true, 'Unknown layer id "$layerId".');
    final current = _isLayerVisible(layerId);
    if (current == visible) return;
    _layerVisibilityOverrides[layerId] = visible;
    _markLayerChanged(notify: true);
  }

  void _toggleLayerVisible(CanvasLayerId layerId) {
    assert(_hasLayerId?.call(layerId) ?? true, 'Unknown layer id "$layerId".');
    _setLayerVisible(layerId, !_isLayerVisible(layerId));
  }

  CanvasKitItemDiagnostics? _getItemDiagnostics(String id) {
    return _readItemDiagnostics?.call(id);
  }

  bool _setItemPosition(String id, Offset worldPosition) {
    return _setItemWorldPosition?.call(id, worldPosition) ?? false;
  }

  int _setItemPositions(Map<String, Offset> worldPositionsById) {
    return _setItemWorldPositions?.call(worldPositionsById) ?? 0;
  }

  bool _setItemDragEnabledById(String id, bool enabled) {
    return _setItemDragEnabled?.call(id, enabled) ?? false;
  }

  bool _setItemTransformById(String id, Matrix4? transform) {
    return _setItemTransform?.call(id, transform) ?? false;
  }

  bool _mutateItemTransformById(
    String id,
    void Function(Matrix4 transform) mutator,
  ) {
    return _mutateItemTransform?.call(id, mutator) ?? false;
  }

  bool _bringItemToFrontById(String id) {
    return _bringItemToFront?.call(id) ?? false;
  }

  Rect? _getItemWorldBounds({
    Iterable<String>? itemIds,
    double worldPadding = 0.0,
  }) {
    return _readItemWorldBounds?.call(
      itemIds: itemIds,
      worldPadding: worldPadding,
    );
  }

  Offset _deltaScreenToWorld(Offset screenDelta) {
    final currentScale = _getScale();
    if (_inNearlyZero(currentScale)) return screenDelta;
    return Offset(screenDelta.dx / currentScale, screenDelta.dy / currentScale);
  }

  Offset _screenToWorld(Offset screenPoint) {
    if (_isAxisAlignedScaleTranslate(_transform)) {
      final m = _transform.storage;
      final sx = m[0];
      final sy = m[5];
      final tx = m[12];
      final ty = m[13];
      if (!_inNearlyZero(sx) && !_inNearlyZero(sy)) {
        return Offset((screenPoint.dx - tx) / sx, (screenPoint.dy - ty) / sy);
      }
    }

    try {
      final inverted = Matrix4.inverted(_transform);
      final v = Vector3(screenPoint.dx, screenPoint.dy, 0)
        ..applyMatrix4(inverted);
      return Offset(v.x, v.y);
    } on ArgumentError {
      return screenPoint;
    }
  }

  Offset _worldToScreen(Offset worldPoint) {
    if (_isAxisAlignedScaleTranslate(_transform)) {
      final m = _transform.storage;
      final sx = m[0];
      final sy = m[5];
      final tx = m[12];
      final ty = m[13];
      return Offset(worldPoint.dx * sx + tx, worldPoint.dy * sy + ty);
    }

    final v = Vector3(worldPoint.dx, worldPoint.dy, 0)
      ..applyMatrix4(_transform);
    return Offset(v.x, v.y);
  }

  Matrix4 _getTransform() => _transform.clone();

  double _getScale() => _transform.getMaxScaleOnAxis();

  Rect _getVisibleWorldRect(Size viewportSize) {
    if (_isAxisAlignedScaleTranslate(_transform)) {
      final m = _transform.storage;
      final sx = m[0];
      final sy = m[5];
      final tx = m[12];
      final ty = m[13];
      if (!_inNearlyZero(sx) && !_inNearlyZero(sy)) {
        final left = (0.0 - tx) / sx;
        final top = (0.0 - ty) / sy;
        final right = (viewportSize.width - tx) / sx;
        final bottom = (viewportSize.height - ty) / sy;
        return Rect.fromLTRB(
          math.min(left, right),
          math.min(top, bottom),
          math.max(left, right),
          math.max(top, bottom),
        );
      }
    }

    final topLeft = _screenToWorld(Offset.zero);
    final bottomRight = _screenToWorld(
      Offset(viewportSize.width, viewportSize.height),
    );
    return Rect.fromLTRB(
      math.min(topLeft.dx, bottomRight.dx),
      math.min(topLeft.dy, bottomRight.dy),
      math.max(topLeft.dx, bottomRight.dx),
      math.max(topLeft.dy, bottomRight.dy),
    );
  }

  void _cancelCameraAnimation() {
    _cameraAnimationGeneration++;
    final completer = _cameraAnimationCompleter;
    _cameraAnimationCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _animateTransform({
    required Matrix4 target,
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeOutCubic,
  }) {
    _cancelCameraAnimation();
    if (duration <= Duration.zero) {
      _setTransformInternal(target, notify: true, takeOwnership: true);
      return Future<void>.value();
    }

    final start = _transform.clone();
    final durationUs = duration.inMicroseconds;
    if (durationUs <= 0) {
      _setTransformInternal(target, notify: true, takeOwnership: true);
      return Future<void>.value();
    }
    if (matrixApproxEquals(start, target)) {
      return Future<void>.value();
    }

    final generation = _cameraAnimationGeneration;
    final completer = Completer<void>();
    _cameraAnimationCompleter = completer;
    Duration? startTimestamp;

    void onFrame(Duration timestamp) {
      if (_cameraAnimationGeneration != generation) {
        return;
      }
      startTimestamp ??= timestamp;
      final elapsedUs = (timestamp - startTimestamp!).inMicroseconds;
      final rawT = (elapsedUs / durationUs).clamp(0.0, 1.0);
      final easedT = curve.transform(rawT);
      final next = _lerpMatrix4(start, target, easedT);
      _setTransformInternal(next, notify: true, takeOwnership: true);
      if (rawT >= 1.0) {
        if (!completer.isCompleted) {
          completer.complete();
        }
        if (identical(_cameraAnimationCompleter, completer)) {
          _cameraAnimationCompleter = null;
        }
        return;
      }
      SchedulerBinding.instance.scheduleFrameCallback(onFrame);
      SchedulerBinding.instance.ensureVisualUpdate();
    }

    SchedulerBinding.instance.scheduleFrameCallback(onFrame);
    SchedulerBinding.instance.ensureVisualUpdate();
    return completer.future;
  }

  @override
  void dispose() {
    _cancelCameraAnimation();
    _renderStats.dispose();
    _viewportSize.dispose();
    _detachedMeasurementRevision.dispose();
    super.dispose();
  }
}

class CanvasCameraController implements CanvasCameraApi {
  final CanvasController _owner;

  const CanvasCameraController._(this._owner);

  @override
  Matrix4 get transform => _owner._getTransform();
  int get transformRevision => _owner._transformRevision;
  @override
  double get scale => _owner._getScale();
  @override
  bool get panEnabled => _owner._panEnabled;

  @override
  Size get viewportSize => _owner._viewportSize.value;

  @override
  ValueListenable<Size> get viewportSizeListenable => _owner._viewportSize;

  @override
  ValueListenable<CanvasKitRenderStats?> get renderStatsListenable =>
      _owner._renderStats;
  @override
  CanvasKitRenderStats? get renderStats => _owner._renderStats.value;

  @override
  void setPanEnabled(bool enabled) => _owner._setPanEnabled(enabled);

  @override
  void enablePan() => setPanEnabled(true);

  @override
  void disablePan() => setPanEnabled(false);

  @override
  void setTransform(Matrix4 next) {
    _owner._cancelCameraAnimation();
    _owner._setTransformInternal(next, notify: true);
  }

  @override
  void jumpToWorldTopLeft(Offset worldTopLeft, {double? zoom}) {
    _owner._cancelCameraAnimation();
    final effectiveZoom = (zoom ?? scale)
        .clamp(_owner.minZoom, _owner.maxZoom)
        .toDouble();
    final target = CanvasController.buildTransformForWorldTopLeft(
      zoom: effectiveZoom,
      worldTopLeft: worldTopLeft,
    );
    _owner._setTransformInternal(target, notify: true, takeOwnership: true);
  }

  @override
  void jumpToWorldCenter(Offset worldCenter, {double? zoom}) {
    final effectiveZoom = (zoom ?? scale)
        .clamp(_owner.minZoom, _owner.maxZoom)
        .toDouble();
    final viewport = viewportSize;
    if (!_isUsableViewport(viewport)) {
      jumpToWorldTopLeft(worldCenter, zoom: effectiveZoom);
      return;
    }
    final halfViewInWorld = Offset(
      viewport.width / (2 * effectiveZoom),
      viewport.height / (2 * effectiveZoom),
    );
    final worldTopLeft = worldCenter - halfViewInWorld;
    jumpToWorldTopLeft(worldTopLeft, zoom: effectiveZoom);
  }

  @override
  Future<void> animateToWorldTopLeft(
    Offset worldTopLeft, {
    double? zoom,
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeOutCubic,
  }) {
    final effectiveZoom = (zoom ?? scale)
        .clamp(_owner.minZoom, _owner.maxZoom)
        .toDouble();
    final target = CanvasController.buildTransformForWorldTopLeft(
      zoom: effectiveZoom,
      worldTopLeft: worldTopLeft,
    );
    return _owner._animateTransform(
      target: target,
      duration: duration,
      curve: curve,
    );
  }

  @override
  Future<void> animateToWorldCenter(
    Offset worldCenter, {
    double? zoom,
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeOutCubic,
  }) {
    final effectiveZoom = (zoom ?? scale)
        .clamp(_owner.minZoom, _owner.maxZoom)
        .toDouble();
    final viewport = viewportSize;
    if (!_isUsableViewport(viewport)) {
      return animateToWorldTopLeft(
        worldCenter,
        zoom: effectiveZoom,
        duration: duration,
        curve: curve,
      );
    }
    final halfViewInWorld = Offset(
      viewport.width / (2 * effectiveZoom),
      viewport.height / (2 * effectiveZoom),
    );
    final worldTopLeft = worldCenter - halfViewInWorld;
    return animateToWorldTopLeft(
      worldTopLeft,
      zoom: effectiveZoom,
      duration: duration,
      curve: curve,
    );
  }

  @override
  void fitWorldRect(Rect worldRect, {double paddingFraction = 0.08}) {
    if (worldRect.width <= 0 || worldRect.height <= 0) return;

    final viewport = viewportSize;
    if (!_isUsableViewport(viewport)) {
      jumpToWorldCenter(worldRect.center);
      return;
    }

    final clampedPadding = paddingFraction.clamp(0.0, 0.49);
    final viewW = viewport.width;
    final viewH = viewport.height;
    final fitW = math.max(1.0, viewW * (1.0 - clampedPadding * 2.0));
    final fitH = math.max(1.0, viewH * (1.0 - clampedPadding * 2.0));
    final zoomX = fitW / worldRect.width;
    final zoomY = fitH / worldRect.height;
    final targetZoom = math
        .min(zoomX, zoomY)
        .clamp(_owner.minZoom, _owner.maxZoom);

    jumpToWorldCenter(worldRect.center, zoom: targetZoom);
  }

  @override
  bool fitWorldRectAligned(
    Rect worldRect, {
    CanvasFitMode fit = CanvasFitMode.contain,
    Alignment alignment = Alignment.center,
    EdgeInsets screenPadding = EdgeInsets.zero,
    double? minZoom,
    double? maxZoom,
  }) {
    _validateFitZoomLimit(minZoom, 'minZoom');
    _validateFitZoomLimit(maxZoom, 'maxZoom');
    if (minZoom != null && maxZoom != null && minZoom > maxZoom) {
      throw ArgumentError('minZoom must be less than or equal to maxZoom.');
    }

    final effectiveMinZoom = math.max(
      _owner.minZoom,
      minZoom ?? _owner.minZoom,
    );
    final effectiveMaxZoom = math.min(
      _owner.maxZoom,
      maxZoom ?? _owner.maxZoom,
    );
    if (effectiveMinZoom > effectiveMaxZoom) {
      throw ArgumentError(
        'The requested zoom limits do not overlap the controller zoom range.',
      );
    }

    if (!_isUsableWorldRect(worldRect) ||
        !_isUsableAlignment(alignment) ||
        !_isUsablePadding(screenPadding)) {
      return false;
    }

    final viewport = viewportSize;
    if (!_isUsableViewport(viewport)) return false;

    final availableWidth =
        viewport.width - screenPadding.left - screenPadding.right;
    final availableHeight =
        viewport.height - screenPadding.top - screenPadding.bottom;
    if (!availableWidth.isFinite ||
        !availableHeight.isFinite ||
        availableWidth <= 0 ||
        availableHeight <= 0) {
      return false;
    }

    final widthZoom = availableWidth / worldRect.width;
    final heightZoom = availableHeight / worldRect.height;
    final fittedZoom = switch (fit) {
      CanvasFitMode.contain => math.min(widthZoom, heightZoom),
      CanvasFitMode.width => widthZoom,
      CanvasFitMode.height => heightZoom,
    };
    final targetZoom = fittedZoom
        .clamp(effectiveMinZoom, effectiveMaxZoom)
        .toDouble();
    final scaledSize = Size(
      worldRect.width * targetZoom,
      worldRect.height * targetZoom,
    );
    if (!scaledSize.width.isFinite || !scaledSize.height.isFinite) {
      return false;
    }

    final paddedViewport = Rect.fromLTWH(
      screenPadding.left,
      screenPadding.top,
      availableWidth,
      availableHeight,
    );
    final alignedScreenRect = alignment.inscribe(scaledSize, paddedViewport);
    final alignedOffset = alignedScreenRect.topLeft;
    final worldTopLeft = Offset(
      worldRect.left - (alignedOffset.dx / targetZoom),
      worldRect.top - (alignedOffset.dy / targetZoom),
    );
    if (!worldTopLeft.dx.isFinite || !worldTopLeft.dy.isFinite) return false;

    jumpToWorldTopLeft(worldTopLeft, zoom: targetZoom);
    return true;
  }

  @override
  void fitAllItems({
    double paddingFraction = 0.08,
    double worldPadding = 120.0,
    Iterable<String>? itemIds,
  }) {
    final worldRect = _owner._getItemWorldBounds(
      itemIds: itemIds,
      worldPadding: worldPadding,
    );
    if (worldRect == null) return;
    fitWorldRect(worldRect, paddingFraction: paddingFraction);
  }

  @override
  void translateWorld(Offset worldDelta) {
    if (worldDelta == Offset.zero) return;
    _owner._cancelCameraAnimation();
    final next = _owner._transform.clone()
      ..translate(worldDelta.dx, worldDelta.dy);
    _owner._setTransformInternal(next, notify: true, takeOwnership: true);
  }

  @override
  void setScale(double nextScale, {Offset focalWorld = Offset.zero}) {
    final clamped = nextScale.clamp(_owner.minZoom, _owner.maxZoom).toDouble();
    final current = scale;
    if ((clamped - current).abs() < 1e-6) return;

    _owner._cancelCameraAnimation();
    final ratio = clamped / current;
    final next = _owner._transform.clone()
      ..translate(focalWorld.dx, focalWorld.dy)
      ..scale(ratio, ratio)
      ..translate(-focalWorld.dx, -focalWorld.dy);
    _owner._setTransformInternal(next, notify: true, takeOwnership: true);
  }

  @override
  void stepScale(int steps, {double increment = 0.05, Offset? focalScreen}) {
    if (!increment.isFinite || increment <= 0) {
      throw ArgumentError.value(
        increment,
        'increment',
        'Must be finite and greater than zero.',
      );
    }
    if (focalScreen != null &&
        (!focalScreen.dx.isFinite || !focalScreen.dy.isFinite)) {
      throw ArgumentError.value(
        focalScreen,
        'focalScreen',
        'Must contain finite coordinates.',
      );
    }
    if (steps == 0) return;

    const gridEpsilon = 1e-9;
    final gridPosition = scale / increment;
    final startingGrid = steps > 0
        ? (gridPosition + gridEpsilon).floor()
        : (gridPosition - gridEpsilon).ceil();
    final nextScale = (startingGrid + steps) * increment;
    final viewport = viewportSize;
    final effectiveFocalScreen =
        focalScreen ??
        (_isUsableViewport(viewport)
            ? Offset(viewport.width / 2, viewport.height / 2)
            : Offset.zero);
    setScale(nextScale, focalWorld: screenToWorld(effectiveFocalScreen));
  }

  @override
  Offset deltaScreenToWorld(Offset screenDelta) {
    return _owner._deltaScreenToWorld(screenDelta);
  }

  @override
  Offset screenToWorld(Offset screenPoint) {
    return _owner._screenToWorld(screenPoint);
  }

  @override
  Offset worldToScreen(Offset worldPoint) {
    return _owner._worldToScreen(worldPoint);
  }

  @override
  Rect getVisibleWorldRect(Size viewportSize) {
    return _owner._getVisibleWorldRect(viewportSize);
  }
}

class CanvasItemController implements CanvasItemsApi {
  final CanvasController _owner;

  const CanvasItemController._(this._owner);

  @override
  CanvasKitItemDiagnostics? getDiagnostics(String itemId) {
    return _owner._getItemDiagnostics(itemId);
  }

  @override
  Offset? getWorldPosition(String itemId) {
    return getDiagnostics(itemId)?.worldPosition;
  }

  @override
  ValueListenable<Offset>? positionListenable(String itemId) {
    return _owner._readItemPositionListenable?.call(itemId);
  }

  @override
  ValueListenable<Size?>? measuredSizeListenable(String itemId) {
    return _owner._readItemMeasuredSizeListenable?.call(itemId);
  }

  @override
  ValueListenable<int> get measurementRevision {
    return _owner._readMeasurementRevision?.call() ??
        _owner._detachedMeasurementRevision;
  }

  @override
  Size? getMeasuredSize(String itemId) {
    return getDiagnostics(itemId)?.measuredSize;
  }

  @override
  Size? getEffectiveSize(String itemId) {
    return getDiagnostics(itemId)?.effectiveSize;
  }

  @override
  Rect? getScreenRect(String itemId) {
    return getDiagnostics(itemId)?.screenRect;
  }

  @override
  bool setWorldPosition(String itemId, Offset worldPosition) {
    return _owner._setItemPosition(itemId, worldPosition);
  }

  @override
  int setWorldPositions(Map<String, Offset> worldPositionsById) {
    if (worldPositionsById.isEmpty) return 0;
    return _owner._setItemPositions(worldPositionsById);
  }

  @override
  bool setTransform(String itemId, Matrix4? transform) {
    return _owner._setItemTransformById(itemId, transform);
  }

  @override
  bool mutateTransform(
    String itemId,
    void Function(Matrix4 transform) mutator,
  ) {
    return _owner._mutateItemTransformById(itemId, mutator);
  }

  @override
  bool clearTransform(String itemId) {
    return _owner._setItemTransformById(itemId, null);
  }

  @override
  bool setDragEnabled(String itemId, bool enabled) {
    return _owner._setItemDragEnabledById(itemId, enabled);
  }

  @override
  bool bringToFront(String itemId) {
    return _owner._bringItemToFrontById(itemId);
  }
}

class CanvasLayerVisibilityController implements CanvasLayersApi {
  final CanvasController _owner;

  const CanvasLayerVisibilityController._(this._owner);

  @override
  int get revision => _owner._layerRevision;

  @override
  bool isVisible(CanvasLayerId layerId) {
    return _owner._isLayerVisible(layerId);
  }

  @override
  void setVisible(CanvasLayerId layerId, bool visible) {
    _owner._setLayerVisible(layerId, visible);
  }

  @override
  void toggleVisible(CanvasLayerId layerId) {
    _owner._toggleLayerVisible(layerId);
  }
}

extension CanvasControllerBinding on CanvasController {
  void setViewportSize(Size size) {
    if (_viewportSize.value == size) return;
    _viewportSize.value = size;
  }

  void attachItemAccessors({
    CanvasKitItemDiagnostics? Function(String id)? readDiagnostics,
    ValueListenable<Offset>? Function(String id)? readPositionListenable,
    ValueListenable<Size?>? Function(String id)? readMeasuredSizeListenable,
    ValueListenable<int> Function()? readMeasurementRevision,
    bool Function(String id, Offset worldPosition)? setWorldPosition,
    int Function(Map<String, Offset> worldPositionsById)? setWorldPositions,
    bool Function(String id, Matrix4? transform)? setTransform,
    bool Function(String id, void Function(Matrix4 transform) mutator)?
    mutateTransform,
    bool Function(String id, bool enabled)? setDragEnabled,
    bool Function(String id)? bringToFront,
    Rect? Function({Iterable<String>? itemIds, double worldPadding})?
    readWorldBounds,
    bool Function(CanvasLayerId layerId)? hasLayerId,
  }) {
    _readItemDiagnostics = readDiagnostics;
    _readItemPositionListenable = readPositionListenable;
    _readItemMeasuredSizeListenable = readMeasuredSizeListenable;
    _readMeasurementRevision = readMeasurementRevision;
    _setItemWorldPosition = setWorldPosition;
    _setItemWorldPositions = setWorldPositions;
    _setItemTransform = setTransform;
    _mutateItemTransform = mutateTransform;
    _setItemDragEnabled = setDragEnabled;
    _bringItemToFront = bringToFront;
    _readItemWorldBounds = readWorldBounds;
    _hasLayerId = hasLayerId;
  }

  void detachItemAccessors() {
    _readItemDiagnostics = null;
    _readItemPositionListenable = null;
    _readItemMeasuredSizeListenable = null;
    _readMeasurementRevision = null;
    _setItemWorldPosition = null;
    _setItemWorldPositions = null;
    _setItemTransform = null;
    _mutateItemTransform = null;
    _setItemDragEnabled = null;
    _bringItemToFront = null;
    _readItemWorldBounds = null;
    _hasLayerId = null;
  }

  void setRenderStats(CanvasKitRenderStats stats) {
    final current = _renderStats.value;
    if (current != null &&
        current.totalItems == stats.totalItems &&
        current.visibleItems == stats.visibleItems &&
        (current.scale - stats.scale).abs() < 1e-9 &&
        current.viewportSize == stats.viewportSize) {
      return;
    }
    _renderStats.value = stats;
  }
}

bool _isUsableViewport(Size viewport) {
  return viewport.width.isFinite &&
      viewport.height.isFinite &&
      viewport.width > 0 &&
      viewport.height > 0;
}

bool _isUsableWorldRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite &&
      rect.width > 0 &&
      rect.height > 0;
}

bool _isUsableAlignment(Alignment alignment) {
  return alignment.x.isFinite && alignment.y.isFinite;
}

bool _isUsablePadding(EdgeInsets padding) {
  return padding.left.isFinite &&
      padding.top.isFinite &&
      padding.right.isFinite &&
      padding.bottom.isFinite &&
      padding.left >= 0 &&
      padding.top >= 0 &&
      padding.right >= 0 &&
      padding.bottom >= 0;
}

void _validateFitZoomLimit(double? value, String name) {
  if (value == null) return;
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name, 'must be finite and greater than 0');
  }
}
