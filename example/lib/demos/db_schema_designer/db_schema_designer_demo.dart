import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

import 'schema_models.dart';
import 'schema_painters.dart';
import 'schema_seed.dart';
import 'widgets/schema_table_card.dart';

class DbSchemaDesignerDemoPage extends StatefulWidget {
  const DbSchemaDesignerDemoPage({super.key});

  @override
  State<DbSchemaDesignerDemoPage> createState() =>
      _DbSchemaDesignerDemoPageState();
}

class _DbSchemaDesignerDemoPageState extends State<DbSchemaDesignerDemoPage> {
  final CanvasController _controller = CanvasController(
    minZoom: 0.03,
    maxZoom: 2.8,
  );

  final ValueNotifier<DbSchemaPreset> _preset = ValueNotifier<DbSchemaPreset>(
    DbSchemaPreset.scale,
  );
  final ValueNotifier<String?> _selectedTableId = ValueNotifier<String?>(null);
  final ValueNotifier<double> _zoom = ValueNotifier<double>(1.0);
  final ValueNotifier<bool> _dragEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  Timer? _loop;
  DateTime? _lastFrameAt;
  double _timeSeconds = 0;

  int _seed = 20260305;
  bool _cameraFitted = false;
  bool _hasScene = false;

  late DbSchemaScene _scene;
  late List<CanvasItem> _tableItems;
  final Map<String, DbTableDef> _tableById = <String, DbTableDef>{};

  @override
  void initState() {
    super.initState();
    _regenerate(seed: _seed, forcePreset: _preset.value);
    _startLoop();
  }

