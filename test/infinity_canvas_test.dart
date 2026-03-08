import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:infinity_canvas/infinity_canvas.dart';
import 'package:infinity_canvas/src/item_store.dart';

void main() {
  const testLayerId = 'layer-a';

  CanvasItem item(String id) {
    return CanvasItem(
      id: id,
      worldPosition: Offset.zero,
      child: const SizedBox.shrink(),
    );
  }

  test(
    'orderedItemsForLayer is cached across sync with unchanged structure',
    () {
      final store = CanvasItemStore(frontOrderingEnabled: true);
      final a = item('a');
      final b = item('b');
      final c = item('c');
      final items = <CanvasItem>[a, b, c];

      store.syncForItems(
        items: items,
        layerIds: const <String>[testLayerId],
        onAnyItemPositionChanged: () {},
      );
      store.bringToFront('c');

      final first = store.orderedItemsForLayer(
        layerId: testLayerId,
        items: items,
      );
      final firstIds = first.map((e) => e.id).toList(growable: false);
      expect(firstIds, equals(<String>['a', 'b', 'c']));

      store.syncForItems(
        items: items,
        layerIds: const <String>[testLayerId],
        onAnyItemPositionChanged: () {},
      );
      final second = store.orderedItemsForLayer(
        layerId: testLayerId,
        items: items,
      );
      final secondIds = second.map((e) => e.id).toList(growable: false);
      expect(secondIds, equals(<String>['a', 'b', 'c']));
      expect(identical(first, second), isTrue);
    },
  );

  test('reorder on same list instance invalidates ordered cache', () {
    final store = CanvasItemStore(frontOrderingEnabled: true);
    final a = item('a');
    final b = item('b');
    final c = item('c');
    final items = <CanvasItem>[a, b, c];

    store.syncForItems(
      items: items,
      layerIds: const <String>[testLayerId],
      onAnyItemPositionChanged: () {},
    );
    store.bringToFront('c');
    final before = store.orderedItemsForLayer(
      layerId: testLayerId,
      items: items,
    );
    expect(
      before.map((e) => e.id).toList(growable: false),
      equals(<String>['a', 'b', 'c']),
    );

    // Mutate the same list object in place (common in app code).
    items
      ..clear()
      ..addAll(<CanvasItem>[b, a, c]);

    store.syncForItems(
      items: items,
      layerIds: const <String>[testLayerId],
      onAnyItemPositionChanged: () {},
    );
    final after = store.orderedItemsForLayer(
      layerId: testLayerId,
      items: items,
    );

    expect(
      after.map((e) => e.id).toList(growable: false),
      equals(<String>['b', 'a', 'c']),
    );
    expect(identical(before, after), isFalse);
  });

  test('bringToFront twice invalidates cached ordering each time', () {
    final store = CanvasItemStore(frontOrderingEnabled: true);
    final a = item('a');
    final b = item('b');
    final c = item('c');
    final items = <CanvasItem>[a, b, c];

    store.syncForItems(
      items: items,
      layerIds: const <String>[testLayerId],
      onAnyItemPositionChanged: () {},
    );

    store.bringToFront('a');
    final first = store.orderedItemsForLayer(
      layerId: testLayerId,
      items: items,
    );
    expect(
      first.map((e) => e.id).toList(growable: false),
      equals(<String>['b', 'c', 'a']),
    );

    store.bringToFront('b');
    final second = store.orderedItemsForLayer(
      layerId: testLayerId,
      items: items,
    );
    expect(
      second.map((e) => e.id).toList(growable: false),
      equals(<String>['c', 'a', 'b']),
    );
    expect(identical(first, second), isFalse);
  });

  test('item transform is stored per item without structural rebuild path', () {
    final store = CanvasItemStore(frontOrderingEnabled: true);
    final a = item('a');

    store.syncForItems(
      items: <CanvasItem>[a],
      layerIds: const <String>[testLayerId],
      onAnyItemPositionChanged: () {},
    );

    final listenable = store.transformListenableFor('a');
    expect(listenable, isNotNull);
    expect(listenable!.value, isNull);

    final transform = Matrix4.identity()
      ..translate(12.0, -6.0)
      ..rotateZ(0.2);

    expect(store.setTransform('a', transform), isTrue);
    expect(listenable.value, isNotNull);
    expect(listenable.value!.storage, equals(transform.storage));

    expect(store.setTransform('a', null), isTrue);
    expect(listenable.value, isNull);
  });

  test('item transform can be mutated in place', () {
    final store = CanvasItemStore(frontOrderingEnabled: true);
    final a = item('a');

    store.syncForItems(
      items: <CanvasItem>[a],
      layerIds: const <String>[testLayerId],
      onAnyItemPositionChanged: () {},
    );

    final listenable = store.transformListenableFor('a');
    expect(listenable, isNotNull);

    store.mutateTransform('a', (m) {
      m
        ..setIdentity()
        ..translate(5.0, -3.0)
        ..rotateZ(0.12);
    });

    final value = listenable!.value;
    expect(value, isNotNull);
    expect(value!.storage[12], closeTo(5.0, 1e-9));
    expect(value.storage[13], closeTo(-3.0, 1e-9));
  });
}
