import 'package:flutter/material.dart';

import 'demos/docking_windows/docking_windows_demo.dart';
import 'demos/db_schema_designer/db_schema_designer_demo.dart';
import 'demos/galaxy_trade_map/galaxy_trade_map_demo.dart';
import 'demos/grouped_nodes_linear/grouped_nodes_linear_demo.dart';
import 'demos/input_smoke/input_smoke_demo.dart';
import 'demos/massive_widget_art_scene/massive_widget_art_scene_demo.dart';
import 'demos/minimal_items/minimal_items_demo.dart';
import 'demos/node_canvas_clean/node_canvas_clean_page.dart';
import 'demos/orbital_constellation/orbital_constellation_demo.dart';
import 'demos/painted_item_widgets/painted_item_widgets_demo.dart';
import 'demos/tower_defense/tower_defense_demo.dart';

void main() {
  runApp(const InfinityCanvasExampleApp());
}

class InfinityCanvasExampleApp extends StatelessWidget {
  const InfinityCanvasExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Infinity Canvas Examples',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B7285)),
      ),
      home: const DemoMenuPage(),
    );
  }
}

class DemoMenuPage extends StatelessWidget {
  const DemoMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infinity Canvas Examples'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DemoTile(
            title: 'Docking Windows',
            subtitle:
                'ImGui-style window shells; drag from title bar/tab area only.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DockingWindowsDemoPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _DemoTile(
            title: 'Database Schema Designer',
            subtitle:
                'ERD-style table cards with FK links, including self-referencing relations.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DbSchemaDesignerDemoPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _DemoTile(
            title: 'Grouped Nodes (Linear)',
            subtitle:
                'User-space grouping: draggable backdrop items move multiple nodes without CanvasLayer.groups.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GroupedNodesLinearDemoPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _DemoTile(
            title: 'Minimal Items',
            subtitle:
                'Single CanvasLayer.items + direct CanvasItem child widget.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MinimalItemsDemoPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _DemoTile(
            title: 'Painted Item Widgets',
            subtitle: 'CanvasItem child is a CustomPaint-based widget.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PaintedItemWidgetsDemoPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _DemoTile(
            title: 'Node Canvas (Clean)',
            subtitle: 'Widget-items only (no painter batch overlay logic).',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NodeCanvasCleanPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _DemoTile(
            title: 'Tower Defense',
            subtitle:
                'Playable TD demo with ECS, shaders, and camera controls.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TowerDefenseDemoPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _DemoTile(
            title: 'Massive Multi-Widget Art Scene',
            subtitle:
                'Seeded procedural mega-scene with layered motion and large-scale visuals.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MassiveWidgetArtSceneDemoPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _DemoTile(
            title: 'Galaxy Trade Map',
            subtitle:
                'Neon star systems, flowing trade lanes, and animated shipments at scale.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GalaxyTradeMapDemoPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _DemoTile(
            title: 'Orbital Constellation',
            subtitle:
                'Procedural orbiting worlds with painter cosmos + widget planets at scale.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OrbitalConstellationDemoPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _DemoTile(
            title: 'Input Smoke',
            subtitle:
                'Pan, wheel, pinch, and trackpad behavior with explicit toggles and presets.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const InputSmokeDemoPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DemoTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
