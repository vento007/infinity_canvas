import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

import 'galaxy_trade_generator.dart';
import 'galaxy_trade_minimap.dart';
import 'galaxy_trade_models.dart';
import 'galaxy_trade_painters.dart';

enum _GalaxyPreset {
  corridor('Trade Corridor', systems: 90, shipments: 220, clusters: 5),
  frontier('Frontier Mesh', systems: 130, shipments: 420, clusters: 7),
  empire('Empire Lattice', systems: 180, shipments: 760, clusters: 9);

  final String label;
  final int systems;
  final int shipments;
  final int clusters;

  const _GalaxyPreset(
    this.label, {
    required this.systems,
    required this.shipments,
    required this.clusters,
  });
}

class GalaxyTradeMapDemoPage extends StatefulWidget {
  const GalaxyTradeMapDemoPage({super.key});

  @override
  State<GalaxyTradeMapDemoPage> createState() => _GalaxyTradeMapDemoPageState();
}

class _GalaxyTradeMapDemoPageState extends State<GalaxyTradeMapDemoPage> {
  static const Size _systemCardSize = Size(150, 82);

  final CanvasController _controller = CanvasController(
    minZoom: 0.03,
    maxZoom: 3.2,
  );

  final ValueNotifier<_GalaxyPreset> _preset = ValueNotifier<_GalaxyPreset>(
    _GalaxyPreset.frontier,
  );
  final ValueNotifier<bool> _running = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _flowEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<double> _dustStrength = ValueNotifier<double>(4.0);
  final ValueNotifier<double> _zoom = ValueNotifier<double>(1.0);
  final ValueNotifier<String?> _selectedSystemId = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _hoveredSystemId = ValueNotifier<String?>(null);
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  Timer? _loop;
  DateTime? _lastFrameAt;
  int _seed = 20260305;
  int _sceneRevision = 0;
  bool _cameraFitted = false;
  double _timeSeconds = 0;

