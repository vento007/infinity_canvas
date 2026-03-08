<div align="center">
  <img src="https://raw.githubusercontent.com/vento007/canvas_kit/main/infinity_canvas/media/logo.png" alt="Infinity Canvas Logo" width="520"/>
</div>

<h1 align="center">Infinity Canvas</h1>

<p align="center"><em>High-performance infinite canvas for Flutter</em></p>

<p align="center">
  <a href="https://pub.dev/packages/infinity_canvas">
    <img src="https://img.shields.io/pub/v/infinity_canvas.svg" alt="Pub">
  </a>
  <a href="https://github.com/vento007/canvas_kit">
    <img src="https://img.shields.io/github/stars/vento007/canvas_kit.svg?style=flat&logo=github&colorB=deeppink&label=stars" alt="Star on Github">
  </a>
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT">
  </a>
  <a href="https://flutter.dev/">
    <img src="https://img.shields.io/badge/flutter-website-deepskyblue.svg" alt="Flutter Website">
  </a>
  <img src="https://img.shields.io/badge/dart-3.8.1-blue.svg" alt="Dart Version">
  <img src="https://img.shields.io/badge/flutter-1.17.0%2B-blue.svg" alt="Flutter Version">
  <img src="https://img.shields.io/badge/platform-android%20|%20ios%20|%20web%20|%20windows%20|%20macos%20|%20linux-blue.svg" alt="Platform Support">
</p>

---

- Mixed layers: positioned widgets, painter passes, and overlays
- Programmatic camera/item control
- Built for large scenes (node editors, maps, strategy UIs, visual tooling)

## Install

```yaml
dependencies:
  infinity_canvas: ^0.0.1
```

## Quickstart

```dart
import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

class MyCanvasPage extends StatefulWidget {
  const MyCanvasPage({super.key});

  @override
  State<MyCanvasPage> createState() => _MyCanvasPageState();
}

class _MyCanvasPageState extends State<MyCanvasPage> {
  late final CanvasController controller;

  @override
  void initState() {
    super.initState();
    controller = CanvasController(
      initialWorldTopLeft: const Offset(-200, -120),
      initialZoom: 1.1,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InfinityCanvas(
      controller: controller,
      enableCulling: true,
      layers: [
        CanvasLayer.positionedItems(
          id: 'nodes',
          items: [
            CanvasItem(
              id: 'node-1',
              worldPosition: const Offset(120, 100),
              behavior: CanvasItemBehavior.nodeEditor(),
              child: const _Card('Node 1'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  const _Card(this.title);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 92,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x3347A3FF)),
      ),
      child: Text(title, style: const TextStyle(color: Colors.white)),
    );
  }
}
```

## Use Like This

### Move items

```dart
controller.items.setWorldPosition('node-1', const Offset(300, 240));

controller.items.setWorldPositions({
  'node-1': const Offset(300, 240),
  'node-2': const Offset(620, 300),
});
```

To add another item, create another `CanvasItem(...)` with its own `id`,
`worldPosition`, and `child`, then include it in the `items: [...]` list.

### Camera controls

```dart
controller.camera.jumpToWorldTopLeft(const Offset(-500, -300), zoom: 1.2);
controller.camera.jumpToWorldCenter(const Offset(0, 0), zoom: 0.8);

await controller.camera.animateToWorldCenter(
  const Offset(1200, 800),
  zoom: 1.0,
  duration: const Duration(milliseconds: 420),
);

controller.camera.fitAllItems();
```

### Layer types

```dart
InfinityCanvas(
  controller: controller,
  layers: [
    CanvasLayer.painter(
      id: 'bg',
      painterBuilder: (transform) => MyBackgroundPainter(transform),
    ),
    CanvasLayer.positionedItems(id: 'nodes', items: items),
    CanvasLayer.overlay(
      id: 'hud',
      ignorePointer: false,
      builder: (context, transform, controller) => const MyHudWidget(),
    ),
  ],
);
```

### Hover, drag, and item transform

```dart
CanvasItem(
  id: 'node-3',
  worldPosition: const Offset(200, 120),
  onHoverChanged: (hovered) {
    controller.items.setTransform(
      'node-3',
      hovered ? (Matrix4.identity()..scale(1.04)) : null,
    );
  },
  onDragUpdate: (event) {
    // event.worldPosition / event.worldDelta / event.pointerGlobalPosition
  },
  child: const _Card('Hover me'),
);
```

## Performance Defaults

- Use `enableCulling: true` for larger scenes
- Give items a fixed `CanvasItemSize` where possible
- Prefer `CanvasLayer.painter` for very dense static visuals
- Use `controller.items.setWorldPositions(...)` for batch updates
- Keep overlays lean (`CanvasLayer.overlay`) for HUD/interaction logic

## Example Demos

See `example/lib/main.dart`:

- Minimal Items
- Painted Item Widgets
- Node Canvas (Clean)
- Grouped Nodes (Linear)
- Input Smoke
- Docking Windows
- Database Schema Designer
- Tower Defense
- Massive Multi-Widget Art Scene
- Galaxy Trade Map
- Orbital Constellation

## API Appendix (Compact)

### `CanvasController`

- `camera`: transform, pan, zoom, fit, jump, animate
- `items`: read diagnostics + mutate item state
- `layers`: show/hide layers

### `controller.camera`

- `jumpToWorldTopLeft(...)`
- `jumpToWorldCenter(...)`
- `animateToWorldTopLeft(...)`
- `animateToWorldCenter(...)`
- `fitWorldRect(...)`
- `fitAllItems(...)`
- `setScale(...)`
- `translateWorld(...)`
- `screenToWorld(...)`
- `worldToScreen(...)`
- `renderStatsListenable`

### `controller.items`

- `getDiagnostics(id)`
- `getWorldPosition(id)`
- `positionListenable(id)`
- `setWorldPosition(id, offset)`
- `setWorldPositions({id: offset})`
- `setTransform(id, matrixOrNull)`
- `mutateTransform(id, mutator)`
- `clearTransform(id)`
- `setDragEnabled(id, enabled)`
- `bringToFront(id)`

### `CanvasLayer`

- `CanvasLayer.positionedItems(...)`
- `CanvasLayer.painter(...)`
- `CanvasLayer.overlay(...)`

### `CanvasInputBehavior`

- `CanvasInputBehavior.desktop()`
- `CanvasInputBehavior.touch()`
- `CanvasInputBehavior.locked()`
