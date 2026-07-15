## 0.11.0

**New features**

- Added `CanvasCameraApi.fitWorldRectAligned(...)` with contain, width, and
  height fit modes; configurable alignment; logical-pixel screen padding; and
  optional per-call zoom limits.
- Added exact `viewportSize` and `viewportSizeListenable` camera state for
  deterministic camera layout and resize handling without relying on throttled
  render diagnostics.
- Added `InfinityCanvas.onViewportSizeChanged`, delivered after layout for the
  initial viewport and later resizes, so callers can refit without manually
  managing listeners or post-frame callbacks.
- Added configurable `CanvasCameraApi.stepScale(...)` with directional grid
  snapping, controller zoom clamping, and viewport-center focus by default.
- Direct camera transform commands now supersede an active camera animation,
  preventing a later animation frame from overwriting a manual zoom or fit.
- Added an interactive Aligned Rectangle Fit example covering fit modes,
  alignments, padding presets, zoom clamps, resize refitting, and separate 5%
  zoom steps.

**Breaking changes**

- Added members to `CanvasCameraApi`. This is additive for API consumers but
  requires third-party implementations of the interface to add the new fit,
  viewport, and scale-stepping members.

## 0.10.0

**New features**

- Auto-measured item sizes now emit change signals on `CanvasItemsApi`
  (`controller.items`), so consumers can reflow layouts (e.g. stacking a column
  of unknown-height nodes) without post-frame retry/settle loops:

  - `ValueListenable<Size?>? measuredSizeListenable(String itemId)` — per-item;
    value is `null` until first layout, then fires on each measured-size change.
  - `ValueListenable<int> get measurementRevision` — increments whenever any
    item's measured size changes; convenient for reflowing a group from one
    listener.

  Guarantee: when either signal fires, `getMeasuredSize`/`getEffectiveSize`
  already return the new size (no stale one-frame lag).

**Breaking changes**

- Added the two members above to the `CanvasItemsApi` interface. This is
  additive for code that only *uses* `controller.items`, but a compile-time
  break for any code that *implements* `CanvasItemsApi` (or `CanvasApi`).

  Migrate: implementers must add `measuredSizeListenable` and
  `measurementRevision` to their implementation.

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