  @override
  void dispose() {
    _loop?.cancel();
    if (_hasScene) {
      _scene.dispose();
    }
    _preset.dispose();
    _selectedTableId.dispose();
    _zoom.dispose();
    _dragEnabled.dispose();
    _tick.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startLoop() {
    _lastFrameAt = DateTime.now();
    _loop = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) return;
      _fitCameraOnce();
      final now = DateTime.now();
      final previous = _lastFrameAt ?? now;
      _lastFrameAt = now;
      var dt =
          now.difference(previous).inMicroseconds /
          Duration.microsecondsPerSecond;
      dt = dt.clamp(0.0, 0.08);
      _timeSeconds += dt;
      _tick.value = _tick.value + 1;
    });
  }

  void _fitCameraOnce() {
    if (_cameraFitted || !_hasScene) return;
    final stats = _controller.camera.renderStats;
    if (stats == null || stats.viewportSize.isEmpty) return;

    final viewW = stats.viewportSize.width;
    final viewH = stats.viewportSize.height;
    final bounds = _scene.bounds;

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
    _zoom.value = scale;
    _cameraFitted = true;
  }

  void _regenerate({int? seed, DbSchemaPreset? forcePreset}) {
    _seed = seed ?? _seed;
    final preset = forcePreset ?? _preset.value;

    final next = generateDbSchemaScene(seed: _seed, preset: preset);
    if (_hasScene) {
      _scene.dispose();
    }
    _scene = next;
    _hasScene = true;

    _tableById
      ..clear()
      ..addEntries(_scene.tables.map((table) => MapEntry(table.id, table)));

    _tableItems = _buildTableItems();
    _selectedTableId.value = null;
    _cameraFitted = false;
    _tick.value = _tick.value + 1;
  }

  void _randomizeSeed() {
    final next = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    setState(() {
      _regenerate(seed: next);
    });
  }

  void _shuffleLayout() {
    final rng = math.Random(DateTime.now().microsecondsSinceEpoch);
    final updates = <String, Offset>{};
    for (final table in _scene.tables) {
      final current = table.position.value;
      final next =
          current +
          Offset(
            (rng.nextDouble() - 0.5) * 540,
            (rng.nextDouble() - 0.5) * 420,
          );
      table.position.value = next;
      updates[table.id] = next;
    }
    _controller.items.setWorldPositions(updates);
  }

  void _toggleDrag() {
    final enabled = !_dragEnabled.value;
    _dragEnabled.value = enabled;
    for (final table in _scene.tables) {
      _controller.items.setDragEnabled(table.id, enabled);
      if (!enabled) {
        table.dragging.value = false;
      }
    }
  }

  List<CanvasItem> _buildTableItems() {
    return [
      for (final table in _scene.tables)
        CanvasItem(
          id: table.id,
          worldPosition: table.position.value,
          size: CanvasItemSize.fromSize(table.size),
          dragEnabled: _dragEnabled.value,
          behavior: const CanvasItemBehavior(
            draggable: true,
            bringToFront: CanvasBringToFrontBehavior.onTapOrDragStart,
          ),
          onDragStart: (_) {
            table.dragging.value = true;
            _selectedTableId.value = table.id;
          },
          onDragUpdate: (event) {
            table.position.value = event.worldPosition;
          },
          onDragEnd: (event) {
            table.dragging.value = false;
            table.position.value = event.worldPosition;
          },
          onDragCancel: (event) {
            table.dragging.value = false;
            table.position.value = event.worldPosition;
          },
          child: SchemaTableCard(
            table: table,
            selectedTableId: _selectedTableId,
            onTap: () => _selectedTableId.value = table.id,
          ),
        ),
    ];
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A31),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2D446B)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFE5EEFF),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _topStrip() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _preset,
        _zoom,
        _dragEnabled,
        _selectedTableId,
      ]),
      builder: (context, _) {
        final selfRefs = _scene.relations.where((r) => r.selfReference).length;
        return Container(
          width: double.infinity,
          color: const Color(0xFF071225),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Seed $_seed'),
                const SizedBox(width: 8),
                _chip('Tables ${_scene.tables.length}'),
                const SizedBox(width: 8),
                _chip('Relations ${_scene.relations.length}'),
                const SizedBox(width: 8),
                _chip('Self refs $selfRefs'),
                const SizedBox(width: 8),
                _chip(_dragEnabled.value ? 'Drag on' : 'Drag off'),
                const SizedBox(width: 8),
                _chip('Zoom ${_zoom.value.toStringAsFixed(3)}'),
                const SizedBox(width: 8),
                _chip('Selected ${_selectedTableId.value ?? '-'}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _inspector(CanvasLayerController controller) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _selectedTableId,
        _zoom,
        controller.renderStatsListenable,
      ]),
      builder: (context, _) {
        final selected = _tableById[_selectedTableId.value];
        final stats = controller.renderStats;

        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 14, right: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xD1061224),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF35517C)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: Color(0xFFE4EDFF),
                    fontSize: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Schema Inspector',
                        style: TextStyle(
                          color: Color(0xFF9DE2FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Table ${selected?.name ?? '-'}'),
                      Text('Columns ${selected?.columns.length ?? '-'}'),
                      Text(
                        'PK ${selected?.columns.where((c) => c.primaryKey).length ?? '-'} '
                        'FK ${selected?.columns.where((c) => c.foreignKey).length ?? '-'}',
                      ),
                      Text(
                        'Visible ${stats?.visibleItems ?? 0} / '
                        '${stats?.totalItems ?? _scene.tables.length}',
                      ),
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
    final relationRepaint = Listenable.merge([
      _tick,
      _selectedTableId,
      ..._scene.tables.map((table) => table.position),
    ]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Schema Designer'),
        actions: [
          ValueListenableBuilder<DbSchemaPreset>(
            valueListenable: _preset,
            builder: (context, preset, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<DbSchemaPreset>(
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
                      for (final option in DbSchemaPreset.values)
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
          OutlinedButton(
            onPressed: _shuffleLayout,
            child: const Text('Shuffle'),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<bool>(
            valueListenable: _dragEnabled,
            builder: (context, enabled, _) {
              return OutlinedButton(
                onPressed: _toggleDrag,
                child: Text(enabled ? 'Drag: on' : 'Drag: off'),
              );
            },
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              _cameraFitted = false;
              _fitCameraOnce();
            },
            child: const Text('Fit schema'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _topStrip(),
          Expanded(
            child: InfinityCanvas(
              controller: _controller,
              enableCulling: true,
              cullPadding: 300,
              onZoomChanged: (value) {
                _zoom.value = value;
                return value;
              },
              layers: [
                CanvasLayer.painter(
                  id: 'schema-background',
                  painterBuilder: (transform) => DbSchemaBackgroundPainter(
                    transform: transform,
                    readTimeSeconds: () => _timeSeconds,
                    repaint: _tick,
                  ),
                ),
                CanvasLayer.painter(
                  id: 'schema-relations',
                  painterBuilder: (transform) => DbSchemaRelationsPainter(
                    transform: transform,
                    relations: _scene.relations,
                    tablesById: _tableById,
                    selectedTableId: _selectedTableId.value,
                    readTimeSeconds: () => _timeSeconds,
                    repaint: relationRepaint,
                  ),
                ),
                CanvasLayer.positionedItems(
                  id: 'schema-tables',
                  items: _tableItems,
                ),
                CanvasLayer.overlay(
                  id: 'schema-inspector',
                  ignorePointer: true,
                  builder: (context, transform, controller) {
                    return _inspector(controller);
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
