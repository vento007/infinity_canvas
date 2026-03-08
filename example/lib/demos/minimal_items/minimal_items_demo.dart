import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

class MinimalItemsDemoPage extends StatefulWidget {
  const MinimalItemsDemoPage({super.key});

  @override
  State<MinimalItemsDemoPage> createState() => _MinimalItemsDemoPageState();
}

class _MinimalItemsDemoPageState extends State<MinimalItemsDemoPage>
    with TickerProviderStateMixin {
  static const _n0 = 'n0';
  static const _n1 = 'n1';
  static const _n2 = 'n2';

  late final CanvasController _controller;
  late final AnimationController _idleController;
  late final AnimationController _hoverController;
  final ValueNotifier<String> _status = ValueNotifier<String>(
    'n0/n2 animate from ticker, n1 animates from hover',
  );

  @override
  void initState() {
    super.initState();
    _controller = CanvasController();

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..addListener(_tickIdle);
    _idleController.repeat();

    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 110),
    )..addListener(_tickHover);
  }

  @override
  void dispose() {
    _idleController.dispose();
    _hoverController.dispose();
    _status.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _tickIdle() {
    final t = _idleController.value * math.pi * 2.0;

    _controller.items.mutateTransform(_n0, (m) {
      m
        ..setIdentity()
        ..translate(0.0, math.sin(t) * -10.0)
        ..rotateZ(math.sin(t) * 0.045);
    });

    _controller.items.mutateTransform(_n2, (m) {
      m
        ..setIdentity()
        ..translate(math.cos(t) * 10.0, math.sin(t * 2.0) * 6.0)
        ..rotateZ(math.cos(t * 3.0) * 0.08)
        ..scale(1.0 + math.sin(t * 2.0) * 0.04);
    });
  }

  void _tickHover() {
    final eased = Curves.easeOut.transform(_hoverController.value);
    _controller.items.mutateTransform(_n1, (m) {
      m
        ..setIdentity()
        ..translate(0.0, -10.0 * eased)
        ..scale(1.0 + 0.07 * eased);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minimal Items Demo')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            color: const Color(0xFF0F172A),
            child: ValueListenableBuilder<String>(
              valueListenable: _status,
              builder: (context, status, _) {
                return Text(
                  status,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: InfinityCanvas(
              controller: _controller,
              layers: [
                CanvasLayer.positionedItems(
                  id: 'items',
                  items: [
                    CanvasItem(
                      id: _n0,
                      worldPosition: const Offset(120, 120),
                      behavior: const CanvasItemBehavior.nodeEditor(),
                      child: const _NodeCard(
                        title: 'n0',
                        subtitle: 'ticker -> setTransform',
                        color: Color(0xFF0B7285),
                      ),
                    ),
                    CanvasItem(
                      id: _n1,
                      worldPosition: const Offset(380, 180),
                      behavior: const CanvasItemBehavior.nodeEditor(),
                      onHoverChanged: (hovered) {
                        _status.value = hovered
                            ? 'n1 hover -> animated matrix'
                            : 'n1 hover end -> identity matrix';
                        if (hovered) {
                          _hoverController.forward();
                        } else {
                          _hoverController.reverse();
                        }
                      },
                      child: const _NodeCard(
                        title: 'n1',
                        subtitle: 'hover -> setTransform',
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                    CanvasItem(
                      id: _n2,
                      worldPosition: const Offset(660, 120),
                      behavior: const CanvasItemBehavior.nodeEditor(),
                      child: const _NodeCard(
                        title: 'n2',
                        subtitle: 'ticker -> translate/rotate/scale',
                        color: Color(0xFFC2410C),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _NodeCard({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.24),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          const Text(
            'drag me',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
