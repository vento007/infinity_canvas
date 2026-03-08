import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

class InputSmokeDemoPage extends StatefulWidget {
  const InputSmokeDemoPage({super.key});

  @override
  State<InputSmokeDemoPage> createState() => _InputSmokeDemoPageState();
}

class _InputSmokeDemoPageState extends State<InputSmokeDemoPage> {
  static const double _initialZoom = 0.92;
  static const Offset _initialWorldTopLeft = Offset(-520, -360);

  late final CanvasController _controller;
  late final List<CanvasItem> _items;
  CanvasInputBehavior _inputBehavior = const CanvasInputBehavior.desktop();
  double _zoom = _initialZoom;
  String _lastEvent = 'Try drag, wheel, pinch, and trackpad scroll.';

  @override
  void initState() {
    super.initState();
    _controller = CanvasController(
      initialZoom: _initialZoom,
      initialWorldTopLeft: _initialWorldTopLeft,
    );
    _items = _buildItems();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<CanvasItem> _buildItems() {
    return [
      _buildCard(
        id: 'input-a',
        title: 'Northwest',
        worldPosition: const Offset(-420, -260),
        color: const Color(0xFF0F766E),
      ),
      _buildCard(
        id: 'input-b',
        title: 'Origin',
        worldPosition: const Offset(-40, -20),
        color: const Color(0xFF7C3AED),
      ),
      _buildCard(
        id: 'input-c',
        title: 'Positive',
        worldPosition: const Offset(380, 120),
        color: const Color(0xFFC2410C),
      ),
      _buildCard(
        id: 'input-d',
        title: 'Far East',
        worldPosition: const Offset(760, -160),
        color: const Color(0xFF1D4ED8),
      ),
      _buildCard(
        id: 'input-e',
        title: 'Deep South',
        worldPosition: const Offset(-160, 420),
        color: const Color(0xFFB91C1C),
      ),
    ];
  }

  CanvasItem _buildCard({
    required String id,
    required String title,
    required Offset worldPosition,
    required Color color,
  }) {
    return CanvasItem(
      id: id,
      worldPosition: worldPosition,
      size: CanvasItemSize.fixed(192, 124),
      behavior: const CanvasItemBehavior.nodeEditor(),
      onDragStart: (_) => setState(() => _lastEvent = 'Drag start: $title'),
      onDragEnd: (event) => setState(
        () => _lastEvent =
            'Drag end: $title @ ${event.worldPosition.dx.toStringAsFixed(0)}, ${event.worldPosition.dy.toStringAsFixed(0)}',
      ),
      child: _InputCard(title: title, color: color),
    );
  }

  void _applyPreset(CanvasInputBehavior behavior, String label) {
    setState(() {
      _inputBehavior = behavior;
      _lastEvent = 'Preset: $label';
    });
  }

  void _resetCamera() {
    _controller.camera.jumpToWorldTopLeft(
      _initialWorldTopLeft,
      zoom: _initialZoom,
    );
    setState(() {
      _zoom = _initialZoom;
      _lastEvent = 'Camera reset';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Smoke'),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: _resetCamera,
            child: const Text('Reset Camera'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: const Color(0xFF0F172A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PresetButton(
                      label: 'Desktop',
                      selected:
                          _inputBehavior == const CanvasInputBehavior.desktop(),
                      onTap: () => _applyPreset(
                        const CanvasInputBehavior.desktop(),
                        'Desktop',
                      ),
                    ),
                    _PresetButton(
                      label: 'Touch',
                      selected:
                          _inputBehavior == const CanvasInputBehavior.touch(),
                      onTap: () => _applyPreset(
                        const CanvasInputBehavior.touch(),
                        'Touch',
                      ),
                    ),
                    _PresetButton(
                      label: 'Locked',
                      selected:
                          _inputBehavior == const CanvasInputBehavior.locked(),
                      onTap: () => _applyPreset(
                        const CanvasInputBehavior.locked(),
                        'Locked',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _BehaviorToggle(
                      label: 'Pan',
                      value: _inputBehavior.enablePan,
                      onChanged: (value) => setState(() {
                        _inputBehavior = _inputBehavior.copyWith(
                          enablePan: value,
                        );
                      }),
                    ),
                    _BehaviorToggle(
                      label: 'Wheel Zoom',
                      value: _inputBehavior.enableWheelZoom,
                      onChanged: (value) => setState(() {
                        _inputBehavior = _inputBehavior.copyWith(
                          enableWheelZoom: value,
                        );
                      }),
                    ),
                    _BehaviorToggle(
                      label: 'Pinch Zoom',
                      value: _inputBehavior.enablePinchZoom,
                      onChanged: (value) => setState(() {
                        _inputBehavior = _inputBehavior.copyWith(
                          enablePinchZoom: value,
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Zoom ${_zoom.toStringAsFixed(2)}  |  $_lastEvent',
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: InfinityCanvas(
              controller: _controller,
              inputBehavior: _inputBehavior,
              enableCulling: false,
              onZoomChanged: (z) => setState(() => _zoom = z),
              layers: [
                CanvasLayer.painter(
                  id: 'input-grid',
                  painterBuilder: (transform) =>
                      _InputSmokeGridPainter(transform: transform),
                ),
                CanvasLayer.positionedItems(id: 'input-items', items: _items),
                CanvasLayer.overlay(
                  id: 'input-overlay',
                  listenable: _controller.camera.renderStatsListenable,
                  builder: (context, transform, controller) {
                    final stats = controller.camera.renderStats;
                    final visible = stats?.visibleItems ?? 0;
                    final total = stats?.totalItems ?? 0;
                    return Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC020617),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x33475569)),
                        ),
                        child: Text(
                          'Visible items: $visible / $total\n'
                          'Negative coordinates included. Drag empty space to pan.',
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final String title;
  final Color color;

  const _InputCard({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Drag the card.\nDrag empty space.\nWheel or pinch zoom.',
            style: TextStyle(color: Color(0xFFF8FAFC), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: selected
            ? const Color(0xFF0EA5E9)
            : const Color(0xFF1E293B),
        foregroundColor: selected
            ? const Color(0xFF082F49)
            : const Color(0xFFE2E8F0),
      ),
      child: Text(label),
    );
  }
}

class _BehaviorToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BehaviorToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33475569)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: value, onChanged: onChanged),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InputSmokeGridPainter extends CustomPainter {
  final Matrix4 transform;

  const _InputSmokeGridPainter({required this.transform});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF020617),
    );

    final matrix = transform.storage;
    final scaleX = matrix[0];
    final scaleY = matrix[5];
    final tx = matrix[12];
    final ty = matrix[13];
    final spacing = 120.0;

    final left = (-tx) / scaleX - spacing;
    final top = (-ty) / scaleY - spacing;
    final right = (size.width - tx) / scaleX + spacing;
    final bottom = (size.height - ty) / scaleY + spacing;

    canvas.save();
    canvas.transform(transform.storage);

    final minor = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1 / math.max(scaleX.abs(), 0.0001);
    final major = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 1.6 / math.max(scaleX.abs(), 0.0001);
    final axis = Paint()
      ..color = const Color(0xFF0EA5E9)
      ..strokeWidth = 2.2 / math.max(scaleX.abs(), 0.0001);

    final startX = (left / spacing).floor() * spacing;
    final endX = (right / spacing).ceil() * spacing;
    final startY = (top / spacing).floor() * spacing;
    final endY = (bottom / spacing).ceil() * spacing;

    for (double x = startX; x <= endX; x += spacing) {
      final isMajor = (x / (spacing * 4)).roundToDouble() == x / (spacing * 4);
      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        x == 0 ? axis : (isMajor ? major : minor),
      );
    }
    for (double y = startY; y <= endY; y += spacing) {
      final isMajor = (y / (spacing * 4)).roundToDouble() == y / (spacing * 4);
      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        y == 0 ? axis : (isMajor ? major : minor),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InputSmokeGridPainter oldDelegate) {
    return oldDelegate.transform != transform;
  }
}
