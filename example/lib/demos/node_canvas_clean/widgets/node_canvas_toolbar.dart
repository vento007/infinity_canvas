import 'package:flutter/material.dart';

import '../node_scene.dart';

class NodeCanvasToolbar extends StatelessWidget {
  final NodeCanvasDemoState demoState;
  final VoidCallback? onBack;
  final ValueChanged<bool> onToggleDrag;
  final VoidCallback onSpawnOne;
  final VoidCallback onSpawnHundred;
  final VoidCallback onSpawnThousand;
  final VoidCallback onSpawnTilted;
  final VoidCallback onFitNodes;
  final VoidCallback onJumpN0;
  final VoidCallback onAnimateN0;
  final VoidCallback onAnimateN0Center;

  const NodeCanvasToolbar({
    super.key,
    required this.demoState,
    this.onBack,
    required this.onToggleDrag,
    required this.onSpawnOne,
    required this.onSpawnHundred,
    required this.onSpawnThousand,
    required this.onSpawnTilted,
    required this.onFitNodes,
    required this.onJumpN0,
    required this.onAnimateN0,
    required this.onAnimateN0Center,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 4),
          ValueListenableBuilder(
            valueListenable:
                demoState.canvasController.camera.renderStatsListenable,
            builder: (context, _, _) {
              final zoom = demoState.canvasController.camera.scale;
              final stats = demoState.canvasController.camera.renderStats;
              final visible = stats?.visibleItems ?? 0;
              final total = stats?.totalItems ?? demoState.nodeCount;
              return Text(
                'Zoom: ${zoom.toStringAsFixed(3)}  Visible: $visible/$total',
              );
            },
          ),
          const SizedBox(width: 12),
          Text('Nodes: ${demoState.nodeCount}'),
          const SizedBox(width: 12),
          Text(demoState.nodesDraggable ? 'Drag: on' : 'Drag: off'),
          const SizedBox(width: 6),
          Switch(value: demoState.nodesDraggable, onChanged: onToggleDrag),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: onSpawnOne,
            child: const Text('Spawn +1'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onSpawnHundred,
            child: const Text('Spawn +100'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onSpawnThousand,
            child: const Text('Spawn +1000'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onSpawnTilted,
            child: const Text('Tilt'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onFitNodes,
            child: const Text('Fit Nodes'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(onPressed: onJumpN0, child: const Text('Jump N0')),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onAnimateN0,
            child: const Text('Animate N0'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onAnimateN0Center,
            child: const Text('Animate N0 Center'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Last: ${demoState.lastEvent}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
