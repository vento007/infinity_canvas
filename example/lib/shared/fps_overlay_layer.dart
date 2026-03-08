import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

CanvasTransformWidgetBuilder buildPerformanceOverlayLayerBuilder({
  Alignment alignment = Alignment.topRight,
  EdgeInsets padding = const EdgeInsets.all(12),
  Duration sampleWindow = const Duration(seconds: 1),
  Size overlaySize = const Size(240, 180),
}) {
  return (context, _, controller) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: RepaintBoundary(
          child: _PerformanceOverlayCard(
            controller: controller,
            sampleWindow: sampleWindow,
            overlaySize: overlaySize,
          ),
        ),
      ),
    );
  };
}

CanvasTransformWidgetBuilder buildFpsOverlayLayerBuilder({
  Alignment alignment = Alignment.topRight,
  EdgeInsets padding = const EdgeInsets.all(12),
  Duration sampleWindow = const Duration(seconds: 1),
  Size overlaySize = const Size(240, 180),
}) {
  return buildPerformanceOverlayLayerBuilder(
    alignment: alignment,
    padding: padding,
    sampleWindow: sampleWindow,
    overlaySize: overlaySize,
  );
}

class _PerformanceOverlayCard extends StatefulWidget {
  final CanvasLayerController controller;
  final Duration sampleWindow;
  final Size overlaySize;

  const _PerformanceOverlayCard({
    required this.controller,
    required this.sampleWindow,
    required this.overlaySize,
  });

  @override
  State<_PerformanceOverlayCard> createState() =>
      _PerformanceOverlayCardState();
}

class _PerformanceOverlayCardState extends State<_PerformanceOverlayCard> {
  static const _idleTimeout = Duration(milliseconds: 900);
  static const _goodFps = 55.0;
  static const _okayFps = 40.0;

  final Stopwatch _sampleStopwatch = Stopwatch()..start();
  Timer? _idleTimer;

  int _windowFrames = 0;
  double _windowBuildMs = 0;
  double _windowRasterMs = 0;
  double _windowTotalMs = 0;

  double _fps = 0;
  double _avgBuildMs = 0;
  double _avgRasterMs = 0;
  double _avgTotalMs = 0;
  bool _idle = true;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    _armIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    super.dispose();
  }

  void _armIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      if (!mounted || _idle) return;
      _windowFrames = 0;
      _windowBuildMs = 0;
      _windowRasterMs = 0;
      _windowTotalMs = 0;
      _sampleStopwatch
        ..reset()
        ..start();
      setState(() => _idle = true);
    });
  }

  void _resetSampleWindow() {
    _windowFrames = 0;
    _windowBuildMs = 0;
    _windowRasterMs = 0;
    _windowTotalMs = 0;
    _sampleStopwatch
      ..reset()
      ..start();
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!mounted || timings.isEmpty) return;

    if (_idle) {
      setState(() => _idle = false);
    }
    _armIdleTimer();

    for (final timing in timings) {
      _windowFrames++;
      _windowBuildMs += timing.buildDuration.inMicroseconds / 1000.0;
      _windowRasterMs += timing.rasterDuration.inMicroseconds / 1000.0;
      _windowTotalMs += timing.totalSpan.inMicroseconds / 1000.0;
    }

    final elapsed = _sampleStopwatch.elapsed;
    if (elapsed < widget.sampleWindow || _windowFrames == 0) return;

    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final nextFps = seconds > 0 ? _windowFrames / seconds : 0.0;
    final nextBuildMs = _windowBuildMs / _windowFrames;
    final nextRasterMs = _windowRasterMs / _windowFrames;
    final nextTotalMs = _windowTotalMs / _windowFrames;

    _resetSampleWindow();
    setState(() {
      _fps = nextFps;
      _avgBuildMs = nextBuildMs;
      _avgRasterMs = nextRasterMs;
      _avgTotalMs = nextTotalMs;
    });
  }

  Color _fpsColor(double fps) {
    if (fps >= _goodFps) return const Color(0xFF73FFA6);
    if (fps >= _okayFps) return const Color(0xFFFFE082);
    return const Color(0xFFFF8A80);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CanvasKitRenderStats?>(
      valueListenable: widget.controller.camera.renderStatsListenable,
      builder: (context, stats, _) {
        final visible = stats?.visibleItems ?? widget.controller.visibleItems;
        final total = stats?.totalItems ?? widget.controller.totalItems;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC0F172A),
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox(
            width: widget.overlaySize.width,
            height: widget.overlaySize.height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    child: kIsWeb
                        ? const ColoredBox(
                            color: Color(0xFF111827),
                            child: Center(
                              child: Text(
                                'FrameTiming metrics only on web',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        : PerformanceOverlay.allEnabled(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.speed,
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            if (_idle)
                              const Text(
                                'idle',
                                style: TextStyle(color: Colors.white38),
                              )
                            else
                              Text(
                                '${_fps.toStringAsFixed(1)} fps',
                                style: TextStyle(color: _fpsColor(_fps)),
                              ),
                            const Spacer(),
                            Text('vis $visible/$total'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'build ${_avgBuildMs.toStringAsFixed(2)} ms  '
                          'raster ${_avgRasterMs.toStringAsFixed(2)} ms',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'total ${_avgTotalMs.toStringAsFixed(2)} ms',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
