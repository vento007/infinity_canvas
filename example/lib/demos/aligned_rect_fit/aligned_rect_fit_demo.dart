import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

class AlignedRectFitDemoPage extends StatefulWidget {
  const AlignedRectFitDemoPage({super.key});

  @override
  State<AlignedRectFitDemoPage> createState() => _AlignedRectFitDemoPageState();
}

class _AlignedRectFitDemoPageState extends State<AlignedRectFitDemoPage> {
  static const _paperRect = Rect.fromLTWH(240, 160, 760, 480);
  static const _zoomStep = 0.05;

  late final CanvasController _controller;
  CanvasFitMode _fitMode = CanvasFitMode.width;
  _AlignmentChoice _alignment = _alignmentChoices.first;
  _PaddingChoice _padding = _paddingChoices[1];
  bool _limitFitZoom = true;
  bool _refitOnResize = true;
  bool _viewportUpdateScheduled = false;
  bool _didInitialFit = false;
  double _zoom = 1;
  String _status = 'Waiting for the first viewport layout…';

  @override
  void initState() {
    super.initState();
    _controller = CanvasController(minZoom: 0.25, maxZoom: 2.5);
    _controller.camera.viewportSizeListenable.addListener(
      _handleViewportChanged,
    );
  }

  @override
  void dispose() {
    _controller.camera.viewportSizeListenable.removeListener(
      _handleViewportChanged,
    );
    _controller.dispose();
    super.dispose();
  }

