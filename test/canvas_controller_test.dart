import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'package:infinity_canvas/infinity_canvas.dart';

void main() {
  test('world/screen conversion roundtrip stays stable', () {
    final controller = CanvasController(
      initialWorldTopLeft: const Offset(100, -50),
      initialZoom: 2.0,
    );
    addTearDown(controller.dispose);

    final world = const Offset(12.5, -33.25);
    final screen = controller.camera.worldToScreen(world);
    final back = controller.camera.screenToWorld(screen);

    expect(back.dx, closeTo(world.dx, 1e-9));
    expect(back.dy, closeTo(world.dy, 1e-9));
  });

  test('deltaScreenToWorld scales by current zoom', () {
    final controller = CanvasController(initialZoom: 2.5);
    addTearDown(controller.dispose);

    final delta = controller.camera.deltaScreenToWorld(const Offset(25, -10));
    expect(delta.dx, closeTo(10.0, 1e-9));
    expect(delta.dy, closeTo(-4.0, 1e-9));
  });

  test('setScale clamps to minZoom/maxZoom', () {
    final controller = CanvasController(minZoom: 0.5, maxZoom: 2.0);
    addTearDown(controller.dispose);

    controller.camera.setScale(9.0);
    expect(controller.camera.scale, closeTo(2.0, 1e-9));

    controller.camera.setScale(0.1);
    expect(controller.camera.scale, closeTo(0.5, 1e-9));
  });

  test('setScale keeps focal world point fixed on screen', () {
    final controller = CanvasController();
    addTearDown(controller.dispose);

    final focalWorld = const Offset(200, 150);
    final before = controller.camera.worldToScreen(focalWorld);
    controller.camera.setScale(1.8, focalWorld: focalWorld);
    final after = controller.camera.worldToScreen(focalWorld);

    expect(after.dx, closeTo(before.dx, 1e-6));
    expect(after.dy, closeTo(before.dy, 1e-6));
  });

  test('jumpToWorldTopLeft maps target to screen origin', () {
    final controller = CanvasController();
    addTearDown(controller.dispose);

    const target = Offset(340, -220);
    controller.camera.jumpToWorldTopLeft(target, zoom: 1.3);

    final screen = controller.camera.worldToScreen(target);
    expect(screen.dx, closeTo(0, 1e-9));
    expect(screen.dy, closeTo(0, 1e-9));
    expect(controller.camera.scale, closeTo(1.3, 1e-9));
  });

  test('screenToWorld does not throw on singular transform', () {
    final controller = CanvasController();
    addTearDown(controller.dispose);

    controller.camera.setTransform(Matrix4.zero());
    final world = controller.camera.screenToWorld(const Offset(24, -12));

    expect(world, const Offset(24, -12));
  });

  test('constructor rejects invalid zoom range', () {
    expect(
      () => CanvasController(minZoom: 2.0, maxZoom: 1.0),
      throwsA(isA<AssertionError>()),
    );
  });
}
