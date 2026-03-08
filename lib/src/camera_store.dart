import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';

class CanvasCameraStore {
  final ValueNotifier<int> tick = ValueNotifier<int>(0);

  Size _viewportSize = Size.zero;
  int _lastTransformRevision = -1;
  int _lastLayerRevision = -1;
  double _lastZoomNotified = 1.0;
  bool _lastLayerChanged = false;

  void dispose() {
    tick.dispose();
  }

  void resetTracking(CanvasController controller) {
    _lastTransformRevision = controller.camera.transformRevision;
    _lastLayerRevision = controller.layers.revision;
    _lastZoomNotified = controller.camera.scale;
  }

  bool handleControllerChanged({
    required CanvasController controller,
    ValueChanged<double>? onZoomChanged,
  }) {
    final transformRevision = controller.camera.transformRevision;
    final layerRevision = controller.layers.revision;
    final transformChanged = transformRevision != _lastTransformRevision;
    final layerChanged = layerRevision != _lastLayerRevision;
    if (!transformChanged && !layerChanged) {
      _lastLayerChanged = false;
      return false;
    }

    _lastTransformRevision = transformRevision;
    _lastLayerRevision = layerRevision;
    tick.value++;

    final zoom = controller.camera.scale;
    if ((zoom - _lastZoomNotified).abs() > 1e-6) {
      _lastZoomNotified = zoom;
      onZoomChanged?.call(zoom);
    }

    _lastLayerChanged = layerChanged;
    return true;
  }

  bool get lastLayerChanged => _lastLayerChanged;

  void markVisualStateChanged() {
    tick.value++;
  }

  bool setViewportSize(Size size) {
    if (_viewportSize == size) return false;
    _viewportSize = size;
    return true;
  }

  Size get viewportSize => _viewportSize;

  bool get hasViewport => !_viewportSize.isEmpty;

  Rect screenVisible({required double cullPadding}) {
    return Rect.fromLTWH(
      0,
      0,
      _viewportSize.width,
      _viewportSize.height,
    ).inflate(cullPadding);
  }

  void publishRenderStats({
    required CanvasController controller,
    required double cullPadding,
    required int totalItems,
    required int Function(Rect screenVisible) visibleItemCount,
  }) {
    if (!hasViewport) return;
    final screenVisibleRect = screenVisible(cullPadding: cullPadding);
    controller.setRenderStats(
      CanvasKitRenderStats(
        totalItems: totalItems,
        visibleItems: visibleItemCount(screenVisibleRect),
        scale: controller.camera.scale,
        viewportSize: _viewportSize,
      ),
    );
  }
}
