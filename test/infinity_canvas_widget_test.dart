import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:infinity_canvas/infinity_canvas.dart';

Widget _buildHost({
  required CanvasController controller,
  required List<CanvasLayer> layers,
  CanvasInputBehavior inputBehavior = const CanvasInputBehavior.desktop(),
  bool enableCulling = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 800,
          height: 600,
          child: InfinityCanvas(
            controller: controller,
            inputBehavior: inputBehavior,
            enableCulling: enableCulling,
            layers: layers,
          ),
        ),
      ),
    ),
  );
}

CanvasItem _item(
  String id,
  Offset worldPosition, {
  double width = 120,
  double height = 80,
  String? label,
  CanvasItemBehavior behavior = const CanvasItemBehavior(
    draggable: true,
    bringToFront: CanvasBringToFrontBehavior.never,
  ),
}) {
  final text = label ?? id.toUpperCase();
  return CanvasItem(
    id: id,
    worldPosition: worldPosition,
    size: CanvasItemSize.fixed(width, height),
    behavior: behavior,
    child: Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(color: Colors.white)),
    ),
  );
}

Offset _canvasGlobal(WidgetTester tester, Offset local) {
  final rect = tester.getRect(find.byType(InfinityCanvas));
  return rect.topLeft + local;
}

Future<void> _sendPointerScroll(
  WidgetTester tester, {
  required Offset globalPosition,
  required Offset scrollDelta,
  PointerDeviceKind kind = PointerDeviceKind.mouse,
}) async {
  tester.binding.handlePointerEvent(
    PointerScrollEvent(
      position: globalPosition,
      scrollDelta: scrollDelta,
      kind: kind,
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('drag works for item in negative world coordinates', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController(
      initialWorldTopLeft: const Offset(-420, -340),
      initialZoom: 1.0,
    );
    addTearDown(controller.dispose);

    final layers = <CanvasLayer>[
      CanvasLayer.positionedItems(
        id: 'nodes',
        items: <CanvasItem>[
          _item('neg', const Offset(-300, -220), label: 'NEG'),
        ],
      ),
    ];

    await tester.pumpWidget(_buildHost(controller: controller, layers: layers));
    await tester.pump();

    final before = controller.items.getWorldPosition('neg');
    expect(before, isNotNull);

    await tester.drag(find.text('NEG'), const Offset(48, 30));
    await tester.pump();

    final after = controller.items.getWorldPosition('neg');
    expect(after, isNotNull);
    expect(after!.dx, closeTo(before!.dx + 48, 0.01));
    expect(after.dy, closeTo(before.dy + 30, 0.01));
  });

  testWidgets(
    'setWorldPositions + setDragEnabled + layer visibility flow works',
    (WidgetTester tester) async {
      final controller = CanvasController();
      addTearDown(controller.dispose);

      final layers = <CanvasLayer>[
        CanvasLayer.positionedItems(
          id: 'nodes',
          items: <CanvasItem>[
            _item('a', const Offset(100, 100), label: 'A'),
            _item('b', const Offset(300, 120), label: 'B'),
          ],
        ),
      ];

      await tester.pumpWidget(
        _buildHost(controller: controller, layers: layers),
      );
      await tester.pump();

      final updated = controller.items.setWorldPositions(<String, Offset>{
        'a': const Offset(220, 200),
        'b': const Offset(460, 240),
      });
      expect(updated, equals(2));

      expect(controller.items.getWorldPosition('a'), const Offset(220, 200));
      expect(controller.items.getWorldPosition('b'), const Offset(460, 240));

      expect(controller.items.setDragEnabled('a', false), isTrue);
      await tester.drag(find.text('A'), const Offset(60, 0));
      await tester.pump();
      expect(controller.items.getWorldPosition('a'), const Offset(220, 200));

      expect(controller.layers.isVisible('nodes'), isTrue);
      controller.layers.toggleVisible('nodes');
      await tester.pump();
      expect(controller.layers.isVisible('nodes'), isFalse);
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsNothing);

      controller.layers.toggleVisible('nodes');
      await tester.pump();
      expect(controller.layers.isVisible('nodes'), isTrue);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    },
  );

  testWidgets('unknown layer id asserts in debug mode', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        layers: <CanvasLayer>[
          CanvasLayer.positionedItems(
            id: 'nodes',
            items: <CanvasItem>[_item('a', const Offset(100, 100), label: 'A')],
          ),
        ],
      ),
    );
    await tester.pump();

    expect(
      () => controller.layers.isVisible('missing'),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => controller.layers.setVisible('missing', false),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => controller.layers.toggleVisible('missing'),
      throwsA(isA<AssertionError>()),
    );
  });

  testWidgets('jumpToWorldCenter and fitAllItems keep targets in view', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController();
    addTearDown(controller.dispose);

    final aRect = const Rect.fromLTWH(1000, 800, 100, 100);
    final bRect = const Rect.fromLTWH(1400, 980, 120, 90);

    final layers = <CanvasLayer>[
      CanvasLayer.positionedItems(
        id: 'nodes',
        items: <CanvasItem>[
          _item('a', aRect.topLeft, width: aRect.width, height: aRect.height),
          _item('b', bRect.topLeft, width: bRect.width, height: bRect.height),
        ],
      ),
    ];

    await tester.pumpWidget(_buildHost(controller: controller, layers: layers));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    final stats = controller.camera.renderStats;
    expect(stats, isNotNull);

    controller.camera.jumpToWorldCenter(const Offset(1200, 900), zoom: 1.0);
    await tester.pump();
    final centerScreen = controller.camera.worldToScreen(
      const Offset(1200, 900),
    );
    final viewportCenter = Offset(
      stats!.viewportSize.width * 0.5,
      stats.viewportSize.height * 0.5,
    );
    expect(centerScreen.dx, closeTo(viewportCenter.dx, 0.01));
    expect(centerScreen.dy, closeTo(viewportCenter.dy, 0.01));

    controller.camera.fitAllItems(worldPadding: 0, paddingFraction: 0);
    await tester.pump();

    final visible = controller.camera.getVisibleWorldRect(stats.viewportSize);
    expect(visible.left <= aRect.left + 0.01, isTrue);
    expect(visible.top <= aRect.top + 0.01, isTrue);
    expect(visible.right >= bRect.right - 0.01, isTrue);
    expect(visible.bottom >= bRect.bottom - 0.01, isTrue);
  });

  testWidgets('animateToWorldTopLeft reaches target transform', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        layers: <CanvasLayer>[
          const CanvasLayer.positionedItems(id: 'nodes', items: <CanvasItem>[]),
        ],
      ),
    );
    await tester.pump();

    final target = const Offset(250, 180);
    final future = controller.camera.animateToWorldTopLeft(
      target,
      zoom: 1.5,
      duration: const Duration(milliseconds: 120),
      curve: Curves.linear,
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await future;

    final screenTopLeft = controller.camera.worldToScreen(target);
    expect(screenTopLeft.dx, closeTo(0, 0.01));
    expect(screenTopLeft.dy, closeTo(0, 0.01));
    expect(controller.camera.scale, closeTo(1.5, 0.001));
  });

  testWidgets('mouse wheel zoom obeys input behavior', (
    WidgetTester tester,
  ) async {
    final centerLocal = const Offset(400, 300);

    final enabledController = CanvasController();
    addTearDown(enabledController.dispose);
    await tester.pumpWidget(
      _buildHost(
        controller: enabledController,
        layers: <CanvasLayer>[
          const CanvasLayer.positionedItems(id: 'nodes', items: <CanvasItem>[]),
        ],
      ),
    );
    await tester.pump();
    final beforeEnabled = enabledController.camera.scale;
    await _sendPointerScroll(
      tester,
      globalPosition: _canvasGlobal(tester, centerLocal),
      scrollDelta: const Offset(0, -40),
      kind: PointerDeviceKind.mouse,
    );
    expect(enabledController.camera.scale, greaterThan(beforeEnabled));

    final disabledController = CanvasController();
    addTearDown(disabledController.dispose);
    await tester.pumpWidget(
      _buildHost(
        controller: disabledController,
        inputBehavior: const CanvasInputBehavior(
          enablePan: true,
          enableWheelZoom: false,
          enablePinchZoom: true,
        ),
        layers: <CanvasLayer>[
          const CanvasLayer.positionedItems(id: 'nodes', items: <CanvasItem>[]),
        ],
      ),
    );
    await tester.pump();
    final beforeDisabled = disabledController.camera.scale;
    await _sendPointerScroll(
      tester,
      globalPosition: _canvasGlobal(tester, centerLocal),
      scrollDelta: const Offset(0, -40),
      kind: PointerDeviceKind.mouse,
    );
    expect(disabledController.camera.scale, closeTo(beforeDisabled, 1e-9));
  });

  testWidgets('trackpad scroll pans canvas even when wheel zoom is disabled', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        inputBehavior: const CanvasInputBehavior(
          enablePan: true,
          enableWheelZoom: false,
          enablePinchZoom: true,
        ),
        layers: <CanvasLayer>[
          const CanvasLayer.positionedItems(id: 'nodes', items: <CanvasItem>[]),
        ],
      ),
    );
    await tester.pump();

    final before = controller.camera.worldToScreen(Offset.zero);
    await _sendPointerScroll(
      tester,
      globalPosition: _canvasGlobal(tester, const Offset(400, 300)),
      scrollDelta: const Offset(0, 36),
      kind: PointerDeviceKind.trackpad,
    );
    final after = controller.camera.worldToScreen(Offset.zero);

    expect(after.dy, closeTo(before.dy - 36, 0.01));
    expect(controller.camera.scale, closeTo(1.0, 1e-9));
  });

  testWidgets('culling hides and shows items as they move into view', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        enableCulling: true,
        layers: <CanvasLayer>[
          CanvasLayer.positionedItems(
            id: 'nodes',
            items: <CanvasItem>[
              _item('far', const Offset(5000, 5000), label: 'FAR'),
            ],
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('FAR'), findsNothing);

    controller.items.setWorldPosition('far', const Offset(120, 120));
    await tester.pump();

    expect(find.text('FAR'), findsOneWidget);
  });

  testWidgets('bringToFront on tap changes overlap drag target', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        layers: <CanvasLayer>[
          CanvasLayer.positionedItems(
            id: 'nodes',
            items: <CanvasItem>[
              _item(
                'a',
                const Offset(80, 80),
                width: 180,
                height: 110,
                label: 'A',
                behavior: const CanvasItemBehavior(
                  draggable: true,
                  bringToFront: CanvasBringToFrontBehavior.onTap,
                ),
              ),
              _item(
                'b',
                const Offset(160, 80),
                width: 180,
                height: 110,
                label: 'B',
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pump();

    final overlap = _canvasGlobal(tester, const Offset(210, 120));
    await tester.dragFrom(overlap, const Offset(40, 0));
    await tester.pump();
    expect(controller.items.getWorldPosition('b')!.dx, greaterThan(160));
    expect(controller.items.getWorldPosition('a')!.dx, closeTo(80, 0.01));

    final uniqueA = _canvasGlobal(tester, const Offset(110, 120));
    await tester.tapAt(uniqueA);
    await tester.pump();

    final aBefore = controller.items.getWorldPosition('a')!;
    final bBefore = controller.items.getWorldPosition('b')!;
    await tester.dragFrom(overlap, const Offset(30, 0));
    await tester.pump();
    final aAfter = controller.items.getWorldPosition('a')!;
    final bAfter = controller.items.getWorldPosition('b')!;
    expect(aAfter.dx, greaterThan(aBefore.dx + 1));
    expect(bAfter.dx, closeTo(bBefore.dx, 0.01));
  });

  testWidgets(
    'bringToFront on drag start updates overlap target for next drag',
    (WidgetTester tester) async {
      final controller = CanvasController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildHost(
          controller: controller,
          layers: <CanvasLayer>[
            CanvasLayer.positionedItems(
              id: 'nodes',
              items: <CanvasItem>[
                _item(
                  'a',
                  const Offset(80, 80),
                  width: 180,
                  height: 110,
                  label: 'A',
                  behavior: const CanvasItemBehavior(
                    draggable: true,
                    bringToFront: CanvasBringToFrontBehavior.onDragStart,
                  ),
                ),
                _item(
                  'b',
                  const Offset(160, 80),
                  width: 180,
                  height: 110,
                  label: 'B',
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pump();

      final uniqueA = _canvasGlobal(tester, const Offset(110, 120));
      await tester.dragFrom(uniqueA, const Offset(40, 0));
      // bringToFront(onDragStart) is scheduled post-frame.
      await tester.pump();
      await tester.pump();

      final overlap = _canvasGlobal(tester, const Offset(210, 120));
      final aBefore = controller.items.getWorldPosition('a')!;
      final bBefore = controller.items.getWorldPosition('b')!;
      await tester.dragFrom(overlap, const Offset(25, 0));
      await tester.pump();

      final aAfter = controller.items.getWorldPosition('a')!;
      final bAfter = controller.items.getWorldPosition('b')!;
      expect(aAfter.dx, greaterThan(aBefore.dx + 1));
      expect(bAfter.dx, closeTo(bBefore.dx, 0.01));
    },
  );

  testWidgets('overlay listenable triggers rebuilds', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController();
    addTearDown(controller.dispose);
    final tick = ValueNotifier<int>(0);
    addTearDown(tick.dispose);

    var builds = 0;

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        layers: <CanvasLayer>[
          CanvasLayer.overlay(
            id: 'overlay',
            ignorePointer: true,
            listenable: tick,
            builder: (context, transform, controller) {
              builds++;
              return const SizedBox.expand();
            },
          ),
        ],
      ),
    );
    await tester.pump();
    final first = builds;
    expect(first, greaterThan(0));

    tick.value++;
    await tester.pump();
    expect(builds, greaterThan(first));
  });

  testWidgets(
    'layer revision increments only on effective visibility changes',
    (WidgetTester tester) async {
      final controller = CanvasController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildHost(
          controller: controller,
          layers: <CanvasLayer>[
            CanvasLayer.positionedItems(
              id: 'nodes',
              items: <CanvasItem>[
                _item('a', const Offset(100, 100), label: 'A'),
              ],
            ),
          ],
        ),
      );
      await tester.pump();

      final r0 = controller.layers.revision;
      controller.layers.setVisible('nodes', false);
      await tester.pump();
      expect(controller.layers.revision, equals(r0 + 1));
      expect(find.text('A'), findsNothing);

      final r1 = controller.layers.revision;
      controller.layers.setVisible('nodes', false);
      await tester.pump();
      expect(controller.layers.revision, equals(r1));

      controller.layers.toggleVisible('nodes');
      await tester.pump();
      expect(controller.layers.revision, equals(r1 + 1));
      expect(find.text('A'), findsOneWidget);
    },
  );

  testWidgets('positionListenable emits only when world position changes', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        layers: <CanvasLayer>[
          CanvasLayer.positionedItems(
            id: 'nodes',
            items: <CanvasItem>[_item('a', const Offset(80, 80), label: 'A')],
          ),
        ],
      ),
    );
    await tester.pump();

    final listenable = controller.items.positionListenable('a');
    expect(listenable, isNotNull);

    var changes = 0;
    void onChange() => changes++;
    listenable!.addListener(onChange);
    addTearDown(() => listenable.removeListener(onChange));

    expect(
      controller.items.setWorldPosition('a', const Offset(120, 110)),
      isTrue,
    );
    expect(changes, equals(1));
    expect(listenable.value, const Offset(120, 110));

    expect(
      controller.items.setWorldPosition('a', const Offset(120, 110)),
      isTrue,
    );
    expect(changes, equals(1));
  });

  testWidgets('diagnostics expose size and screen rect updates', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        layers: <CanvasLayer>[
          CanvasLayer.positionedItems(
            id: 'nodes',
            items: <CanvasItem>[
              _item('a', const Offset(120, 90), width: 140, height: 100),
            ],
          ),
        ],
      ),
    );
    await tester.pump();

    final d0 = controller.items.getDiagnostics('a');
    expect(d0, isNotNull);
    expect(d0!.estimatedSize, const Size(140, 100));
    expect(d0.effectiveSize, const Size(140, 100));
    expect(d0.screenRect, isNotNull);

    final r0 = d0.screenRect!;
    controller.items.setWorldPosition('a', const Offset(160, 120));
    await tester.pump();
    final d1 = controller.items.getDiagnostics('a');
    expect(d1, isNotNull);
    expect(d1!.screenRect, isNotNull);
    final r1 = d1.screenRect!;
    expect(r1.left - r0.left, closeTo(40, 0.01));
    expect(r1.top - r0.top, closeTo(30, 0.01));
  });

  testWidgets('disabling pan blocks drag and trackpad panning', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        layers: <CanvasLayer>[
          const CanvasLayer.positionedItems(id: 'nodes', items: <CanvasItem>[]),
        ],
      ),
    );
    await tester.pump();

    controller.camera.disablePan();
    await tester.pump();

    final before = controller.camera.worldToScreen(Offset.zero);

    await tester.drag(find.byType(InfinityCanvas), const Offset(70, 35));
    await tester.pump();
    await _sendPointerScroll(
      tester,
      globalPosition: _canvasGlobal(tester, const Offset(400, 300)),
      scrollDelta: const Offset(0, 36),
      kind: PointerDeviceKind.trackpad,
    );

    final after = controller.camera.worldToScreen(Offset.zero);
    expect(after.dx, closeTo(before.dx, 0.01));
    expect(after.dy, closeTo(before.dy, 0.01));
  });
}
