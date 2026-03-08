import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

import 'widgets/grouped_node_card.dart';

typedef GroupedNodesEventSink = void Function(String text);

class LinearUserSpaceGroupSpec {
  final String id;
  final String title;
  final Rect rect;
  final Set<String> itemIds;
  final Color fillColor;
  final Color borderColor;
  final Color headerColor;

  const LinearUserSpaceGroupSpec({
    required this.id,
    required this.title,
    required this.rect,
    required this.itemIds,
    required this.fillColor,
    required this.borderColor,
    required this.headerColor,
  });
}

List<CanvasItem> buildGroupedNodesLinearItems({
  required GroupedNodesEventSink onEvent,
}) {
  return <CanvasItem>[
    _buildItem(
      id: 'n1',
      title: 'Input',
      position: const Offset(-120, -40),
      color: const Color(0xFF2563EB),
      onEvent: onEvent,
    ),
    _buildItem(
      id: 'n2',
      title: 'Parse',
      position: const Offset(130, 10),
      color: const Color(0xFF2563EB),
      onEvent: onEvent,
    ),
    _buildItem(
      id: 'n3',
      title: 'Validate',
      position: const Offset(380, 40),
      color: const Color(0xFF2563EB),
      onEvent: onEvent,
    ),
    _buildItem(
      id: 'n4',
      title: 'Cache',
      position: const Offset(120, 290),
      color: const Color(0xFF7C3AED),
      onEvent: onEvent,
    ),
    _buildItem(
      id: 'n5',
      title: 'Queue',
      position: const Offset(360, 310),
      color: const Color(0xFF7C3AED),
      onEvent: onEvent,
    ),
    _buildItem(
      id: 'n6',
      title: 'Audit',
      position: const Offset(650, 180),
      color: const Color(0xFFEA580C),
      onEvent: onEvent,
    ),
  ];
}

List<LinearUserSpaceGroupSpec> buildGroupedNodesLinearGroups() {
  return const <LinearUserSpaceGroupSpec>[
    LinearUserSpaceGroupSpec(
      id: 'group-flow',
      title: 'Flow Column',
      rect: Rect.fromLTWH(-180, -120, 760, 260),
      itemIds: <String>{'n1', 'n2', 'n3'},
      fillColor: Color(0x1422C55E),
      borderColor: Color(0xFF22C55E),
      headerColor: Color(0x2234D399),
    ),
    LinearUserSpaceGroupSpec(
      id: 'group-runtime',
      title: 'Runtime Services',
      rect: Rect.fromLTWH(40, 220, 520, 220),
      itemIds: <String>{'n4', 'n5'},
      fillColor: Color(0x147C3AED),
      borderColor: Color(0xFF8B5CF6),
      headerColor: Color(0x226D28D9),
    ),
  ];
}

CanvasItem _buildItem({
  required String id,
  required String title,
  required Offset position,
  required Color color,
  required GroupedNodesEventSink onEvent,
}) {
  return CanvasItem(
    id: id,
    worldPosition: position,
    behavior: const CanvasItemBehavior.nodeEditor(),
    onDragStart: (_) => onEvent('drag $id'),
    onDragEnd: (_) => onEvent('drop $id'),
    onDragCancel: (_) => onEvent('cancel $id'),
    child: GroupedNodeCard(title: title, id: id, color: color),
  );
}
