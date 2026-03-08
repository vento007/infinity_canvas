import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

import 'mega_components.dart';
import 'mega_engine.dart';
import 'mega_minimap.dart';
import 'mega_painters.dart';

enum _MegaMapPreset {
  large('Large 12x140', lanes: 12, creepsPerLane: 140, segments: 14),
  huge('Huge 16x190', lanes: 16, creepsPerLane: 190, segments: 16),
  extreme('Extreme 22x240', lanes: 22, creepsPerLane: 240, segments: 18);

  final String label;
  final int lanes;
  final int creepsPerLane;
  final int segments;

  const _MegaMapPreset(
    this.label, {
    required this.lanes,
    required this.creepsPerLane,
    required this.segments,
  });
}

enum _CreepRenderMode { painter, widgets }

class MassiveWidgetArtSceneDemoPage extends StatefulWidget {
  const MassiveWidgetArtSceneDemoPage({super.key});

  @override
  State<MassiveWidgetArtSceneDemoPage> createState() =>
      _MassiveWidgetArtSceneDemoPageState();
}

class _MassiveWidgetArtSceneDemoPageState
    extends State<MassiveWidgetArtSceneDemoPage> {
  final CanvasController _controller = CanvasController(
    minZoom: 0.02,
    maxZoom: 3.0,
  );

  late final TdMegaMapEngine _engine;
  final ValueNotifier<_MegaMapPreset> _preset = ValueNotifier<_MegaMapPreset>(
    _MegaMapPreset.large,
  );
  final ValueNotifier<double> _zoom = ValueNotifier<double>(1.0);
  final ValueNotifier<int?> _hoveredCreep = ValueNotifier<int?>(null);
  _CreepRenderMode _creepRenderMode = _CreepRenderMode.painter;

  Timer? _loop;
  DateTime? _lastFrameAt;
  int _seed = 20260305;
  bool _cameraFitted = false;

  @override
  void initState() {
    super.initState();
    final p = _preset.value;
    _engine = TdMegaMapEngine(
      seed: _seed,
      laneCount: p.lanes,
      creepsPerLane: p.creepsPerLane,
      segmentCount: p.segments,
    );
    _startLoop();
  }

  @override
  void dispose() {
    _loop?.cancel();
    _preset.dispose();
    _zoom.dispose();
    _hoveredCreep.dispose();
    _engine.dispose();
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
      final dt =
          now.difference(previous).inMicroseconds /
          Duration.microsecondsPerSecond;
      _engine.step(dt);
    });
  }

  void _fitCameraOnce() {
    if (_cameraFitted) return;
    final stats = _controller.camera.renderStats;
    if (stats == null || stats.viewportSize.isEmpty) return;

    final bounds = _engine.boardBounds;
    final viewW = stats.viewportSize.width;
    final viewH = stats.viewportSize.height;
    final scaleX = viewW / bounds.width;
    final scaleY = viewH / bounds.height;
    final scale = math.min(scaleX, scaleY) * 0.94;

    final tx = (viewW - bounds.width * scale) * 0.5 - bounds.left * scale;
    final ty = (viewH - bounds.height * scale) * 0.5 - bounds.top * scale;
    _controller.camera.setTransform(
      Matrix4.identity()
        ..translate(tx, ty)
        ..scale(scale, scale),
    );
    _cameraFitted = true;
    _zoom.value = scale;
  }

  void _regenerate({int? seed}) {
    _seed = seed ?? _seed;
    final p = _preset.value;
    _engine.regenerate(
      seed: _seed,
      laneCount: p.lanes,
      creepsPerLane: p.creepsPerLane,
      segmentCount: p.segments,
      towerFill: 0.34,
    );
    _cameraFitted = false;
  }

  void _regenerateNewSeed() {
    final next = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    _regenerate(seed: next);
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFE2E8F0),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _hudRow() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _engine.seedValue,
        _engine.laneCountValue,
        _engine.padCountValue,
        _engine.towerCountValue,
        _engine.creepCountValue,
        _engine.running,
        _zoom,
        _hoveredCreep,
      ]),
      builder: (context, _) {
        return Container(
          width: double.infinity,
          color: const Color(0xFF0B1323),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Seed ${_engine.seedValue.value}'),
                const SizedBox(width: 8),
                _chip('Lanes ${_engine.laneCountValue.value}'),
                const SizedBox(width: 8),
                _chip('Pads ${_engine.padCountValue.value}'),
                const SizedBox(width: 8),
                _chip('Towers ${_engine.towerCountValue.value}'),
                const SizedBox(width: 8),
                _chip('Creeps ${_engine.creepCountValue.value}'),
                const SizedBox(width: 8),
                _chip('Zoom ${_zoom.value.toStringAsFixed(3)}'),
                const SizedBox(width: 8),
                _chip(_engine.running.value ? 'Running' : 'Paused'),
                const SizedBox(width: 8),
                _chip(
                  _creepRenderMode == _CreepRenderMode.widgets
                      ? 'Creeps: widgets'
                      : 'Creeps: painter',
                ),
                const SizedBox(width: 8),
                _chip('Hover ${_hoveredCreep.value?.toString() ?? '-'}'),
              ],
            ),
          ),
        );
      },
    );
  }

  CanvasLayer _buildCreepsWidgetLayer() {
    return CanvasLayer.overlay(
      id: 'td-mega-creeps-widget',
      ignorePointer: false,
      listenable: _engine.tick,
      builder: (context, transform, controller) {
        const dotSize = 3.0;
        const hoverHitSize = 10.0;
        final viewport = controller.renderStats?.viewportSize ?? Size.zero;
        final children = <Widget>[];

        for (final q in _engine.world.query2<MegaPositionC, MegaCreepC>()) {
          final screen = MatrixUtils.transformPoint(
            transform,
            q.component1.offset,
          );
          if (!viewport.isEmpty) {
            if (screen.dx < -dotSize ||
                screen.dy < -dotSize ||
                screen.dx > viewport.width + dotSize ||
                screen.dy > viewport.height + dotSize) {
              continue;
            }
          }
          children.add(
            Positioned(
              left: screen.dx - hoverHitSize * 0.5,
              top: screen.dy - hoverHitSize * 0.5,
              width: hoverHitSize,
              height: hoverHitSize,
              child: MouseRegion(
                opaque: false,
                onEnter: (_) => _hoveredCreep.value = q.entity,
                onExit: (_) {
                  if (_hoveredCreep.value == q.entity) {
                    _hoveredCreep.value = null;
                  }
                },
                child: Center(
                  child: SizedBox(
                    width: dotSize,
                    height: dotSize,
                    child: _MegaCreepDotWidget(
                      hovered: _hoveredCreep.value == q.entity,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return RepaintBoundary(
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Massive Multi-Widget Art Scene'),
        actions: [
          ValueListenableBuilder<_MegaMapPreset>(
            valueListenable: _preset,
            builder: (context, preset, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<_MegaMapPreset>(
                    value: preset,
                    borderRadius: BorderRadius.circular(8),
                    onChanged: (next) {
                      if (next == null) return;
                      _preset.value = next;
                      _regenerate();
                    },
                    items: [
                      for (final option in _MegaMapPreset.values)
                        DropdownMenuItem(
                          value: option,
                          child: Text('Preset: ${option.label}'),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          FilledButton(
            onPressed: _regenerateNewSeed,
            child: const Text('New seed'),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<bool>(
            valueListenable: _engine.running,
            builder: (context, running, _) {
              return OutlinedButton(
                onPressed: () => _engine.setRunning(!running),
                child: Text(running ? 'Pause' : 'Resume'),
              );
            },
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _creepRenderMode = _creepRenderMode == _CreepRenderMode.painter
                    ? _CreepRenderMode.widgets
                    : _CreepRenderMode.painter;
              });
            },
            child: Text(
              _creepRenderMode == _CreepRenderMode.painter
                  ? 'Creeps: Painter'
                  : 'Creeps: Widgets',
            ),
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
          _hudRow(),
          Expanded(
            child: InfinityCanvas(
              controller: _controller,
              enableCulling: true,
              cullPadding: 340,
              onZoomChanged: (value) {
                _zoom.value = value;
                return value;
              },
              layers: [
                CanvasLayer.painter(
                  id: 'td-mega-bg',
                  painterBuilder: (transform) =>
                      TdMegaBackdropPainter(transform: transform),
                ),
                CanvasLayer.painter(
                  id: 'td-mega-world',
                  painterBuilder: (transform) => TdMegaWorldPainter(
                    transform: transform,
                    engine: _engine,
                    paintCreeps: _creepRenderMode == _CreepRenderMode.painter,
                    repaint: _engine.tick,
                  ),
                ),
                if (_creepRenderMode == _CreepRenderMode.widgets)
                  _buildCreepsWidgetLayer(),
                CanvasLayer.overlay(
                  id: 'td-mega-hover-probe',
                  ignorePointer: true,
                  listenable: _hoveredCreep,
                  builder: (context, transform, controller) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12, top: 12),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xCC07111E),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2C4763)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              'Mode ${_creepRenderMode == _CreepRenderMode.widgets ? 'widgets' : 'painter'}   Hover ${_hoveredCreep.value ?? '-'}',
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                CanvasLayer.overlay(
                  id: 'td-mega-mini-map',
                  ignorePointer: false,
                  builder: (context, transform, controller) {
                    return TdMegaMiniMapOverlay(
                      engine: _engine,
                      controller: controller,
                      repaint: _engine.tick,
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

class _MegaCreepDotWidget extends StatelessWidget {
  final bool hovered;

  const _MegaCreepDotWidget({this.hovered = false});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: hovered ? const Color(0xFFFFC9D8) : const Color(0xFFFF5C8A),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: hovered ? const Color(0xAAFFD6E1) : const Color(0x66FF5C8A),
            blurRadius: hovered ? 3.8 : 2.4,
            spreadRadius: hovered ? 0.5 : 0.2,
          ),
        ],
      ),
    );
  }
}
