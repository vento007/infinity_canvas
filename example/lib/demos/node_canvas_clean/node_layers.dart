import 'package:infinity_canvas/infinity_canvas.dart';

import 'node_scene.dart';
import 'painters.dart';

CanvasTransformPainterBuilder buildLinksPainterBuilder(
  NodeCanvasDemoState demoState,
) {
  final repaint = demoState.linksRepaintListenable();
  return (transform) => NodeLinksPainter(
    nodes: demoState.nodes,
    columns: NodeCanvasDemoState.gridColumns,
    worldPositionOf: demoState.worldPositionFor,
    transform: transform,
    repaintListenable: repaint,
  );
}
