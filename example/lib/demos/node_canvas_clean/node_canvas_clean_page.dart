import 'package:infinity_canvas/infinity_canvas.dart';
import 'package:flutter/material.dart';

import 'layers/background_grid_layer.dart';
import 'layers/minimap_layer.dart';
import 'node_layers.dart';
import 'node_scene.dart';
import 'widgets/node_canvas_toolbar.dart';

class NodeCanvasCleanPage extends StatefulWidget {
  const NodeCanvasCleanPage({super.key});

  @override
  State<NodeCanvasCleanPage> createState() => _NodeCanvasCleanPageState();
}

class _NodeCanvasCleanPageState extends State<NodeCanvasCleanPage> {
  static const double _initialZoom = 1.32;
  static const Offset _initialWorldTopLeft = Offset(-3740, -2920);
  static const bool _enableLinksLayer = true;
  static const bool _enableMiniMapLayer = true;
  static const MiniMapBoundsMode _miniMapBoundsMode =
      MiniMapBoundsMode.cameraAware;

  late final CanvasController _canvasController;
  late final NodeCanvasDemoState _demoState;

  @override
  void initState() {
    super.initState();
    _canvasController = CanvasController(
      initialZoom: _initialZoom,
      initialWorldTopLeft: _initialWorldTopLeft,
    );
    _demoState = NodeCanvasDemoState(canvasController: _canvasController);
  }

  @override
  void dispose() {
    _demoState.dispose();
    _canvasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _demoState,
      builder: (context, _) {
        return Scaffold(
          body: Column(
            children: [
              NodeCanvasToolbar(
                demoState: _demoState,
                onBack: () => Navigator.of(context).maybePop(),
                onToggleDrag: _demoState.setNodesDraggable,
                onSpawnOne: _demoState.spawnOne,
                onSpawnHundred: _demoState.spawnHundred,
                onSpawnThousand: _demoState.spawnThousand,
                onSpawnTilted: _demoState.spawnTiltedOne,
                onFitNodes: _demoState.fitAllNodes,
                onJumpN0: () => _demoState.jumpToN0(zoom: 1.2),
                onAnimateN0: () => _demoState.animateToN0(zoom: 1.2),
                onAnimateN0Center: () =>
                    _demoState.animateToN0Center(zoom: 1.2),
              ),
              Expanded(
                child: Center(
                  child: InfinityCanvas(
                    controller: _canvasController,
                    enableCulling: true,
                    cullPadding: 160,
                    onZoomChanged: _demoState.updateZoom,
                    layers: [
                      CanvasLayer.painter(
                        id: 'bg-grid',
                        painterBuilder: buildBackgroundGridPainter,
                      ),
                      if (_enableLinksLayer)
                        CanvasLayer.painter(
                          id: 'node-links',
                          painterBuilder: buildLinksPainterBuilder(_demoState),
                        ),
                      CanvasLayer.positionedItems(
                        id: 'node-items',
                        items: _demoState.nodeItems,
                      ),
                      if (_enableMiniMapLayer)
                        CanvasLayer.overlay(
                          id: 'node-mini-map',
                          ignorePointer: false,
                          builder: buildMiniMapLayerBuilder(
                            _demoState,
                            boundsMode: _miniMapBoundsMode,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
