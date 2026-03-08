import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';

import 'matrix_utils.dart';
import 'models.dart';

class CanvasItemStore {
  bool _frontOrderingEnabled;

  final Map<String, Size> _measuredSizes = <String, Size>{};
  final Map<String, int> _frontOrder = <String, int>{};
  final Map<String, ValueNotifier<Offset>> _positionNotifiers =
      <String, ValueNotifier<Offset>>{};
  final Map<String, ValueNotifier<bool>> _dragEnabledNotifiers =
      <String, ValueNotifier<bool>>{};
  final Map<String, _TransformListenable> _transformNotifiers =
      <String, _TransformListenable>{};
  final Map<String, VoidCallback> _positionListeners = <String, VoidCallback>{};
  final Map<String, _OrderedLayerCache> _orderedLayerCache =
      <String, _OrderedLayerCache>{};
  VoidCallback? _onAnyItemPositionChanged;
  bool _suppressPositionNotifications = false;
  bool _positionChangedWhileSuppressed = false;

  // Cache invalidation stamps for orderedItemsForLayer().
  // - _frontOrderRevision changes when bring-to-front ordering changes.
  // - _itemsRevision changes when syncForItems detects structural changes.
  int _frontCounter = 0;
  int _frontOrderRevision = 0;
  int _itemsRevision = 0;
  // Fingerprint of the latest synced item id sequence.
  // Used to detect reorder/count changes even when the layer list instance
  // itself is reused and mutated in place by caller code.
  int _lastItemsSequenceHash = 0;
  int _lastItemCount = -1;

  CanvasItemStore({required bool frontOrderingEnabled})
    : _frontOrderingEnabled = frontOrderingEnabled;

  void setFrontOrderingEnabled(bool enabled) {
    if (_frontOrderingEnabled == enabled) return;
    _frontOrderingEnabled = enabled;
    _frontOrderRevision++;
    _orderedLayerCache.clear();
  }

  void dispose() {
    _detachAllPositionListeners();
  }

  void syncForItems({
    required Iterable<CanvasItem> items,
    required Iterable<String> layerIds,
    required VoidCallback onAnyItemPositionChanged,
  }) {
    _onAnyItemPositionChanged = onAnyItemPositionChanged;
    var structureChanged = false;
    var sequenceHash = 17;
    var itemCount = 0;
    final seenIds = <String>{};
    for (final item in items) {
      itemCount++;
      sequenceHash = Object.hash(sequenceHash, item.id);
      seenIds.add(item.id);
      if (!_positionNotifiers.containsKey(item.id)) {
        final notifier = ValueNotifier<Offset>(item.worldPosition);
        void listener() {
          if (_suppressPositionNotifications) {
            _positionChangedWhileSuppressed = true;
            return;
          }
          _onAnyItemPositionChanged?.call();
        }

        notifier.addListener(listener);
        _positionNotifiers[item.id] = notifier;
        _positionListeners[item.id] = listener;
        structureChanged = true;
      }
      if (!_dragEnabledNotifiers.containsKey(item.id)) {
        _dragEnabledNotifiers[item.id] = ValueNotifier<bool>(item.dragEnabled);
      }
      if (!_transformNotifiers.containsKey(item.id)) {
        _transformNotifiers[item.id] = _TransformListenable();
      }
    }

    final staleIds = _positionNotifiers.keys
        .where((id) => !seenIds.contains(id))
        .toList(growable: false);
    for (final id in staleIds) {
      final notifier = _positionNotifiers.remove(id);
      final listener = _positionListeners.remove(id);
      if (notifier != null && listener != null) {
        notifier.removeListener(listener);
      }
      notifier?.dispose();
      _dragEnabledNotifiers.remove(id)?.dispose();
      _transformNotifiers.remove(id)?.dispose();
    }
    if (staleIds.isNotEmpty) {
      structureChanged = true;
    }

    final activeLayerIds = layerIds.toSet();
    _orderedLayerCache.removeWhere(
      (layerId, _) => !activeLayerIds.contains(layerId),
    );

    _measuredSizes.removeWhere((id, _) => !seenIds.contains(id));
    final before = _frontOrder.length;
    _frontOrder.removeWhere((id, _) => !seenIds.contains(id));
    if (_frontOrder.length != before) {
      _frontOrderRevision++;
      structureChanged = true;
    }

    if (_lastItemsSequenceHash != sequenceHash || _lastItemCount != itemCount) {
      _lastItemsSequenceHash = sequenceHash;
      _lastItemCount = itemCount;
      structureChanged = true;
    }

    if (structureChanged) {
      _itemsRevision++;
      _orderedLayerCache.clear();
    }
  }

