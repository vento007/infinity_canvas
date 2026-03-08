import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

class PaintedItemWidgetsDemoPage extends StatefulWidget {
  const PaintedItemWidgetsDemoPage({super.key});

  @override
  State<PaintedItemWidgetsDemoPage> createState() =>
      _PaintedItemWidgetsDemoPageState();
}

class _PaintedItemWidgetsDemoPageState
    extends State<PaintedItemWidgetsDemoPage> {
  late final CanvasController _controller;
  final List<_PaintedNode> _nodes = <_PaintedNode>[];
  int _nextId = 0;
  bool _dragEnabled = true;

  @override
  void initState() {
    super.initState();
    _controller = CanvasController();
    _spawnAt(const Offset(120, 100));
    _spawnAt(const Offset(360, 180));
    _spawnAt(const Offset(600, 120));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spawnAt(Offset world) {
    final id = 'p${_nextId++}';
    _nodes.add(_PaintedNode(id: id, worldPosition: world));
  }

  void _spawnOne() {
    setState(() {
      final index = _nodes.length;
      _spawnAt(Offset(160 + (index % 6) * 190, 120 + ((index ~/ 6) % 5) * 130));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painted Item Widgets'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _dragEnabled = !_dragEnabled);
              for (final node in _nodes) {
                _controller.items.setDragEnabled(node.id, _dragEnabled);
              }
            },
            child: Text(_dragEnabled ? 'Drag: on' : 'Drag: off'),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _spawnOne, child: const Text('Spawn +1')),
          const SizedBox(width: 12),
        ],
      ),
      body: InfinityCanvas(
        controller: _controller,
        layers: [
          CanvasLayer.positionedItems(
            id: 'painted-item-widgets',
            items: [
              for (final node in _nodes)
                CanvasItem(
                  id: node.id,
                  worldPosition: node.worldPosition,
                  dragEnabled: _dragEnabled,
                  behavior: CanvasItemBehavior(
                    draggable: true,
                    bringToFront: CanvasBringToFrontBehavior.onTapOrDragStart,
                  ),
                  child: _PaintedNodeWidget(label: node.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaintedNode {
  final String id;
  final Offset worldPosition;

  const _PaintedNode({required this.id, required this.worldPosition});
}

class _PaintedNodeWidget extends StatefulWidget {
  final String label;

  const _PaintedNodeWidget({required this.label});

  @override
  State<_PaintedNodeWidget> createState() => _PaintedNodeWidgetState();
}

class _PaintedNodeWidgetState extends State<_PaintedNodeWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        width: 170,
        height: 96,
        child: CustomPaint(
          painter: _PaintedNodePainter(hovered: _hovered),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaintedNodePainter extends CustomPainter {
  final bool hovered;

  const _PaintedNodePainter({required this.hovered});

  @override
  void paint(Canvas canvas, Size size) {
    final card = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    canvas.drawRRect(
      card.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );
    canvas.drawRRect(card, Paint()..color = const Color(0xFF135D66));
    canvas.drawRRect(
      card,
      Paint()
        ..color = hovered ? const Color(0xFFFFC857) : Colors.white38
        ..style = PaintingStyle.stroke
        ..strokeWidth = hovered ? 2.6 : 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _PaintedNodePainter oldDelegate) {
    return oldDelegate.hovered != hovered;
  }
}
