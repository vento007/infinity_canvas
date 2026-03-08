import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:tiny_ecs/tiny_ecs.dart';

import 'mega_components.dart';

class TdMegaMapEngine {
  TdMegaMapEngine({
    int seed = 20260305,
    int laneCount = 12,
    int creepsPerLane = 140,
    int segmentCount = 14,
  }) {
    regenerate(
      seed: seed,
      laneCount: laneCount,
      creepsPerLane: creepsPerLane,
      segmentCount: segmentCount,
    );
  }

  World _world = World();
  Rect _boardBounds = const Rect.fromLTWH(-6000, -3200, 12000, 6400);
  List<MegaLanePath> _lanes = const <MegaLanePath>[];
  List<Offset> _towerPads = const <Offset>[];

  final ValueNotifier<int> tick = ValueNotifier<int>(0);
  final ValueNotifier<int> seedValue = ValueNotifier<int>(0);
  final ValueNotifier<int> laneCountValue = ValueNotifier<int>(0);
  final ValueNotifier<int> padCountValue = ValueNotifier<int>(0);
  final ValueNotifier<int> towerCountValue = ValueNotifier<int>(0);
  final ValueNotifier<int> creepCountValue = ValueNotifier<int>(0);
  final ValueNotifier<bool> running = ValueNotifier<bool>(true);

  double laneWorldWidth = 120.0;

  World get world => _world;
  Rect get boardBounds => _boardBounds;
  List<MegaLanePath> get lanes => _lanes;
  List<Offset> get towerPads => _towerPads;

  void setRunning(bool value) {
    if (running.value == value) return;
    running.value = value;
  }

  void regenerate({
    required int seed,
    required int laneCount,
    required int creepsPerLane,
    required int segmentCount,
    double towerFill = 0.34,
  }) {
    final rng = math.Random(seed);
    _world = World();
    _boardBounds = _generateBoardBounds(
      rng: rng,
      laneCount: laneCount,
      creepsPerLane: creepsPerLane,
    );
    laneWorldWidth = (95 + rng.nextDouble() * 50).clamp(90.0, 170.0);
    _lanes = _generateLanes(
      rng: rng,
      bounds: _boardBounds,
      laneCount: laneCount,
      segmentCount: segmentCount,
    );
    _towerPads = _generatePads(
      rng: rng,
      bounds: _boardBounds,
      lanes: _lanes,
      laneWorldWidth: laneWorldWidth,
    );

    _spawnTowers(rng: rng, towerFill: towerFill);
    _spawnCreeps(rng: rng, creepsPerLane: creepsPerLane);

    seedValue.value = seed;
    laneCountValue.value = _lanes.length;
    padCountValue.value = _towerPads.length;
    towerCountValue.value = _world.query<MegaTowerC>().length;
    creepCountValue.value = _world.query<MegaCreepC>().length;
    tick.value = tick.value + 1;
  }

  void step(double dt) {
    if (!running.value || _lanes.isEmpty || dt <= 0) return;
    final frameDt = dt.clamp(0.0, 0.05);

    for (final q in _world.query2<MegaPositionC, MegaLaneFollowerC>()) {
      final pos = q.component1;
      final follower = q.component2;
      if (_lanes.isEmpty) continue;
      final lane = _lanes[follower.laneIndex % _lanes.length];
      final laneLength = lane.totalLength;
      if (laneLength <= 1e-9) continue;

      follower.distance += follower.speed * frameDt;
      while (follower.distance >= laneLength) {
        follower.distance -= laneLength;
      }
      pos.offset = lane.sampleByDistance(follower.distance);
    }

    tick.value = tick.value + 1;
  }

  void dispose() {
    tick.dispose();
    seedValue.dispose();
    laneCountValue.dispose();
    padCountValue.dispose();
    towerCountValue.dispose();
    creepCountValue.dispose();
    running.dispose();
  }

  Rect _generateBoardBounds({
    required math.Random rng,
    required int laneCount,
    required int creepsPerLane,
  }) {
    final width = 9000 + laneCount * 260 + (creepsPerLane * 8);
    final height = 3600 + laneCount * 210 + (rng.nextDouble() * 700);
    return Rect.fromCenter(
      center: Offset.zero,
      width: width.toDouble(),
      height: height.toDouble(),
    );
  }