  bool updateMeasuredSize(String id, Size size, {double epsilon = 0.5}) {
    if (size.isEmpty) return false;
    final previous = _measuredSizes[id];
    if (previous != null &&
        (previous.width - size.width).abs() < epsilon &&
        (previous.height - size.height).abs() < epsilon) {
      return false;
    }
    _measuredSizes[id] = size;
    return true;
  }

  Size? measuredSizeFor(String id) => _measuredSizes[id];

  Offset? worldPositionFor(String id) => _positionNotifiers[id]?.value;

  ValueListenable<Offset>? positionListenableFor(String id) {
    return _positionNotifiers[id];
  }

  bool setWorldPosition(String id, Offset worldPosition) {
    final notifier = _positionNotifiers[id];
    if (notifier == null) return false;
    if (notifier.value != worldPosition) {
      notifier.value = worldPosition;
    }
    return true;
  }

  int setWorldPositions(Map<String, Offset> worldPositionsById) {
    if (worldPositionsById.isEmpty) return 0;
    _suppressPositionNotifications = true;
    var updated = 0;
    try {
      for (final entry in worldPositionsById.entries) {
        if (setWorldPosition(entry.key, entry.value)) {
          updated++;
        }
      }
    } finally {
      _suppressPositionNotifications = false;
      if (_positionChangedWhileSuppressed) {
        _positionChangedWhileSuppressed = false;
        _onAnyItemPositionChanged?.call();
      }
    }
    return updated;
  }

  bool setDragEnabled(String id, bool enabled) {
    final notifier = _dragEnabledNotifiers[id];
    if (notifier == null) return false;
    if (notifier.value != enabled) {
      notifier.value = enabled;
    }
    return true;
  }

  ValueListenable<bool>? dragEnabledListenableFor(String id) {
    return _dragEnabledNotifiers[id];
  }

  bool isDragEnabled(String id) => _dragEnabledNotifiers[id]?.value ?? true;

  bool setTransform(String id, Matrix4? transform) {
    final notifier = _transformNotifiers[id];
    if (notifier == null) return false;
    return notifier.setValue(transform, equals: matrixApproxEquals);
  }

  bool mutateTransform(String id, void Function(Matrix4 transform) mutator) {
    final notifier = _transformNotifiers[id];
    if (notifier == null) return false;
    notifier.mutate(mutator);
    return true;
  }

  ValueListenable<Matrix4?>? transformListenableFor(String id) {
    return _transformNotifiers[id];
  }

  Matrix4? transformFor(String id) => _transformNotifiers[id]?.value;

  Size? baseSizeFor(CanvasItem item) {
    return item.size.estimatedSize ?? _measuredSizes[item.id];
  }

  bool bringToFront(String itemId) {
    if (!_frontOrderingEnabled) return false;
    _frontOrder[itemId] = ++_frontCounter;
    _frontOrderRevision++;
    _orderedLayerCache.clear();
    return true;
  }

  List<CanvasItem> orderedItemsForLayer({
    required String layerId,
    required List<CanvasItem> items,
  }) {
    if (!_frontOrderingEnabled) return items;
    if (items.length <= 1 || _frontOrder.isEmpty) {
      return items;
    }

    final cached = _orderedLayerCache[layerId];
    if (cached != null &&
        cached.frontOrderRevision == _frontOrderRevision &&
        cached.itemsRevision == _itemsRevision &&
        cached.itemCount == items.length) {
      return cached.orderedItems;
    }

    final baseIndexById = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      baseIndexById[items[i].id] = i;
    }

