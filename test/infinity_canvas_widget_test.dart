import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:infinity_canvas/infinity_canvas.dart';

Widget _buildHost({
  required CanvasController controller,
  required List<CanvasLayer> layers,
  CanvasInputBehavior inputBehavior = const CanvasInputBehavior.desktop(),
  bool enableCulling = false,
  Size viewportSize = const Size(800, 600),
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: viewportSize.width,
          height: viewportSize.height,
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

class _NoopPainter extends CustomPainter {
  const _NoopPainter();

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant _NoopPainter oldDelegate) => false;
}

void main() {
  testWidgets('painter layer receives CanvasApi controller', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController(initialZoom: 1.25);
    addTearDown(controller.dispose);

    CanvasApi? receivedController;
    double? receivedScale;
    Offset? receivedOriginScreen;

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        layers: <CanvasLayer>[
          CanvasLayer.painter(
            id: 'paint',
            painterBuilder: (transform, api) {
              receivedController = api;
              receivedScale = api.scale;
              receivedOriginScreen = api.camera.worldToScreen(Offset.zero);
              return const _NoopPainter();
            },
          ),
        ],
      ),
    );
    await tester.pump();

    expect(receivedController, same(controller));
    expect(receivedScale, closeTo(1.25, 1e-9));
    expect(
      receivedOriginScreen,
      equals(controller.camera.worldToScreen(Offset.zero)),
    );
  });

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

  testWidgets('viewport size is exact and tracks layout lifecycle', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController();
    addTearDown(controller.dispose);
    final observed = <Size>[];
    void recordViewport() {
      observed.add(controller.camera.viewportSize);
    }

    controller.camera.viewportSizeListenable.addListener(recordViewport);
    addTearDown(
      () => controller.camera.viewportSizeListenable.removeListener(
        recordViewport,
      ),
    );

    expect(controller.camera.viewportSize, Size.zero);

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        layers: const [
          CanvasLayer.positionedItems(id: 'empty', items: <CanvasItem>[]),
        ],
      ),
    );
    expect(controller.camera.viewportSize, const Size(800, 600));
    expect(observed, [const Size(800, 600)]);

    controller.camera.setScale(1.2);
    await tester.pump();
    expect(observed, [const Size(800, 600)]);

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        viewportSize: const Size(640, 480),
        layers: const [
          CanvasLayer.positionedItems(id: 'empty', items: <CanvasItem>[]),
        ],
      ),
    );
    expect(controller.camera.viewportSize, const Size(640, 480));
    expect(observed, [const Size(800, 600), const Size(640, 480)]);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.camera.viewportSize, Size.zero);
    expect(observed.last, Size.zero);
  });

  testWidgets('aligned fitting calculates contain, width, and height zoom', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController(maxZoom: 10);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        layers: const [
          CanvasLayer.positionedItems(id: 'empty', items: <CanvasItem>[]),
        ],
      ),
    );

    const rect = Rect.fromLTWH(100, 200, 400, 400);
    const expectedZooms = <CanvasFitMode, double>{
      CanvasFitMode.contain: 1.5,
      CanvasFitMode.width: 2,
      CanvasFitMode.height: 1.5,
    };

    for (final entry in expectedZooms.entries) {
      final fitted = controller.camera.fitWorldRectAligned(
        rect,
        fit: entry.key,
      );
      expect(fitted, isTrue, reason: entry.key.name);
      expect(
        controller.camera.scale,
        closeTo(entry.value, 1e-9),
        reason: entry.key.name,
      );
    }
  });

  testWidgets('aligned fitting honors screen padding and alignment', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController(maxZoom: 10);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        layers: const [
          CanvasLayer.positionedItems(id: 'empty', items: <CanvasItem>[]),
        ],
      ),
    );

    const rect = Rect.fromLTWH(100, 200, 400, 200);
    const padding = EdgeInsets.fromLTRB(20, 30, 40, 50);
    expect(
      controller.camera.fitWorldRectAligned(
        rect,
        fit: CanvasFitMode.width,
        alignment: Alignment.topLeft,
        screenPadding: padding,
      ),
      isTrue,
    );
    expect(controller.camera.scale, closeTo(1.85, 1e-9));
    final topLeft = controller.camera.worldToScreen(rect.topLeft);
    final topRight = controller.camera.worldToScreen(rect.topRight);
    expect(topLeft.dx, closeTo(20, 1e-6));
    expect(topLeft.dy, closeTo(30, 1e-6));
    expect(topRight.dx, closeTo(760, 1e-6));

    const clampedRect = Rect.fromLTWH(100, 200, 200, 100);
    final expectedOffsets = <(Alignment, Offset)>[
      (Alignment.topLeft, const Offset(20, 30)),
      (Alignment.center, const Offset(190, 190)),
      (Alignment.bottomRight, const Offset(360, 350)),
    ];
    for (final (alignment, expectedOffset) in expectedOffsets) {
      final fitted = controller.camera.fitWorldRectAligned(
        clampedRect,
        fit: CanvasFitMode.width,
        alignment: alignment,
        screenPadding: padding,
        maxZoom: 2,
      );
      expect(fitted, isTrue, reason: alignment.toString());
      final screenTopLeft = controller.camera.worldToScreen(
        clampedRect.topLeft,
      );
      expect(
        screenTopLeft.dx,
        closeTo(expectedOffset.dx, 1e-6),
        reason: alignment.toString(),
      );
      expect(
        screenTopLeft.dy,
        closeTo(expectedOffset.dy, 1e-6),
        reason: alignment.toString(),
      );
    }
  });

  testWidgets('aligned fitting intersects method and controller zoom limits', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController(minZoom: 0.75, maxZoom: 2);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        layers: const [
          CanvasLayer.positionedItems(id: 'empty', items: <CanvasItem>[]),
        ],
      ),
    );

    expect(
      controller.camera.fitWorldRectAligned(
        const Rect.fromLTWH(0, 0, 4000, 3000),
        minZoom: 1,
      ),
      isTrue,
    );
    expect(controller.camera.scale, closeTo(1, 1e-9));

    expect(
      controller.camera.fitWorldRectAligned(
        const Rect.fromLTWH(0, 0, 20, 20),
        maxZoom: 1.4,
      ),
      isTrue,
    );
    expect(controller.camera.scale, closeTo(1.4, 1e-9));

    expect(
      () => controller.camera.fitWorldRectAligned(
        const Rect.fromLTWH(0, 0, 100, 100),
        minZoom: 1.5,
        maxZoom: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => controller.camera.fitWorldRectAligned(
        const Rect.fromLTWH(0, 0, 100, 100),
        maxZoom: 0.5,
      ),
      throwsArgumentError,
    );
  });

  testWidgets('aligned fitting safely rejects unusable geometry', (
    WidgetTester tester,
  ) async {
    final controller = CanvasController();
    addTearDown(controller.dispose);
    const rect = Rect.fromLTWH(100, 200, 400, 200);

    expect(controller.camera.fitWorldRectAligned(rect), isFalse);
    expect(
      controller.camera.fitWorldRectAligned(Rect.fromLTWH(0, 0, 0, 10)),
      isFalse,
    );

    await tester.pumpWidget(
      _buildHost(
        controller: controller,
        layers: const [
          CanvasLayer.positionedItems(id: 'empty', items: <CanvasItem>[]),
        ],
      ),
    );
    final before = controller.camera.worldToScreen(rect.topLeft);
    expect(
      controller.camera.fitWorldRectAligned(
        rect,
        screenPadding: const EdgeInsets.symmetric(horizontal: 400),
      ),
      isFalse,
    );
    expect(controller.camera.worldToScreen(rect.topLeft), before);
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

  testWidgets(
    'measuredSizeListenable fires after store update with read-back guarantee',
    (WidgetTester tester) async {
      final controller = CanvasController();
      addTearDown(controller.dispose);

      final heightNotifier = ValueNotifier<double>(60);
      addTearDown(heightNotifier.dispose);

      await tester.pumpWidget(
        _buildHost(
          controller: controller,
          layers: <CanvasLayer>[
            CanvasLayer.positionedItems(
              id: 'nodes',
              items: <CanvasItem>[
                CanvasItem(
                  id: 'a',
                  worldPosition: Offset.zero,
                  // Auto size — measured from the child, not declared up front.
                  child: ValueListenableBuilder<double>(
                    valueListenable: heightNotifier,
                    builder: (context, h, _) => SizedBox(width: 100, height: h),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      // Let the measurement post-frame callbacks settle.
      await tester.pump();
      await tester.pump();

      final listenable = controller.items.measuredSizeListenable('a');
      expect(listenable, isNotNull);
      expect(listenable!.value, const Size(100, 60));
      expect(controller.items.getEffectiveSize('a'), const Size(100, 60));

      // Capture what the store reports at the exact moment the signal fires.
      Size? firedValue;
      Size? effectiveAtFire;
      int revisionAtFire = -1;
      final startRevision = controller.items.measurementRevision.value;
      listenable.addListener(() {
        firedValue = listenable.value;
        effectiveAtFire = controller.items.getEffectiveSize('a');
        revisionAtFire = controller.items.measurementRevision.value;
      });

      // Grow the node; measurement is delivered on the following frame.
      heightNotifier.value = 200;
      await tester.pump();
      await tester.pump();

      expect(firedValue, const Size(100, 200));
      // The core guarantee: when the listener fired, getEffectiveSize already
      // returned the new size — no stale one-frame lag to settle-loop around.
      expect(effectiveAtFire, const Size(100, 200));
      expect(revisionAtFire, greaterThan(startRevision));
    },
  );

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
