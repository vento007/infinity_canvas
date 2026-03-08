import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

import 'orbital_generator.dart';
import 'orbital_models.dart';
import 'orbital_painters.dart';

enum _OrbitPreset {
  pocket('Pocket Sector', hubs: 12, bodiesPerHub: 14),
  basin('Deep Basin', hubs: 18, bodiesPerHub: 20),
  supercluster('Supercluster', hubs: 26, bodiesPerHub: 28);

  final String label;
  final int hubs;
  final int bodiesPerHub;

  const _OrbitPreset(
    this.label, {
    required this.hubs,
    required this.bodiesPerHub,
  });
}

class OrbitalConstellationDemoPage extends StatefulWidget {
  const OrbitalConstellationDemoPage({super.key});

  @override
  State<OrbitalConstellationDemoPage> createState() =>
      _OrbitalConstellationDemoPageState();
}

class _OrbitalConstellationDemoPageState
    extends State<OrbitalConstellationDemoPage> {
  final CanvasController _controller = CanvasController(
    minZoom: 0.015,
    maxZoom: 4.0,
  );

  final ValueNotifier<_OrbitPreset> _preset = ValueNotifier<_OrbitPreset>(
    _OrbitPreset.basin,
  );
  final ValueNotifier<bool> _running = ValueNotifier<bool>(true);
  final ValueNotifier<double> _zoom = ValueNotifier<double>(1.0);
  final ValueNotifier<String?> _hoveredBodyId = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _selectedBodyId = ValueNotifier<String?>(null);
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  final Map<String, Offset> _framePositions = <String, Offset>{};
  final Map<String, OrbitalBody> _bodyById = <String, OrbitalBody>{};

  Timer? _loop;
  DateTime? _lastFrameAt;
  late OrbitalScene _scene;
  late List<CanvasItem> _bodyItems;
  late List<List<OrbitalBody>> _bodiesByHub;

  int _seed = 20260305;
  bool _cameraFitted = false;
  double _timeSeconds = 0;

  @override
  void initState() {
    super.initState();
    _regenerate(seed: _seed, forcePreset: _preset.value);
    _startLoop();
  }

  @override
  void dispose() {
    _loop?.cancel();
    _preset.dispose();
    _running.dispose();
    _zoom.dispose();
    _hoveredBodyId.dispose();
    _selectedBodyId.dispose();
    _tick.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startLoop() {
    _lastFrameAt = DateTime.now();
    _loop = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      _fitCameraOnce();

      final now = DateTime.now();
      final previous = _lastFrameAt ?? now;
      _lastFrameAt = now;

      var dt =
          now.difference(previous).inMicroseconds /
          Duration.microsecondsPerSecond;
      dt = dt.clamp(0.0, 0.05);

      if (_running.value) {
        _stepBodies(dt);
      }
      _timeSeconds += dt;
      _tick.value = _tick.value + 1;
    });
  }

  void _fitCameraOnce() {
    if (_cameraFitted) return;
    final stats = _controller.camera.renderStats;
    if (stats == null || stats.viewportSize.isEmpty) return;

    final bounds = _scene.bounds;
    final viewW = stats.viewportSize.width;
    final viewH = stats.viewportSize.height;
    final scaleX = viewW / bounds.width;
    final scaleY = viewH / bounds.height;
    final scale = math.min(scaleX, scaleY) * 0.90;

    final tx = (viewW - bounds.width * scale) * 0.5 - bounds.left * scale;
    final ty = (viewH - bounds.height * scale) * 0.5 - bounds.top * scale;

    _controller.camera.setTransform(
      Matrix4.identity()
        ..translate(tx, ty)
        ..scale(scale, scale),
    );
    _zoom.value = scale;
    _cameraFitted = true;
  }

  void _stepBodies(double dt) {
    _framePositions.clear();
    for (final body in _scene.bodies) {
      body.angle += body.angularVelocity * dt;
      if (body.angle > math.pi * 2) body.angle -= math.pi * 2;
      if (body.angle < 0) body.angle += math.pi * 2;

      final hub = _scene.hubs[body.hubIndex];
      body.center =
          hub.center +
          Offset(math.cos(body.angle), math.sin(body.angle)) * body.orbitRadius;

      _framePositions[body.id] =
          body.center - Offset(body.size * 0.5, body.size * 0.5);
    }
    _controller.items.setWorldPositions(_framePositions);
  }

  void _regenerate({int? seed, _OrbitPreset? forcePreset}) {
    _seed = seed ?? _seed;
    final preset = forcePreset ?? _preset.value;
    _scene = generateOrbitalScene(
      seed: _seed,
      hubCount: preset.hubs,
      bodiesPerHub: preset.bodiesPerHub,
    );
    _bodyById
      ..clear()
      ..addEntries(_scene.bodies.map((b) => MapEntry(b.id, b)));
    _bodiesByHub = List<List<OrbitalBody>>.generate(
      _scene.hubs.length,
      (_) => <OrbitalBody>[],
    );
    for (final body in _scene.bodies) {
      _bodiesByHub[body.hubIndex].add(body);
    }
    _bodyItems = _buildBodyItems();
    _selectedBodyId.value = null;
    _hoveredBodyId.value = null;
    _cameraFitted = false;
    _tick.value = _tick.value + 1;
  }

  void _randomizeSeed() {
    final next = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    setState(() {
      _regenerate(seed: next);
    });
  }

  List<CanvasItem> _buildBodyItems() {
    return [
      for (final body in _scene.bodies)
        CanvasItem(
          id: body.id,
          worldPosition: body.center - Offset(body.size * 0.5, body.size * 0.5),
          size: CanvasItemSize.fromSize(Size(body.size, body.size)),
          behavior: const CanvasItemBehavior(
            draggable: false,
            bringToFront: CanvasBringToFrontBehavior.never,
          ),
          dragEnabled: false,
          child: _OrbitalBodyWidget(
            body: body,
            selectedBodyId: _selectedBodyId,
            onHoverChanged: (hovered) {
              _hoveredBodyId.value = hovered ? body.id : null;
            },
            onTap: () {
              _selectedBodyId.value = body.id;
            },
          ),
        ),
    ];
  }

  OrbitalBody? _body(String? id) {
    if (id == null) return null;
    return _bodyById[id];
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B162D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF25406A)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFE5EEFF),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
        ),
      ),
    );
  }

  Widget _hudStrip() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _running,
        _zoom,
        _preset,
        _selectedBodyId,
        _hoveredBodyId,
      ]),
      builder: (context, _) {
        return Container(
          width: double.infinity,
          color: const Color(0xFF040A16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Seed $_seed'),
                const SizedBox(width: 8),
                _chip('Hubs ${_scene.hubs.length}'),
                const SizedBox(width: 8),
                _chip('Bodies ${_scene.bodies.length} widgets'),
                const SizedBox(width: 8),
                _chip('Routes ${_scene.routes.length}'),
                const SizedBox(width: 8),
                _chip('Zoom ${_zoom.value.toStringAsFixed(3)}'),
                const SizedBox(width: 8),
                _chip(
                  _running.value ? 'Simulation running' : 'Simulation paused',
                ),
                const SizedBox(width: 8),
                _chip('Hover ${_hoveredBodyId.value ?? '-'}'),
                const SizedBox(width: 8),
                _chip('Selected ${_selectedBodyId.value ?? '-'}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _inspectorOverlay(CanvasLayerController controller) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _selectedBodyId,
        _hoveredBodyId,
        _zoom,
        controller.renderStatsListenable,
      ]),
      builder: (context, _) {
        final selected = _body(_selectedBodyId.value);
        final hovered = _body(_hoveredBodyId.value);
        final current = selected ?? hovered;

        final stats = controller.renderStats;
        final visible = stats?.visibleItems ?? 0;
        final total = stats?.totalItems ?? _scene.bodies.length;

        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 14, right: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xDC071226),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF32527F)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x88000000),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: Color(0xFFE3EDFF),
                    fontSize: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Orbital Inspector',
                        style: TextStyle(
                          color: Color(0xFF9BE7FF),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Body ${current?.label ?? '-'}'),
                      Text(
                        'Type ${current == null ? '-' : (current.station ? 'Station' : 'Planet')}',
                      ),
                      Text(
                        'Orbit ${current?.orbitRadius.toStringAsFixed(1) ?? '-'}',
                      ),
                      Text('Visible widgets $visible / $total'),
                      Text('Zoom ${_zoom.value.toStringAsFixed(3)}'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orbital Constellation'),
        actions: [
          ValueListenableBuilder<_OrbitPreset>(
            valueListenable: _preset,
            builder: (context, preset, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<_OrbitPreset>(
                    value: preset,
                    borderRadius: BorderRadius.circular(10),
                    onChanged: (next) {
                      if (next == null) return;
                      _preset.value = next;
                      setState(() {
                        _regenerate(forcePreset: next);
                      });
                    },
                    items: [
                      for (final option in _OrbitPreset.values)
                        DropdownMenuItem(
                          value: option,
                          child: Text(option.label),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          FilledButton(
            onPressed: _randomizeSeed,
            child: const Text('New seed'),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<bool>(
            valueListenable: _running,
            builder: (context, running, _) {
              return OutlinedButton(
                onPressed: () => _running.value = !running,
                child: Text(running ? 'Pause' : 'Resume'),
              );
            },
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              _cameraFitted = false;
              _fitCameraOnce();
            },
            child: const Text('Fit map'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _hudStrip(),
          Expanded(
            child: InfinityCanvas(
              controller: _controller,
              enableCulling: true,
              cullPadding: 450,
              onZoomChanged: (value) {
                _zoom.value = value;
                return value;
              },
              layers: [
                CanvasLayer.painter(
                  id: 'orbital-backdrop',
                  painterBuilder: (transform) => OrbitalBackdropPainter(
                    transform: transform,
                    scene: _scene,
                    readTimeSeconds: () => _timeSeconds,
                    repaint: _tick,
                  ),
                ),
                CanvasLayer.painter(
                  id: 'orbital-network',
                  painterBuilder: (transform) => OrbitalNetworkPainter(
                    transform: transform,
                    scene: _scene,
                    bodiesByHub: _bodiesByHub,
                    readTimeSeconds: () => _timeSeconds,
                    repaint: _tick,
                  ),
                ),
                CanvasLayer.positionedItems(
                  id: 'orbital-bodies',
                  items: _bodyItems,
                ),
                CanvasLayer.overlay(
                  id: 'orbital-inspector-overlay',
                  ignorePointer: true,
                  builder: (context, transform, controller) {
                    return _inspectorOverlay(controller);
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

class _OrbitalBodyWidget extends StatefulWidget {
  final OrbitalBody body;
  final ValueListenable<String?> selectedBodyId;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  const _OrbitalBodyWidget({
    required this.body,
    required this.selectedBodyId,
    required this.onHoverChanged,
    required this.onTap,
  });

  @override
  State<_OrbitalBodyWidget> createState() => _OrbitalBodyWidgetState();
}

class _OrbitalBodyWidgetState extends State<_OrbitalBodyWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final body = widget.body;
    return ValueListenableBuilder<String?>(
      valueListenable: widget.selectedBodyId,
      builder: (context, selectedId, _) {
        final selected = selectedId == body.id;
        final glow = selected || _hovered;

        Widget core;
        if (body.station) {
          core = Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0E1B34),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: glow ? const Color(0xFFB7F7FF) : body.color,
                width: glow ? 1.6 : 1.1,
              ),
              boxShadow: glow
                  ? [
                      BoxShadow(
                        color: body.color.withValues(alpha: 0.50),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Container(
                width: body.size * 0.33,
                height: body.size * 0.33,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE7F6FF),
                  boxShadow: [
                    BoxShadow(
                      color: body.color.withValues(alpha: 0.60),
                      blurRadius: 7,
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          core = Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color.lerp(Colors.white, body.color, 0.22)!,
                  body.color,
                  Color.lerp(body.color, Colors.black, 0.38)!,
                ],
                stops: const [0.0, 0.58, 1.0],
              ),
              border: Border.all(
                color: glow ? const Color(0xFFFFF3D4) : Colors.white24,
                width: glow ? 1.3 : 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: body.color.withValues(alpha: glow ? 0.65 : 0.34),
                  blurRadius: glow ? 14 : 8,
                  spreadRadius: glow ? 1.6 : 0,
                ),
              ],
            ),
          );
        }

        if (body.hasRing) {
          core = Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(body.size),
                    border: Border.all(
                      color: body.color.withValues(alpha: glow ? 0.62 : 0.35),
                      width: glow ? 1.3 : 0.9,
                    ),
                  ),
                ),
              ),
              Center(child: core),
            ],
          );
        }

        return Tooltip(
          message: body.label,
          waitDuration: const Duration(milliseconds: 180),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) {
              if (_hovered) return;
              setState(() => _hovered = true);
              widget.onHoverChanged(true);
            },
            onExit: (_) {
              if (!_hovered) return;
              setState(() => _hovered = false);
              widget.onHoverChanged(false);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 120),
                scale: glow ? 1.12 : 1.0,
                child: core,
              ),
            ),
          ),
        );
      },
    );
  }
}
