## 0.9.0

**Breaking changes**

- `CanvasLayerController` renamed to `CanvasApi`.

  Migrate: replace every occurrence of `CanvasLayerController` with `CanvasApi`.

- `CanvasTransformPainterBuilder` now receives a second `CanvasApi controller`
  parameter, consistent with `CanvasTransformWidgetBuilder`.

  Migrate: add `_` or a named parameter to every `painterBuilder` lambda.
  ```dart
  // Before
  painterBuilder: (t) => MyPainter(transform: t)
  // After
  painterBuilder: (t, controller) => MyPainter(transform: t, controller: controller)
  ```

- `CanvasApi` is the single consistent interface passed to both builder callbacks,
  exposing the full canvas API via `.camera`, `.items`, and `.layers`.

## 0.8.1

Initial standalone release of `infinity_canvas`.

- Infinite canvas with layered rendering for positioned items, painters, and overlays
- Controller-driven camera APIs for pan, zoom, jump, animate, and fit operations
- Programmatic item APIs for world position updates, batch updates, transforms, and bring-to-front
- Input behaviors for desktop, touch, and locked interaction modes
- Culling and throttled render stats for larger scenes
- Support for hover, drag, diagnostics, and screen/world coordinate conversion
