import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:infinity_canvas/infinity_canvas.dart';
import 'package:flutter/material.dart';

import 'components.dart';
import 'engine.dart';
import 'minimap.dart';
import 'painters.dart';

class TowerDefenseDemoPage extends StatefulWidget {
  const TowerDefenseDemoPage({super.key});

  @override
  State<TowerDefenseDemoPage> createState() => _TowerDefenseDemoPageState();
}

class _TowerDefenseDemoPageState extends State<TowerDefenseDemoPage> {
  final CanvasController _controller = CanvasController(
    minZoom: 0.2,
    maxZoom: 2.0,
  );

  final TdGameEngine _engine = TdGameEngine();

  final ValueNotifier<TdTowerKind> _selectedKind = ValueNotifier<TdTowerKind>(
    TdTowerKind.pulse,
  );
  final ValueNotifier<int?> _hoveredPad = ValueNotifier<int?>(null);
  final ValueNotifier<int?> _selectedPad = ValueNotifier<int?>(null);
  final ValueNotifier<String> _lastEvent = ValueNotifier<String>('ready');
  final ValueNotifier<double> _zoom = ValueNotifier<double>(1.0);

  Timer? _loop;
  DateTime? _lastFrameAt;
  bool _cameraFitted = false;
  bool _miniMapGestureActive = false;
  Offset? _pointerDownScreen;
  ui.FragmentProgram? _bgProgram;
  ui.FragmentProgram? _fxOrbProgram;
  ui.FragmentProgram? _fxLineProgram;

  @override
  void initState() {
    super.initState();
    _loadBackgroundShader();
    _loadFxShaders();
    _startLoop();
  }