    final ordered = List<CanvasItem>.from(items);
    ordered.sort((a, b) {
      final zA = _frontOrder[a.id] ?? 0;
      final zB = _frontOrder[b.id] ?? 0;
      if (zA != zB) return zA.compareTo(zB);
      return baseIndexById[a.id]!.compareTo(baseIndexById[b.id]!);
    });
    _orderedLayerCache[layerId] = _OrderedLayerCache(
      orderedItems: ordered,
      frontOrderRevision: _frontOrderRevision,
      itemsRevision: _itemsRevision,
      itemCount: items.length,
    );
    return ordered;
  }

  void _detachAllPositionListeners() {
    for (final entry in _positionNotifiers.entries) {
      final listener = _positionListeners[entry.key];
      if (listener != null) {
        entry.value.removeListener(listener);
      }
      entry.value.dispose();
    }
    for (final notifier in _dragEnabledNotifiers.values) {
      notifier.dispose();
    }
    for (final notifier in _transformNotifiers.values) {
      notifier.dispose();
    }
    _positionNotifiers.clear();
    _positionListeners.clear();
    _dragEnabledNotifiers.clear();
    _transformNotifiers.clear();
    _orderedLayerCache.clear();
    _onAnyItemPositionChanged = null;
    _suppressPositionNotifications = false;
    _positionChangedWhileSuppressed = false;
  }
}

class _OrderedLayerCache {
  final List<CanvasItem> orderedItems;
  final int frontOrderRevision;
  final int itemsRevision;
  final int itemCount;

  const _OrderedLayerCache({
    required this.orderedItems,
    required this.frontOrderRevision,
    required this.itemsRevision,
    required this.itemCount,
  });
}

class _TransformListenable extends ChangeNotifier
    implements ValueListenable<Matrix4?> {
  Matrix4? _value;

  @override
  Matrix4? get value => _value;

  bool setValue(
    Matrix4? next, {
    required bool Function(Matrix4? a, Matrix4? b) equals,
  }) {
    if (equals(_value, next)) {
      return true;
    }
    _value = next?.clone();
    notifyListeners();
    return true;
  }

  void mutate(void Function(Matrix4 transform) mutator) {
    final existing = _value;
    final transform = existing ?? Matrix4.identity();
    final storage = transform.storage;
    final b0 = storage[0];
    final b1 = storage[1];
    final b2 = storage[2];
    final b3 = storage[3];
    final b4 = storage[4];
    final b5 = storage[5];
    final b6 = storage[6];
    final b7 = storage[7];
    final b8 = storage[8];
    final b9 = storage[9];
    final b10 = storage[10];
    final b11 = storage[11];
    final b12 = storage[12];
    final b13 = storage[13];
    final b14 = storage[14];
    final b15 = storage[15];
    mutator(transform);
    final after = transform.storage;
    final changed =
        (after[0] - b0).abs() > 1e-9 ||
        (after[1] - b1).abs() > 1e-9 ||
        (after[2] - b2).abs() > 1e-9 ||
        (after[3] - b3).abs() > 1e-9 ||
        (after[4] - b4).abs() > 1e-9 ||
        (after[5] - b5).abs() > 1e-9 ||
        (after[6] - b6).abs() > 1e-9 ||
        (after[7] - b7).abs() > 1e-9 ||
        (after[8] - b8).abs() > 1e-9 ||
        (after[9] - b9).abs() > 1e-9 ||
        (after[10] - b10).abs() > 1e-9 ||
        (after[11] - b11).abs() > 1e-9 ||
        (after[12] - b12).abs() > 1e-9 ||
        (after[13] - b13).abs() > 1e-9 ||
        (after[14] - b14).abs() > 1e-9 ||
        (after[15] - b15).abs() > 1e-9;
    if (!changed) return;
    _value = transform;
    notifyListeners();
  }

  void clear() {
    if (_value == null) return;
    _value = null;
    notifyListeners();
  }
}