  void _handleViewportChanged() {
    if (_viewportUpdateScheduled) return;
    _viewportUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportUpdateScheduled = false;
      if (!mounted) return;
      setState(() {});
      if (!_didInitialFit || _refitOnResize) {
        _applyFit();
      }
    });
  }

  void _applyFit() {
    final fitted = _controller.camera.fitWorldRectAligned(
      _paperRect,
      fit: _fitMode,
      alignment: _alignment.value,
      screenPadding: _padding.value,
      minZoom: _limitFitZoom ? 0.6 : null,
      maxZoom: _limitFitZoom ? 1.4 : null,
    );
    if (!mounted) return;
    setState(() {
      _didInitialFit = _didInitialFit || fitted;
      _zoom = _controller.camera.scale;
      _status = fitted
          ? '${_fitMode.name} fit · ${_alignment.label} · ${_padding.label}'
          : 'Fit skipped: the viewport is not ready or padding consumes it.';
    });
  }

  void _stepZoom(int steps) {
    final nextZoom =
        ((_controller.camera.scale / _zoomStep).round() + steps) * _zoomStep;
    _controller.camera.setScale(nextZoom, focalWorld: _paperRect.topLeft);
    setState(() {
      _zoom = _controller.camera.scale;
      _status =
          '5% zoom step around the paper top-left (separate from fitting)';
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewport = _controller.camera.viewportSize;
    return Scaffold(
      appBar: AppBar(title: const Text('Aligned Rectangle Fit')),
      body: Column(
        children: [
          _DemoControls(
            fitMode: _fitMode,
            alignment: _alignment,
            padding: _padding,
            limitFitZoom: _limitFitZoom,
            refitOnResize: _refitOnResize,
            zoom: _zoom,
            viewport: viewport,
            status: _status,
            onFitModeChanged: (value) => setState(() => _fitMode = value),
            onAlignmentChanged: (value) {
              setState(() => _alignment = value);
            },
            onPaddingChanged: (value) => setState(() => _padding = value),
            onLimitFitZoomChanged: (value) {
              setState(() => _limitFitZoom = value);
            },
            onRefitOnResizeChanged: (value) {
              setState(() => _refitOnResize = value);
            },
            onApplyFit: _applyFit,
            onZoomOut: () => _stepZoom(-1),
            onZoomIn: () => _stepZoom(1),
          ),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFF07111F),
              child: InfinityCanvas(
                controller: _controller,
                onZoomChanged: (zoom) {
                  if (!mounted) return;
                  setState(() => _zoom = zoom);
                },
                layers: [
                  CanvasLayer.positionedItems(
                    id: 'fit-demo-items',
                    items: [
                      CanvasItem(
                        id: 'fit-paper',
                        worldPosition: _paperRect.topLeft,
                        size: CanvasItemSize.fromSize(_paperRect.size),
                        dragEnabled: false,
                        child: const _PaperSheet(),
                      ),
                      CanvasItem(
                        id: 'world-origin',
                        worldPosition: Offset(-12, -12),
                        size: CanvasItemSize.fixed(24, 24),
                        dragEnabled: false,
                        child: const _OriginMarker(),
                      ),
                    ],
                  ),
                  CanvasLayer.overlay(
                    id: 'padded-viewport-guide',
                    builder: (context, transform, controller) => IgnorePointer(
                      child: CustomPaint(
                        painter: _PaddedViewportPainter(_padding.value),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoControls extends StatelessWidget {
  final CanvasFitMode fitMode;
  final _AlignmentChoice alignment;
  final _PaddingChoice padding;
  final bool limitFitZoom;
  final bool refitOnResize;
  final double zoom;
  final Size viewport;
  final String status;
  final ValueChanged<CanvasFitMode> onFitModeChanged;
  final ValueChanged<_AlignmentChoice> onAlignmentChanged;
  final ValueChanged<_PaddingChoice> onPaddingChanged;
  final ValueChanged<bool> onLimitFitZoomChanged;
  final ValueChanged<bool> onRefitOnResizeChanged;
  final VoidCallback onApplyFit;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;

  const _DemoControls({
    required this.fitMode,
    required this.alignment,
    required this.padding,
    required this.limitFitZoom,
    required this.refitOnResize,
    required this.zoom,
    required this.viewport,
    required this.status,
    required this.onFitModeChanged,
    required this.onAlignmentChanged,
    required this.onPaddingChanged,
    required this.onLimitFitZoomChanged,
    required this.onRefitOnResizeChanged,
    required this.onApplyFit,
    required this.onZoomOut,
    required this.onZoomIn,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0F172A),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ChoiceField<CanvasFitMode>(
                  label: 'Fit mode',
                  value: fitMode,
                  values: CanvasFitMode.values,
                  itemLabel: (value) => value.name,
                  onChanged: onFitModeChanged,
                ),
                _ChoiceField<_AlignmentChoice>(
                  label: 'Alignment',
                  value: alignment,
                  values: _alignmentChoices,
                  itemLabel: (value) => value.label,
                  onChanged: onAlignmentChanged,
                ),
                _ChoiceField<_PaddingChoice>(
                  label: 'Screen padding',
                  value: padding,
                  values: _paddingChoices,
                  itemLabel: (value) => value.label,
                  onChanged: onPaddingChanged,
                ),
                FilterChip(
                  selected: limitFitZoom,
                  label: const Text('Clamp fit to 60–140%'),
                  onSelected: onLimitFitZoomChanged,
                ),
                FilterChip(
                  selected: refitOnResize,
                  label: const Text('Refit on resize'),
                  onSelected: onRefitOnResizeChanged,
                ),
                FilledButton.icon(
                  onPressed: onApplyFit,
                  icon: const Icon(Icons.fit_screen),
                  label: const Text('Apply fit'),
                ),
                IconButton.filledTonal(
                  tooltip: 'Zoom out 5%',
                  onPressed: onZoomOut,
                  icon: const Icon(Icons.remove),
                ),
                IconButton.filledTonal(
                  tooltip: 'Zoom in 5%',
                  onPressed: onZoomIn,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Viewport ${viewport.width.toStringAsFixed(0)} × '
              '${viewport.height.toStringAsFixed(0)} · '
              'zoom ${(zoom * 100).toStringAsFixed(0)}% · $status',
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onChanged;

  const _ChoiceField({
    required this.label,
    required this.value,
    required this.values,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8))),
        const SizedBox(width: 8),
        DropdownButton<T>(
          value: value,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Color(0xFFE2E8F0)),
          underline: const SizedBox.shrink(),
          items: [
            for (final choice in values)
              DropdownMenuItem<T>(
                value: choice,
                child: Text(itemLabel(choice)),
              ),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ],
    );
  }
}

class _PaperSheet extends StatelessWidget {
  const _PaperSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _AlignedRectFitDemoPageState._paperRect.width,
      height: _AlignedRectFitDemoPageState._paperRect.height,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFF0EA5E9), width: 4),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: const Stack(
        children: [
          Center(
            child: Text(
              '760 × 480 world rect',
              style: TextStyle(
                color: Color(0xFF334155),
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Positioned(left: 16, top: 12, child: _CornerLabel('TOP LEFT')),
          Positioned(right: 16, top: 12, child: _CornerLabel('TOP RIGHT')),
          Positioned(left: 16, bottom: 12, child: _CornerLabel('BOTTOM LEFT')),
          Positioned(
            right: 16,
            bottom: 12,
            child: _CornerLabel('BOTTOM RIGHT'),
          ),
        ],
      ),
    );
  }
}

class _CornerLabel extends StatelessWidget {
  final String label;

  const _CornerLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _OriginMarker extends StatelessWidget {
  const _OriginMarker();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFFF43F5E),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '0',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _PaddedViewportPainter extends CustomPainter {
  final EdgeInsets padding;

  const _PaddedViewportPainter(this.padding);

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width - padding.horizontal;
    final height = size.height - padding.vertical;
    if (width <= 0 || height <= 0) return;
    final rect = Rect.fromLTWH(padding.left, padding.top, width, height);
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _PaddedViewportPainter oldDelegate) {
    return oldDelegate.padding != padding;
  }
}

class _AlignmentChoice {
  final String label;
  final Alignment value;

  const _AlignmentChoice(this.label, this.value);
}

const _alignmentChoices = [
  _AlignmentChoice('topLeft', Alignment.topLeft),
  _AlignmentChoice('topCenter', Alignment.topCenter),
  _AlignmentChoice('topRight', Alignment.topRight),
  _AlignmentChoice('centerLeft', Alignment.centerLeft),
  _AlignmentChoice('center', Alignment.center),
  _AlignmentChoice('centerRight', Alignment.centerRight),
  _AlignmentChoice('bottomLeft', Alignment.bottomLeft),
  _AlignmentChoice('bottomCenter', Alignment.bottomCenter),
  _AlignmentChoice('bottomRight', Alignment.bottomRight),
];

class _PaddingChoice {
  final String label;
  final EdgeInsets value;

  const _PaddingChoice(this.label, this.value);
}

const _paddingChoices = [
  _PaddingChoice('none', EdgeInsets.zero),
  _PaddingChoice('16 all', EdgeInsets.all(16)),
  _PaddingChoice(
    '32 horizontal / 12 vertical',
    EdgeInsets.symmetric(horizontal: 32, vertical: 12),
  ),
  _PaddingChoice('asymmetric', EdgeInsets.fromLTRB(64, 24, 16, 48)),
];