  @override
  void dispose() {
    _loop?.cancel();
    _selectedKind.dispose();
    _hoveredPad.dispose();
    _selectedPad.dispose();
    _lastEvent.dispose();
    _zoom.dispose();
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

  Future<void> _loadBackgroundShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/td_neon_bg.frag',
      );
      if (!mounted) return;
      setState(() {
        _bgProgram = program;
      });
      _lastEvent.value = 'shader loaded';
    } catch (_) {
      if (!mounted) return;
      _lastEvent.value = 'shader fallback';
    }
  }

  Future<void> _loadFxShaders() async {
    try {
      final orbProgram = await ui.FragmentProgram.fromAsset(
        'shaders/td_fx_orb.frag',
      );
      final lineProgram = await ui.FragmentProgram.fromAsset(
        'shaders/td_fx_line.frag',
      );
      if (!mounted) return;
      setState(() {
        _fxOrbProgram = orbProgram;
        _fxLineProgram = lineProgram;
      });
      _lastEvent.value = 'fx shaders loaded';
    } catch (_) {
      if (!mounted) return;
      _lastEvent.value = 'fx shader fallback';
    }
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
    final scale = math.min(scaleX, scaleY) * 0.92;

    final tx = (viewW - bounds.width * scale) * 0.5 - bounds.left * scale;
    final ty = (viewH - bounds.height * scale) * 0.5 - bounds.top * scale;

    _controller.camera.setTransform(
      Matrix4.identity()
        ..translate(tx, ty)
        ..scale(scale, scale),
    );
    _cameraFitted = true;
  }

  void _startWave() {
    final ok = _engine.startNextWave();
    _lastEvent.value = ok
        ? 'wave ${_engine.wave.value} started'
        : 'cannot start wave';
  }

  void _togglePause() {
    final next = !_engine.paused.value;
    _engine.setPaused(next);
    _lastEvent.value = next ? 'paused' : 'resumed';
  }

  void _reset() {
    _engine.reset();
    _selectedPad.value = null;
    _lastEvent.value = 'reset';
  }

  void _onPointerAt(Offset screenPos) {
    final world = _controller.camera.screenToWorld(screenPos);
    _hoveredPad.value = _engine.hitPadIndex(world);
  }

  void _onPointerTap(Offset screenPos) {
    if (_engine.gameOver.value) return;
    final world = _controller.camera.screenToWorld(screenPos);
    final padIndex = _engine.hitPadIndex(world);
    if (padIndex == null) {
      _selectedPad.value = null;
      _lastEvent.value = 'selection cleared';
      return;
    }

    final selected = _selectedPad.value;
    final kind = _selectedKind.value;
    final hasTower = _engine.hasTowerOnPad(padIndex);

    if (hasTower) {
      if (selected == padIndex) {
        final currentKind = _engine.towerKindOnPad(padIndex);
        if (currentKind != null && currentKind != kind) {
          final replaced = _engine.replaceTowerOnPad(padIndex, kind);
          if (replaced) {
            _lastEvent.value =
                'replaced with ${kind.label} on pad ${padIndex + 1}';
          } else {
            final need =
                _engine.replaceCostDeltaOnPad(padIndex, kind) ?? kind.cost;
            _lastEvent.value = 'not enough gold to replace ($need)';
          }
          return;
        }
      }
      _selectedPad.value = padIndex;
      final level = _engine.towerLevelOnPad(padIndex) ?? 1;
      final towerKind = _engine.towerKindOnPad(padIndex);
      if (towerKind != null) {
        _lastEvent.value =
            'selected ${towerKind.label} L$level on pad ${padIndex + 1}';
      }
      return;
    }

    if (selected != null && _engine.hasTowerOnPad(selected)) {
      final moved = _engine.moveTower(selected, padIndex);
      if (moved) {
        _selectedPad.value = padIndex;
        _lastEvent.value = 'moved tower to pad ${padIndex + 1}';
        return;
      }
    }

    final ok = _engine.buildTowerOnPad(padIndex, kind);
    if (ok) {
      _selectedPad.value = padIndex;
      _lastEvent.value = 'built ${kind.label} on pad ${padIndex + 1}';
    } else if (!_engine.canBuildOnPad(padIndex)) {
      _lastEvent.value = 'pad ${padIndex + 1} occupied';
    } else {
      _lastEvent.value = 'not enough gold (${kind.cost})';
    }
  }

  bool _isInsideMiniMap(Offset localPos, Size canvasSize) {
    final rect = Rect.fromLTWH(
      canvasSize.width - tdMiniMapSize.width - tdMiniMapMargin.right,
      canvasSize.height - tdMiniMapSize.height - tdMiniMapMargin.bottom,
      tdMiniMapSize.width,
      tdMiniMapSize.height,
    );
    return rect.contains(localPos);
  }

  void _upgradeSelectedTower() {
    final selected = _selectedPad.value;
    if (selected == null) return;
    final ok = _engine.upgradeTowerOnPad(selected);
    if (ok) {
      final level = _engine.towerLevelOnPad(selected);
      _lastEvent.value = 'upgraded to L$level on pad ${selected + 1}';
    } else {
      final needed = _engine.towerUpgradeCostOnPad(selected);
      if (needed == null) {
        _lastEvent.value = 'max level reached';
      } else {
        _lastEvent.value = 'not enough gold to upgrade ($needed)';
      }
    }
  }

  void _sellSelectedTower() {
    final selected = _selectedPad.value;
    if (selected == null) return;
    final sellValue = _engine.towerSellValueOnPad(selected);
    final ok = _engine.sellTowerOnPad(selected);
    if (ok) {
      _selectedPad.value = null;
      _lastEvent.value = 'sold tower (+${sellValue ?? 0} gold)';
    }
  }

  void _replaceSelectedTower() {
    final selected = _selectedPad.value;
    if (selected == null) return;
    final nextKind = _selectedKind.value;
    final ok = _engine.replaceTowerOnPad(selected, nextKind);
    if (ok) {
      _lastEvent.value =
          'replaced with ${nextKind.label} on pad ${selected + 1}';
    } else {
      final needed = _engine.replaceCostDeltaOnPad(selected, nextKind);
      if (needed == null) return;
      _lastEvent.value = needed == 0
          ? 'already ${nextKind.label}'
          : 'not enough gold to replace ($needed)';
    }
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

  Widget _hud() {
    return Container(
      color: const Color(0xFF0B1323),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder<int>(
              valueListenable: _engine.gold,
              builder: (_, v, __) => _chip('Gold $v'),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<int>(
              valueListenable: _engine.lives,
              builder: (_, v, __) => _chip('Lives $v'),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<int>(
              valueListenable: _engine.wave,
              builder: (_, v, __) => _chip('Wave $v'),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<int>(
              valueListenable: _engine.score,
              builder: (_, v, __) => _chip('Score $v'),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<int>(
              valueListenable: _engine.tick,
              builder: (_, __, ___) {
                return _chip(
                  'Creeps ${_engine.creepCount}  Towers ${_engine.towerCount}  Proj ${_engine.projectileCount}',
                );
              },
            ),
            const SizedBox(width: 12),
            ValueListenableBuilder<TdTowerKind>(
              valueListenable: _selectedKind,
              builder: (_, kind, __) {
                return SegmentedButton<TdTowerKind>(
                  segments: [
                    for (final t in TdTowerKind.values)
                      ButtonSegment<TdTowerKind>(
                        value: t,
                        label: Text('${t.label} (${t.cost})'),
                      ),
                  ],
                  selected: {kind},
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFF041420);
                      }
                      if (states.contains(WidgetState.disabled)) {
                        return const Color(0xFF64748B);
                      }
                      return const Color(0xFFE2E8F0);
                    }),
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFF93C5FD);
                      }
                      return const Color(0xFF0F172A);
                    }),
                    side: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const BorderSide(
                          color: Color(0xFF7DD3FC),
                          width: 1.2,
                        );
                      }
                      return const BorderSide(
                        color: Color(0xFF334155),
                        width: 1.0,
                      );
                    }),
                  ),
                  onSelectionChanged: (next) {
                    if (next.isEmpty) return;
                    _selectedKind.value = next.first;
                  },
                );
              },
            ),
            const SizedBox(width: 10),
            ListenableBuilder(
              listenable: Listenable.merge([
                _selectedPad,
                _selectedKind,
                _engine.gold,
              ]),
              builder: (_, __) {
                final selected = _selectedPad.value;
                if (selected == null || !_engine.hasTowerOnPad(selected)) {
                  return _chip('Tap tower to select, tap empty pad to move');
                }

                final towerKind = _engine.towerKindOnPad(selected)!;
                final level = _engine.towerLevelOnPad(selected) ?? 1;
                final upgradeCost = _engine.towerUpgradeCostOnPad(selected);
                final sellValue = _engine.towerSellValueOnPad(selected) ?? 0;
                final replaceCost =
                    _engine.replaceCostDeltaOnPad(
                      selected,
                      _selectedKind.value,
                    ) ??
                    0;

                final canUpgrade =
                    upgradeCost != null && _engine.gold.value >= upgradeCost;
                final canReplace =
                    towerKind != _selectedKind.value &&
                    _engine.gold.value >= replaceCost;

                return Row(
                  children: [
                    _chip('Pad ${selected + 1}  ${towerKind.label}  L$level'),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: canUpgrade ? _upgradeSelectedTower : null,
                      child: Text(
                        upgradeCost == null
                            ? 'Upgrade max'
                            : 'Upgrade $upgradeCost',
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: canReplace ? _replaceSelectedTower : null,
                      child: Text(
                        towerKind == _selectedKind.value
                            ? 'Replace -'
                            : 'Replace $replaceCost',
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _sellSelectedTower,
                      child: Text('Sell +$sellValue'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<bool>(
              valueListenable: _engine.waveRunning,
              builder: (_, running, __) {
                return FilledButton.tonal(
                  onPressed: running ? null : _startWave,
                  child: Text(running ? 'Wave running' : 'Start wave'),
                );
              },
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<bool>(
              valueListenable: _engine.paused,
              builder: (_, p, __) => FilledButton.tonal(
                onPressed: _togglePause,
                child: Text(p ? 'Resume' : 'Pause'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _reset, child: const Text('Reset')),
            const SizedBox(width: 12),
            ValueListenableBuilder<double>(
              valueListenable: _zoom,
              builder: (_, z, __) => Text(
                'Zoom ${z.toStringAsFixed(2)}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            ValueListenableBuilder<String>(
              valueListenable: _lastEvent,
              builder: (_, e, __) => Text(
                'Last: $e',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(bottom: false, child: _hud()),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerHover: (e) {
                    if (_miniMapGestureActive ||
                        _isInsideMiniMap(e.localPosition, canvasSize)) {
                      return;
                    }
                    _onPointerAt(e.localPosition);
                  },
                  onPointerMove: (e) {
                    if (_miniMapGestureActive ||
                        _isInsideMiniMap(e.localPosition, canvasSize)) {
                      return;
                    }
                    _onPointerAt(e.localPosition);
                  },
                  onPointerDown: (e) {
                    if (_isInsideMiniMap(e.localPosition, canvasSize)) {
                      _miniMapGestureActive = true;
                      _pointerDownScreen = null;
                      return;
                    }
                    _pointerDownScreen = e.localPosition;
                    _onPointerAt(e.localPosition);
                  },
                  onPointerUp: (e) {
                    if (_miniMapGestureActive) {
                      _miniMapGestureActive = false;
                      return;
                    }
                    _onPointerAt(e.localPosition);
                    final start = _pointerDownScreen;
                    _pointerDownScreen = null;
                    if (start == null) return;
                    if ((e.localPosition - start).distance <= 6) {
                      _onPointerTap(e.localPosition);
                    }
                  },
                  onPointerCancel: (_) {
                    _miniMapGestureActive = false;
                    _pointerDownScreen = null;
                  },
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _engine.gameOver,
                    builder: (_, over, __) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          InfinityCanvas(
                            controller: _controller,
                            inputBehavior: const CanvasInputBehavior.desktop(),
                            enableCulling: false,
                            onZoomChanged: (z) => _zoom.value = z,
                            layers: [
                              CanvasLayer.overlay(
                                id: 'td-bg',
                                listenable: _engine.tick,
                                builder: (context, transform, controller) {
                                  return CustomPaint(
                                    painter: TdBackdropPainter(
                                      transform: transform,
                                      program: _bgProgram,
                                      timeSeconds: _engine.elapsedSeconds,
                                    ),
                                    size: Size.infinite,
                                  );
                                },
                              ),
                              CanvasLayer.painter(
                                id: 'td-path-fx',
                                painterBuilder: (transform) => TdPathFxPainter(
                                  transform: transform,
                                  engine: _engine,
                                  lineProgram: _fxLineProgram,
                                  repaint: _engine.tick,
                                ),
                              ),
                              CanvasLayer.painter(
                                id: 'td-world',
                                painterBuilder: (transform) => TdWorldPainter(
                                  transform: transform,
                                  engine: _engine,
                                  selectedKind: _selectedKind.value,
                                  hoveredPadIndex: _hoveredPad.value,
                                  selectedPadIndex: _selectedPad.value,
                                  repaint: Listenable.merge([
                                    _engine.tick,
                                    _selectedKind,
                                    _hoveredPad,
                                    _selectedPad,
                                  ]),
                                ),
                              ),
                              CanvasLayer.painter(
                                id: 'td-fx',
                                painterBuilder: (transform) => TdWorldFxPainter(
                                  transform: transform,
                                  engine: _engine,
                                  orbProgram: _fxOrbProgram,
                                  repaint: _engine.tick,
                                ),
                              ),
                              CanvasLayer.overlay(
                                id: 'td-mini-map',
                                ignorePointer: false,
                                builder: (context, transform, controller) {
                                  return TdMiniMapOverlay(
                                    engine: _engine,
                                    controller: controller,
                                    repaint: Listenable.merge([
                                      _engine.tick,
                                      _selectedPad,
                                      _hoveredPad,
                                    ]),
                                  );
                                },
                              ),
                            ],
                          ),
                          if (over)
                            ColoredBox(
                              color: Colors.black.withValues(alpha: 0.66),
                              child: Center(
                                child: Container(
                                  width: 360,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0B1323),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Base Lost',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ValueListenableBuilder<int>(
                                        valueListenable: _engine.score,
                                        builder: (_, s, __) => Text(
                                          'Score: $s',
                                          style: const TextStyle(
                                            color: Color(0xFFD1E2FF),
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      FilledButton(
                                        onPressed: _reset,
                                        child: const Text('Restart'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