  List<MegaLanePath> _generateLanes({
    required math.Random rng,
    required Rect bounds,
    required int laneCount,
    required int segmentCount,
  }) {
    if (laneCount <= 0) return const <MegaLanePath>[];
    final lanes = <MegaLanePath>[];
    final topMargin = 230.0;
    final leftMargin = 210.0;
    final usableHeight = math.max(200.0, bounds.height - topMargin * 2);
    final spacing = usableHeight / laneCount;

    for (var laneIndex = 0; laneIndex < laneCount; laneIndex++) {
      final points = <Offset>[];
      final yCenter = bounds.top + topMargin + spacing * (laneIndex + 0.5);
      final startY = yCenter + (rng.nextDouble() * 140 - 70);
      final endY = yCenter + (rng.nextDouble() * 140 - 70);
      final amp = spacing * (0.32 + rng.nextDouble() * 0.44);
      final freq = 0.9 + rng.nextDouble() * 1.8;
      final phase = rng.nextDouble() * math.pi * 2;
      final noiseAmp = 42 + rng.nextDouble() * 58;
      final segments = math.max(8, segmentCount + rng.nextInt(4) - 1);
      final minY = bounds.top + topMargin;
      final maxY = bounds.bottom - topMargin;

      for (var i = 0; i <= segments; i++) {
        final t = i / segments;
        final x = lerpDouble(
          bounds.left + leftMargin,
          bounds.right - leftMargin,
          t,
        )!;
        final baseline = lerpDouble(startY, endY, t)!;
        final wave = math.sin(t * freq * math.pi * 2 + phase) * amp;
        final noise = (rng.nextDouble() * 2 - 1) * noiseAmp;
        final y = (baseline + wave + noise).clamp(minY, maxY).toDouble();
        points.add(Offset(x, y));
      }

      var smoothed = points;
      smoothed = _chaikinSmooth(smoothed);
      smoothed = _chaikinSmooth(smoothed);
      lanes.add(MegaLanePath.fromPoints(smoothed));
    }

    return lanes;
  }

  List<Offset> _generatePads({
    required math.Random rng,
    required Rect bounds,
    required List<MegaLanePath> lanes,
    required double laneWorldWidth,
  }) {
    final pads = <Offset>[];
    final laneOffsetMin = laneWorldWidth * 0.5 + 100;
    final laneOffsetMax = laneWorldWidth * 0.5 + 182;
    final minPadDistanceSq = 145.0 * 145.0;
    final allowed = bounds.deflate(170);

    for (final lane in lanes) {
      final laneLength = lane.totalLength;
      if (laneLength <= 600) continue;
      var d = 240.0 + rng.nextDouble() * 140;
      while (d < laneLength - 240) {
        final center = lane.sampleByDistance(d);
        final tangent = lane.tangentByDistance(d);
        var normal = Offset(-tangent.dy, tangent.dx);
        if (normal.distanceSquared <= 1e-12) {
          normal = const Offset(0, 1);
        } else {
          normal = normal / normal.distance;
        }
        final side = rng.nextBool() ? 1.0 : -1.0;
        final offset =
            laneOffsetMin + rng.nextDouble() * (laneOffsetMax - laneOffsetMin);
        final candidate = center + normal * (offset * side);

        if (allowed.contains(candidate) &&
            _isFarEnough(candidate, pads, minPadDistanceSq)) {
          pads.add(candidate);
        }

        d += 230 + rng.nextDouble() * 140;
      }
    }

    return pads;
  }

  bool _isFarEnough(Offset candidate, List<Offset> existing, double minSq) {
    for (final p in existing) {
      final dx = p.dx - candidate.dx;
      final dy = p.dy - candidate.dy;
      if (dx * dx + dy * dy < minSq) return false;
    }
    return true;
  }

  void _spawnTowers({required math.Random rng, required double towerFill}) {
    final fill = towerFill.clamp(0.0, 1.0);
    for (final pad in _towerPads) {
      if (rng.nextDouble() > fill) continue;
      final tower = _world.createEntity();
      _world.addComponent(tower, MegaPositionC(pad.dx, pad.dy));
      _world.addComponent(
        tower,
        MegaTowerC(
          radius: 18 + rng.nextDouble() * 6,
          range: 150 + rng.nextDouble() * 65,
        ),
      );
    }
  }