  late GalaxyTradeScene _scene;
  late List<TradeShipment> _shipments;
  late List<GalaxyMeteor> _meteors;
  late List<CanvasItem> _systemItems;
  late math.Random _runtimeRng;
  double _meteorSpawnIn = 0;

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
    _flowEnabled.dispose();
    _dustStrength.dispose();
    _zoom.dispose();
    _selectedSystemId.dispose();
    _hoveredSystemId.dispose();
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
        _stepShipments(dt);
        _stepMeteors(dt);
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
    _cameraFitted = true;
  }

  void _stepShipments(double dt) {
    if (_scene.routes.isEmpty) return;

    for (final shipment in _shipments) {
      shipment.progress += shipment.speed * dt;
      if (shipment.progress >= 1.0) {
        _respawnShipment(shipment);
      }
    }
  }

  void _respawnShipment(TradeShipment shipment) {
    final routeIndex = _runtimeRng.nextInt(_scene.routes.length);
    shipment
      ..routeIndex = routeIndex
      ..progress = 0
      ..speed = _randomRange(0.07, 0.26)
      ..size = _randomRange(0.65, 1.45)
      ..color = _shipmentColorForRoute(routeIndex);
  }

  double _randomRange(double min, double max) {
    return min + (max - min) * _runtimeRng.nextDouble();
  }

  Color _shipmentColorForRoute(int routeIndex) {
    final route = _scene.routes[routeIndex];
    return Color.lerp(route.color, Colors.white, 0.24) ?? route.color;
  }

  void _stepMeteors(double dt) {
    _meteorSpawnIn -= dt;
    if (_meteorSpawnIn <= 0 && _meteors.length < 4) {
      _spawnMeteor();
      _meteorSpawnIn = _randomRange(2.4, 6.8);
    }

    final killBounds = _scene.bounds.inflate(5200);
    for (final meteor in _meteors) {
      meteor.position = meteor.position + meteor.velocity * dt;
      meteor.life -= dt;
    }
    _meteors.removeWhere(
      (m) => m.life <= 0 || !killBounds.contains(m.position),
    );
  }

  void _spawnMeteor() {
    final spawnBounds = _scene.bounds.inflate(4200);
    final targetBounds = _scene.bounds.inflate(1200);
    final side = _runtimeRng.nextInt(4);

    late Offset start;
    switch (side) {
      case 0:
        start = Offset(
          _randomRange(spawnBounds.left, spawnBounds.right),
          spawnBounds.top,
        );
        break;
      case 1:
        start = Offset(
          spawnBounds.right,
          _randomRange(spawnBounds.top, spawnBounds.bottom),
        );
        break;
      case 2:
        start = Offset(
          _randomRange(spawnBounds.left, spawnBounds.right),
          spawnBounds.bottom,
        );
        break;
      default:
        start = Offset(
          spawnBounds.left,
          _randomRange(spawnBounds.top, spawnBounds.bottom),
        );
        break;
    }

    final target = Offset(
      _randomRange(targetBounds.left, targetBounds.right),
      _randomRange(targetBounds.top, targetBounds.bottom),
    );
    var delta = target - start;
    final len = delta.distance;
    if (len <= 1e-6) return;
    delta = Offset(delta.dx / len, delta.dy / len);

    final speed = _randomRange(980, 1850);
    final velocity = Offset(delta.dx * speed, delta.dy * speed);
    final life = _randomRange(0.95, 1.9);
    final tint = _runtimeRng.nextBool()
        ? const Color(0xFFB5EEFF)
        : const Color(0xFFFFE0AF);

    _meteors.add(
      GalaxyMeteor(
        position: start,
        velocity: velocity,
        length: _randomRange(180, 460),
        life: life,
        maxLife: life,
        width: _randomRange(1.2, 2.8),
        color: tint,
      ),
    );
  }

  void _regenerate({int? seed, _GalaxyPreset? forcePreset}) {
    _seed = seed ?? _seed;
    final preset = forcePreset ?? _preset.value;

    final generated = generateGalaxyTradeScene(
      seed: _seed,
      systemCount: preset.systems,
      shipmentCount: preset.shipments,
      clusterCount: preset.clusters,
    );

    _runtimeRng = math.Random(_seed ^ 0x9E3779B9);

    _scene = generated.scene;
    _shipments = generated.shipments;
    _meteors = <GalaxyMeteor>[];
    _meteorSpawnIn = _randomRange(1.2, 3.8);
    _sceneRevision++;
    _systemItems = _buildSystemItems();
    _selectedSystemId.value = null;
    _hoveredSystemId.value = null;
    _cameraFitted = false;
    _tick.value = _tick.value + 1;
  }

  void _randomizeSeed() {
    final next = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    setState(() {
      _regenerate(seed: next);
    });
  }

  List<CanvasItem> _buildSystemItems() {
    return [
      for (final system in _scene.systems)
        CanvasItem(
          id: 'r${_sceneRevision}_${system.id}',
          worldPosition:
              system.center -
              Offset(_systemCardSize.width * 0.5, _systemCardSize.height * 0.5),
          size: CanvasItemSize.fromSize(_systemCardSize),
          behavior: const CanvasItemBehavior(
            draggable: false,
            bringToFront: CanvasBringToFrontBehavior.never,
          ),
          dragEnabled: false,
          child: _GalaxySystemWidget(
            system: system,
            selectedSystemId: _selectedSystemId,
            hoveredSystemId: _hoveredSystemId,
            onTap: () {
              _selectedSystemId.value = system.id;
            },
          ),
        ),
    ];
  }

  GalaxySystem? _lookupSystem(String? id) {
    if (id == null) return null;
    for (final system in _scene.systems) {
      if (system.id == id) return system;
    }
    return null;
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B152A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2C436D)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFE2ECFF),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _hudStrip() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _preset,
        _running,
        _flowEnabled,
        _dustStrength,
        _zoom,
        _selectedSystemId,
        _hoveredSystemId,
      ]),
      builder: (context, _) {
        final selected = _lookupSystem(_selectedSystemId.value);
        return Container(
          color: const Color(0xFF050E1D),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Seed $_seed'),
                const SizedBox(width: 8),
                _chip('Systems ${_scene.systems.length}'),
                const SizedBox(width: 8),
                _chip('Routes ${_scene.routes.length}'),
                const SizedBox(width: 8),
                _chip('Shipments ${_shipments.length}'),
                const SizedBox(width: 8),
                _chip('Zoom ${_zoom.value.toStringAsFixed(3)}'),
                const SizedBox(width: 8),
                _chip(_running.value ? 'Sim running' : 'Sim paused'),
                const SizedBox(width: 8),
                _chip(_flowEnabled.value ? 'Route flow on' : 'Route flow off'),
                const SizedBox(width: 8),
                _chip('Dust ${_dustStrength.value.toStringAsFixed(1)}x'),
                const SizedBox(width: 8),
                _chip(
                  selected != null ? 'Selected ${selected.name}' : 'Selected -',
                ),
                const SizedBox(width: 8),
                _chip('Hover ${_hoveredSystemId.value ?? '-'}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _overlayCard(CanvasLayerController controller) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _selectedSystemId,
        _hoveredSystemId,
        _zoom,
        controller.renderStatsListenable,
      ]),
      builder: (context, _) {
        final selected = _lookupSystem(_selectedSystemId.value);
        final hovered = _lookupSystem(_hoveredSystemId.value);
        final stats = controller.renderStats;
        final visible = stats?.visibleItems ?? 0;
        final total = stats?.totalItems ?? _scene.systems.length;

        final title = selected?.name ?? hovered?.name ?? 'No system selected';
        final supply = (selected?.supply ?? hovered?.supply)?.toStringAsFixed(
          0,
        );
        final demand = (selected?.demand ?? hovered?.demand)?.toStringAsFixed(
          0,
        );

        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 14, right: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xD0081020),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2F4C7A)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x88000000),
                    blurRadius: 16,
                    offset: Offset(0, 7),
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
                    color: Color(0xFFDDE8FF),
                    fontSize: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Galaxy Inspector',
                        style: TextStyle(
                          color: Color(0xFF9FDBFF),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text('Supply ${supply ?? '-'}   Demand ${demand ?? '-'}'),
                      Text('Visible items $visible / $total'),
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
    final routeRepaint = Listenable.merge([
      _tick,
      _selectedSystemId,
      _hoveredSystemId,
      _flowEnabled,
    ]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Galaxy Trade Map'),
        actions: [
          ValueListenableBuilder<_GalaxyPreset>(
            valueListenable: _preset,
            builder: (context, preset, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<_GalaxyPreset>(
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
                      for (final option in _GalaxyPreset.values)
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
          ValueListenableBuilder<bool>(
            valueListenable: _flowEnabled,
            builder: (context, enabled, _) {
              return OutlinedButton(
                onPressed: () => _flowEnabled.value = !enabled,
                child: Text(enabled ? 'Flow: on' : 'Flow: off'),
              );
            },
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<double>(
            valueListenable: _dustStrength,
            builder: (context, dust, _) {
              return OutlinedButton(
                onPressed: () {
                  const steps = <double>[0.0, 0.5, 1.0, 2.0, 4.0, 8.0];
                  final idx = steps.indexOf(dust);
                  final next = idx < 0 ? 1.0 : steps[(idx + 1) % steps.length];
                  _dustStrength.value = next;
                },
                child: Text('Dust ${dust.toStringAsFixed(1)}x'),
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
              cullPadding: 420,
              onZoomChanged: (value) {
                _zoom.value = value;
                return value;
              },
              layers: [
                CanvasLayer.painter(
                  id: 'galaxy-backdrop',
                  painterBuilder: (transform) => GalaxyBackdropPainter(
                    transform: transform,
                    scene: _scene,
                    readTimeSeconds: () => _timeSeconds,
                    readDustStrength: () => _dustStrength.value,
                    repaint: _tick,
                  ),
                ),
                CanvasLayer.painter(
                  id: 'galaxy-meteors',
                  painterBuilder: (transform) => GalaxyMeteorsPainter(
                    transform: transform,
                    meteors: _meteors,
                    repaint: _tick,
                  ),
                ),
                CanvasLayer.painter(
                  id: 'galaxy-routes',
                  painterBuilder: (transform) => GalaxyTradeRoutesPainter(
                    transform: transform,
                    scene: _scene,
                    shipments: _shipments,
                    selectedSystemId: _selectedSystemId.value,
                    hoveredSystemId: _hoveredSystemId.value,
                    flowEnabled: _flowEnabled.value,
                    readTimeSeconds: () => _timeSeconds,
                    repaint: routeRepaint,
                  ),
                ),
                CanvasLayer.positionedItems(
                  id: 'galaxy-systems',
                  items: _systemItems,
                ),
                CanvasLayer.overlay(
                  id: 'galaxy-minimap',
                  ignorePointer: false,
                  builder: (context, transform, controller) {
                    return GalaxyTradeMiniMapOverlay(
                      scene: _scene,
                      controller: controller,
                      selectedSystemId: _selectedSystemId,
                      hoveredSystemId: _hoveredSystemId,
                    );
                  },
                ),
                CanvasLayer.overlay(
                  id: 'galaxy-overlay',
                  ignorePointer: true,
                  builder: (context, transform, controller) {
                    return _overlayCard(controller);
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

class _GalaxySystemWidget extends StatelessWidget {
  final GalaxySystem system;
  final ValueNotifier<String?> selectedSystemId;
  final ValueNotifier<String?> hoveredSystemId;
  final VoidCallback onTap;

  const _GalaxySystemWidget({
    required this.system,
    required this.selectedSystemId,
    required this.hoveredSystemId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([selectedSystemId, hoveredSystemId]),
      builder: (context, _) {
        final selected = selectedSystemId.value == system.id;
        final hovered = hoveredSystemId.value == system.id;
        final active = selected || hovered;

        final accent = system.factionColor;
        final border = selected
            ? Colors.white.withValues(alpha: 0.95)
            : (hovered
                  ? const Color(0xFFFFE2A8)
                  : accent.withValues(alpha: 0.45));

        return MouseRegion(
          opaque: false,
          onEnter: (_) => hoveredSystemId.value = system.id,
          onExit: (_) {
            if (hoveredSystemId.value == system.id) {
              hoveredSystemId.value = null;
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: _GalaxyTradeMapDemoPageState._systemCardSize.width,
              height: _GalaxyTradeMapDemoPageState._systemCardSize.height,
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border, width: active ? 2.0 : 1.0),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(accent, Colors.black, 0.62)!,
                    Color.lerp(accent, const Color(0xFF030712), 0.78)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: active ? 0.34 : 0.18),
                    blurRadius: active ? 18 : 10,
                    spreadRadius: active ? 1.4 : 0.2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Color(0xFFDDE8FF), fontSize: 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      system.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      system.id,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'S ${system.supply.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: const Color(
                                0xFF86EFAC,
                              ).withValues(alpha: active ? 0.95 : 0.78),
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'D ${system.demand.toStringAsFixed(0)}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: const Color(
                                0xFFFCA5A5,
                              ).withValues(alpha: active ? 0.95 : 0.78),
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
