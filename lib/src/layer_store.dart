import 'dart:collection';

import 'models.dart';

class CanvasLayerStore {
  List<CanvasLayer> _layers = const <CanvasLayer>[];
  List<CanvasPositionedItemsLayer> _itemLayers =
      const <CanvasPositionedItemsLayer>[];
  List<CanvasItem> _allItems = const <CanvasItem>[];
  Map<String, CanvasItem> _itemsById = const <String, CanvasItem>{};

  CanvasLayerStore(List<CanvasLayer> layers) {
    replaceLayers(layers);
  }

  static bool hasUniqueLayerIds(List<CanvasLayer> layers) {
    final ids = <CanvasLayerId>{};
    for (final layer in layers) {
      if (!ids.add(layer.id)) return false;
    }
    return true;
  }

  static bool hasUniqueItemIds(List<CanvasLayer> layers) {
    final ids = <String>{};
    for (final layer in layers) {
      if (layer is! CanvasPositionedItemsLayer) continue;
      for (final item in layer.items) {
        if (!ids.add(item.id)) return false;
      }
    }
    return true;
  }

  void replaceLayers(List<CanvasLayer> layers) {
    final itemLayers = <CanvasPositionedItemsLayer>[];
    final allItems = <CanvasItem>[];
    final itemsById = <String, CanvasItem>{};

    for (final layer in layers) {
      if (layer is CanvasPositionedItemsLayer) {
        itemLayers.add(layer);
        for (final item in layer.items) {
          allItems.add(item);
          itemsById[item.id] = item;
        }
      }
    }

    _layers = List<CanvasLayer>.unmodifiable(layers);
    _itemLayers = List<CanvasPositionedItemsLayer>.unmodifiable(itemLayers);
    _allItems = List<CanvasItem>.unmodifiable(allItems);
    _itemsById = UnmodifiableMapView<String, CanvasItem>(itemsById);
  }

  Iterable<CanvasLayer> visibleLayers(
    bool Function(CanvasLayerId layerId) isVisible,
  ) sync* {
    for (final layer in _layers) {
      if (isVisible(layer.id)) {
        yield layer;
      }
    }
  }

  List<CanvasPositionedItemsLayer> get itemLayers => _itemLayers;

  List<CanvasItem> get allItems => _allItems;

  int get totalItemCount => _allItems.length;

  bool hasLayerId(CanvasLayerId id) => _layers.any((layer) => layer.id == id);

  CanvasItem? itemById(String id) => _itemsById[id];
}
