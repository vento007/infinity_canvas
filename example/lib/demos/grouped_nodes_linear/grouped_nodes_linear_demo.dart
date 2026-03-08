import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

import 'grouped_nodes_linear_data.dart';
import 'grouped_nodes_linear_painters.dart';
import 'widgets/grouped_group_backdrop.dart';

class GroupedNodesLinearDemoPage extends StatefulWidget {
  const GroupedNodesLinearDemoPage({super.key});

  @override
  State<GroupedNodesLinearDemoPage> createState() =>
      _GroupedNodesLinearDemoPageState();
}

class _GroupedNodesLinearDemoPageState
    extends State<GroupedNodesLinearDemoPage> {
  late final CanvasController _controller;
  late final List<CanvasItem> _nodeItems;
  late final List<LinearUserSpaceGroupSpec> _groups;
  late final List<CanvasItem> _backdropItems;
  String _lastEvent = '-';

  @override
  void initState() {
    super.initState();
    _controller = CanvasController(
      initialZoom: 1.0,
      initialWorldTopLeft: const Offset(-420, -180),
    );
    _nodeItems = buildGroupedNodesLinearItems(onEvent: _setLastEvent);
    _groups = buildGroupedNodesLinearGroups();
    _backdropItems = _groups.map(_buildBackdropItem).toList(growable: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setLastEvent(String text) {
    if (!mounted) return;
    setState(() {
      _lastEvent = text;
    });
  }

  void _fitAllItems() {
    _controller.camera.fitAllItems(worldPadding: 80);
    _setLastEvent('fit all items');
  }

  CanvasItem _buildBackdropItem(LinearUserSpaceGroupSpec group) {
    return CanvasItem(
      id: 'backdrop-${group.id}',
      worldPosition: group.rect.topLeft,
      size: CanvasItemSize.fromSize(group.rect.size),
      behavior: const CanvasItemBehavior(
        draggable: true,
        bringToFront: CanvasBringToFrontBehavior.never,
      ),
      onDragStart: (_) => _setLastEvent('drag ${group.id}'),
      onDragUpdate: (event) {
        final delta = event.worldDelta;
        if (delta == null || delta == Offset.zero) return;
        final nextPositions = <String, Offset>{};
        for (final itemId in group.itemIds) {
          final current = _controller.items.getWorldPosition(itemId);
          if (current != null) {
            nextPositions[itemId] = current + delta;
          }
        }
        _controller.items.setWorldPositions(nextPositions);
      },
      onDragEnd: (_) => _setLastEvent('drop ${group.id}'),
      onDragCancel: (_) => _setLastEvent('cancel ${group.id}'),
      child: GroupedGroupBackdrop(
        title: group.title,
        fillColor: group.fillColor,
        borderColor: group.borderColor,
        headerColor: group.headerColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grouped Nodes (Linear)'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFFF3F4F6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                FilledButton.tonal(
                  onPressed: _fitAllItems,
                  child: const Text('Fit All'),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'User-space grouping demo: the backdrops are normal CanvasItems. Their onDragUpdate callbacks move multiple node ids with controller.items.setWorldPositions(...).',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text('Last: $_lastEvent'),
              ],
            ),
          ),
          Expanded(
            child: InfinityCanvas(
              controller: _controller,
              enableCulling: true,
              cullPadding: 160,
              layers: [
                CanvasLayer.painter(
                  id: 'background',
                  painterBuilder: (_) => const GroupedNodesLinearGridPainter(),
                ),
                CanvasLayer.positionedItems(
                  id: 'backdrops',
                  items: _backdropItems,
                ),
                CanvasLayer.positionedItems(id: 'items', items: _nodeItems),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