  void _spawnCreeps({required math.Random rng, required int creepsPerLane}) {
    if (_lanes.isEmpty || creepsPerLane <= 0) return;
    for (var laneIndex = 0; laneIndex < _lanes.length; laneIndex++) {
      final lane = _lanes[laneIndex];
      final laneLength = lane.totalLength;
      if (laneLength <= 1e-9) continue;

      final spacing = laneLength / creepsPerLane;
      for (var i = 0; i < creepsPerLane; i++) {
        final jitter = (rng.nextDouble() * 2 - 1) * spacing * 0.28;
        var distance = (i * spacing + jitter) % laneLength;
        if (distance < 0) distance += laneLength;
        final pos = lane.sampleByDistance(distance);
        final speed = 62 + rng.nextDouble() * 74;

        final creep = _world.createEntity();
        _world.addComponent(creep, MegaPositionC(pos.dx, pos.dy));
        _world.addComponent(
          creep,
          MegaLaneFollowerC(
            laneIndex: laneIndex,
            distance: distance,
            speed: speed,
          ),
        );
        _world.addComponent(
          creep,
          MegaCreepC(
            radius: 7.0 + rng.nextDouble() * 3.8,
            hue:
                (laneIndex * (360.0 / _lanes.length) + rng.nextDouble() * 18) %
                360,
          ),
        );
      }
    }
  }
}

class MegaLanePath {
  final List<Offset> points;
  final List<double> cumulativeLengths;
  final double totalLength;

  const MegaLanePath._({
    required this.points,
    required this.cumulativeLengths,
    required this.totalLength,
  });

  factory MegaLanePath.fromPoints(List<Offset> points) {
    if (points.length < 2) {
      final fallback = points.isEmpty ? const <Offset>[Offset.zero] : points;
      return MegaLanePath._(
        points: fallback,
        cumulativeLengths: const <double>[0],
        totalLength: 0,
      );
    }

    final cumulative = <double>[0.0];
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
      cumulative.add(total);
    }
    return MegaLanePath._(
      points: points,
      cumulativeLengths: cumulative,
      totalLength: total,
    );
  }

  Offset sampleByDistance(double distance) {
    if (points.isEmpty) return Offset.zero;
    if (points.length == 1 || totalLength <= 1e-9) return points.first;

    final d = _wrapDistance(distance);
    final segment = _segmentIndex(d);
    final a = points[segment];
    final b = points[segment + 1];
    final start = cumulativeLengths[segment];
    final end = cumulativeLengths[segment + 1];
    final segLen = (end - start).abs();
    if (segLen <= 1e-9) return a;
    final t = ((d - start) / segLen).clamp(0.0, 1.0);
    return Offset.lerp(a, b, t)!;
  }

  Offset tangentByDistance(double distance) {
    if (points.length < 2 || totalLength <= 1e-9) return const Offset(1, 0);
    final d = _wrapDistance(distance);
    final segment = _segmentIndex(d);
    final delta = points[segment + 1] - points[segment];
    final len = delta.distance;
    if (len <= 1e-9) return const Offset(1, 0);
    return delta / len;
  }

  double _wrapDistance(double distance) {
    if (totalLength <= 1e-9) return 0;
    var d = distance % totalLength;
    if (d < 0) d += totalLength;
    return d;
  }

  int _segmentIndex(double distance) {
    for (var i = 0; i < cumulativeLengths.length - 1; i++) {
      final start = cumulativeLengths[i];
      final end = cumulativeLengths[i + 1];
      if (distance >= start && distance <= end) {
        return i;
      }
    }
    return math.max(0, cumulativeLengths.length - 2);
  }
}

List<Offset> _chaikinSmooth(List<Offset> points) {
  if (points.length < 3) return points;
  final out = <Offset>[points.first];
  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    out.add(Offset.lerp(a, b, 0.25)!);
    out.add(Offset.lerp(a, b, 0.75)!);
  }
  out.add(points.last);
  return out;
}
