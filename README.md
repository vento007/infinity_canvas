<div align="center">
  <img src="https://raw.githubusercontent.com/vento007/infinity_canvas/main/media/logo2.png" alt="Infinity Canvas Logo" width="520"/>
</div>

<h1 align="center">High-performance infinite canvas for Flutter</h1>

<p align="center">
  <a href="https://pub.dev/packages/infinity_canvas">
    <img src="https://img.shields.io/pub/v/infinity_canvas.svg" alt="Pub">
  </a>
  <a href="https://github.com/vento007/infinity_canvas">
    <img src="https://img.shields.io/github/stars/vento007/infinity_canvas.svg?style=flat&logo=github&colorB=deeppink&label=stars" alt="Star on Github">
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
  <a href="https://github.com/vento007/infinity_canvas/issues">
    <img src="https://img.shields.io/github/issues/vento007/infinity_canvas.svg" alt="Open Issues">
  </a>
  <a href="https://github.com/vento007/infinity_canvas/pulls">
    <img src="https://img.shields.io/github/issues-pr/vento007/infinity_canvas.svg" alt="Pull Requests">
  </a>
  <a href="https://github.com/vento007/infinity_canvas/graphs/contributors">
    <img src="https://img.shields.io/github/contributors/vento007/infinity_canvas.svg" alt="Contributors">
  </a>
  <img src="https://img.shields.io/github/last-commit/vento007/infinity_canvas.svg" alt="Last Commit">
</p>

---

- Mixed layers: positioned widgets, painter passes, and overlays
- Programmatic camera/item control
- Built for large scenes (node editors, maps, strategy UIs, visual tooling)

<p align="center">
  <img src="https://raw.githubusercontent.com/vento007/infinity_canvas/main/media/node-editor.png" alt="Node editor demo" width="31%" />
  <img src="https://raw.githubusercontent.com/vento007/infinity_canvas/main/media/galaxy-trade-map.png" alt="Galaxy trade map demo" width="31%" />
  <img src="https://raw.githubusercontent.com/vento007/infinity_canvas/main/media/database-editor.png" alt="Database editor demo" width="31%" />
</p>

## Install

```yaml
dependencies:
  infinity_canvas: ^0.11.0
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

### Auto-sized items and reflow

Items default to `CanvasItemSize.auto()`, sizing themselves to their `child`.
When you need to lay them out relative to each other but don't know their sizes
up front (e.g. stacking a column of node-editor cards with variable content),
listen for measured sizes instead of estimating or retrying post-frame:

```dart
// Reflow a column whenever any item's measured size changes.
void layoutColumn(CanvasApi api, List<String> ids, {double x = 0, double gap = 100}) {
  double y = 0;
  final updates = <String, Offset>{};
  for (final id in ids) {
    final size = api.items.getEffectiveSize(id);
    if (size == null) return; // not measured yet — a later signal will retry
    updates[id] = Offset(x, y);
    y += size.height + gap;
  }
  api.items.setWorldPositions(updates);
}

// Fires after each measurement, and getEffectiveSize already returns the new
// size when it does — no post-frame settle loop needed.
controller.items.measurementRevision.addListener(() {
  layoutColumn(controller, ['a', 'b', 'c']);
});
```

Use `controller.items.measuredSizeListenable(id)` instead if you only care about
one item. Both guarantee that `getMeasuredSize`/`getEffectiveSize` already
reflect the new size when the signal fires.

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

// Fit a paper-like rect to viewport width while pinning its top-left corner
// 16 logical pixels inside the canvas.
controller.camera.fitWorldRectAligned(
  paperRect,
  fit: CanvasFitMode.width,
  alignment: Alignment.topLeft,
  screenPadding: const EdgeInsets.all(16),
  minZoom: 0.6,
  maxZoom: 1.4,
);

// Additive, directionally snapped zoom steps around the viewport center.
controller.camera.stepScale(-1); // Zoom out by five percentage points.
controller.camera.stepScale(1);  // Zoom in by five percentage points.
```

`fitWorldRectAligned` computes the zoom and position for initial framing,
reset, or application-controlled resize refitting. To refit after the initial
layout and whenever the canvas size changes, use the widget callback:

```dart
InfinityCanvas(
  controller: controller,
  onViewportSizeChanged: (_) {
    controller.camera.fitWorldRectAligned(
      paperRect,
      fit: CanvasFitMode.width,
      alignment: Alignment.topLeft,
      screenPadding: const EdgeInsets.all(16),
      minZoom: 0.6,
      maxZoom: 1.4,
    );
  },
  layers: layers,
);
```

The callback runs after layout, so camera methods can be called directly. No
viewport listener or post-frame scheduling is needed. Applications still
decide whether resize should refit and potentially replace a user's panned
view. Replacing the canvas controller reports the current viewport size again,
even when the widget size is unchanged, so the new controller can be fitted.

`stepScale` uses an additive grid and snaps in the requested direction. Its
increment is configurable, and an optional local screen focal point can replace
the default viewport center:

```dart
controller.camera.stepScale(1, increment: 0.10);
controller.camera.stepScale(-1, focalScreen: const Offset(100, 80));
```

Exact `viewportSize` and `viewportSizeListenable` state remains available for
advanced integrations that need more than the widget callback.

### Layer types

```dart
InfinityCanvas(
  controller: controller,
  layers: [
    CanvasLayer.painter(
      id: 'bg',
      painterBuilder: (transform, controller) => MyBackgroundPainter(transform),
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

- Aligned Rectangle Fit
- Minimal Items
- Painted Item Widgets
- Node Canvas (Clean)
- Grouped Nodes (Linear)
- Input Smoke
- Docking Windows
- Database Schema Designer
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
- `fitWorldRectAligned(...)`
- `fitAllItems(...)`
- `setScale(...)`
- `stepScale(...)`
- `translateWorld(...)`
- `screenToWorld(...)`
- `worldToScreen(...)`
- `viewportSize` / `viewportSizeListenable`
- `renderStatsListenable`

### `InfinityCanvas`

- `onViewportSizeChanged`: post-layout initial and resize notifications

### `controller.items`

- `getDiagnostics(id)`
- `getWorldPosition(id)`
- `getMeasuredSize(id)` / `getEffectiveSize(id)`
- `positionListenable(id)`
- `measuredSizeListenable(id)`
- `measurementRevision`
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
