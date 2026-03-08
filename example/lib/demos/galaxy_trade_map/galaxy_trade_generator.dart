import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'galaxy_trade_models.dart';

GalaxyTradeGenerated generateGalaxyTradeScene({
  required int seed,
  int systemCount = 120,
  int shipmentCount = 340,
  int clusterCount = 6,
}) {
  final rng = math.Random(seed);
  const bounds = Rect.fromLTWH(-6200, -4600, 12400, 9200);
  final coreCenter = bounds.center;
  final haloRadiusX = bounds.width * 0.5 + 8200;
  final haloRadiusY = bounds.height * 0.5 + 7200;

  final factionPalette = <Color>[
    const Color(0xFF6EE7F9),
    const Color(0xFF3B82F6),
    const Color(0xFFF59E0B),
    const Color(0xFFEF4444),
    const Color(0xFF8B5CF6),
    const Color(0xFF22C55E),
  ];

  final clusterCenters = <Offset>[
    for (var i = 0; i < clusterCount; i++)
      Offset(
        _randRange(rng, bounds.left + 1200, bounds.right - 1200),
        _randRange(rng, bounds.top + 900, bounds.bottom - 900),
      ),
  ];

  final systems = <GalaxySystem>[];
  for (var i = 0; i < systemCount; i++) {
    final anchor = clusterCenters[rng.nextInt(clusterCenters.length)];
    final angle = rng.nextDouble() * math.pi * 2;
    final radius =
        math.pow(rng.nextDouble(), 0.58).toDouble() *
        _randRange(rng, 520, 1900);
    final spreadX = _randRange(rng, 0.65, 1.35);
    final spreadY = _randRange(rng, 0.60, 1.25);

    final x = (anchor.dx + math.cos(angle) * radius * spreadX).clamp(
      bounds.left,
      bounds.right,
    );
    final y = (anchor.dy + math.sin(angle) * radius * spreadY).clamp(
      bounds.top,
      bounds.bottom,
    );

    final faction = factionPalette[rng.nextInt(factionPalette.length)];

    systems.add(
      GalaxySystem(
        id: 'S$i',
        name: _buildSystemName(rng),
        center: Offset(x.toDouble(), y.toDouble()),
        factionColor: faction,
        supply: _randRange(rng, 10, 99),
        demand: _randRange(rng, 10, 99),
        influence: _randRange(rng, 0.25, 1.0),
      ),
    );
  }

  final routes = _buildRoutes(rng, systems);

  final nebulas = <GalaxyNebula>[
    for (var i = 0; i < 22; i++)
      () {
        final depth = math.pow(rng.nextDouble(), 0.75).toDouble();
        final radialBias = rng.nextDouble() < 0.82 ? 1.65 : 0.58;
        final center = _sampleHaloPoint(
          rng,
          center: coreCenter,
          radiusX: haloRadiusX,
          radiusY: haloRadiusY,
          radialBias: radialBias,
        );
        final radiusBase = radialBias > 1.0
            ? _randRange(rng, 820, 2200)
            : _randRange(rng, 1200, 3000);
        return GalaxyNebula(
          center: center,
          radius: radiusBase,
          color: HSLColor.fromAHSL(
            1,
            _randRange(rng, 180, 330),
            _randRange(rng, 0.65, 0.90),
            _randRange(rng, 0.46, 0.70),
          ).toColor(),
          phase: _randRange(rng, 0, math.pi * 2),
          depth: depth,
        );
      }(),
  ];

  final dustMotes = <GalaxyDustMote>[
    for (var i = 0; i < 850; i++)
      () {
        final depth = math.pow(rng.nextDouble(), 1.15).toDouble();
        final radialBias = rng.nextDouble() < 0.84 ? 1.5 : 0.62;
        final pos = _sampleHaloPoint(
          rng,
          center: coreCenter,
          radiusX: haloRadiusX,
          radiusY: haloRadiusY,
          radialBias: radialBias,
        );
        final hue = rng.nextBool()
            ? _randRange(rng, 186, 232)
            : _randRange(rng, 26, 54);
        return GalaxyDustMote(
          position: pos,
          size: _randRange(rng, 0.55, 1.80),
          depth: depth,
          phase: _randRange(rng, 0, math.pi * 2),
          flickerSpeed: _randRange(rng, 0.05, 0.22),
          color: HSLColor.fromAHSL(
            1,
            hue,
            _randRange(rng, 0.10, 0.42),
            _randRange(rng, 0.74, 0.94),
          ).toColor(),
        );
      }(),
  ];

  final stars = <GalaxyStar>[
    for (var i = 0; i < 3600; i++)
      () {
        final depth = math.pow(rng.nextDouble(), 1.35).toDouble();
        final radialBias = rng.nextDouble() < 0.72 ? 1.85 : 0.52;
        final starPos = _sampleHaloPoint(
          rng,
          center: coreCenter,
          radiusX: haloRadiusX,
          radiusY: haloRadiusY,
          radialBias: radialBias,
        );
        return GalaxyStar(
          position: starPos,
          magnitude: _randRange(rng, 0.28, 1.58),
          twinkleSpeed: _randRange(rng, 0.45, 2.20),
          phase: _randRange(rng, 0, math.pi * 2),
          color: HSLColor.fromAHSL(
            1,
            rng.nextBool()
                ? _randRange(rng, 188, 246)
                : _randRange(rng, 22, 54),
            _randRange(rng, 0.20, 0.62),
            _randRange(rng, 0.72, 0.95),
          ).toColor(),
          depth: depth,
        );
      }(),
  ];

  final shipments = <TradeShipment>[
    for (var i = 0; i < shipmentCount; i++)
      () {
        final routeIndex = routes.isEmpty ? 0 : rng.nextInt(routes.length);
        final routeColor = routes.isEmpty
            ? const Color(0xFFA5F3FC)
            : routes[routeIndex].color;
        return TradeShipment(
          routeIndex: routeIndex,
          progress: rng.nextDouble(),
          speed: _randRange(rng, 0.07, 0.26),
          size: _randRange(rng, 0.70, 1.40),
          color:
              Color.lerp(
                routeColor,
                Colors.white,
                _randRange(rng, 0.12, 0.34),
              ) ??
              const Color(0xFFA5F3FC),
        );
      }(),
  ];

  return GalaxyTradeGenerated(
    scene: GalaxyTradeScene(
      systems: systems,
      routes: routes,
      nebulas: nebulas,
      dustMotes: dustMotes,
      stars: stars,
      bounds: bounds,
    ),
    shipments: shipments,
  );
}

List<TradeRoute> _buildRoutes(math.Random rng, List<GalaxySystem> systems) {
  final routes = <TradeRoute>[];
  final seen = <String>{};

  void addEdge(int a, int b) {
    if (a == b) return;
    final minIdx = math.min(a, b);
    final maxIdx = math.max(a, b);
    final key = '$minIdx-$maxIdx';
    if (!seen.add(key)) return;

    final from = systems[minIdx];
    final to = systems[maxIdx];
    final blend =
        Color.lerp(from.factionColor, to.factionColor, 0.5) ??
        const Color(0xFF8CE7FF);

    routes.add(
      TradeRoute(
        fromIndex: minIdx,
        toIndex: maxIdx,
        capacity: _randRange(rng, 0.30, 1.0),
        flowSpeed: _randRange(rng, 0.06, 0.30),
        flowOffset: _randRange(rng, 0, 1),
        color: blend,
      ),
    );
  }

  for (var i = 0; i < systems.length; i++) {
    final neighbors = <_NeighborDist>[];
    final a = systems[i].center;
    for (var j = 0; j < systems.length; j++) {
      if (i == j) continue;
      final b = systems[j].center;
      final d2 = (a - b).distanceSquared;
      neighbors.add(_NeighborDist(index: j, distanceSq: d2));
    }

    neighbors.sort((l, r) => l.distanceSq.compareTo(r.distanceSq));
    final nearCount = math.min(4, neighbors.length);
    for (var n = 0; n < nearCount; n++) {
      if (n < 2 || rng.nextDouble() < 0.44) {
        addEdge(i, neighbors[n].index);
      }
    }

    if (rng.nextDouble() < 0.20 && systems.length > 8) {
      addEdge(i, rng.nextInt(systems.length));
    }
  }

  return routes;
}

class _NeighborDist {
  final int index;
  final double distanceSq;

  const _NeighborDist({required this.index, required this.distanceSq});
}

String _buildSystemName(math.Random rng) {
  const a = <String>[
    'Astra',
    'Vela',
    'Drift',
    'Orion',
    'Zeph',
    'Ciri',
    'Nyx',
    'Tara',
    'Luma',
    'Aris',
    'Nova',
    'Kron',
  ];
  const b = <String>[
    'Prime',
    'Reach',
    'Gate',
    'Harbor',
    'Port',
    'Spire',
    'Basin',
    'Haven',
    'Nexus',
    'Arc',
  ];
  final left = a[rng.nextInt(a.length)];
  final right = b[rng.nextInt(b.length)];
  final code = rng.nextInt(90) + 10;
  return '$left $right-$code';
}

double _randRange(math.Random rng, double min, double max) {
  return min + (max - min) * rng.nextDouble();
}

Offset _sampleHaloPoint(
  math.Random rng, {
  required Offset center,
  required double radiusX,
  required double radiusY,
  required double radialBias,
}) {
  final theta = rng.nextDouble() * math.pi * 2;
  final radial = math.pow(rng.nextDouble(), radialBias).toDouble();
  return Offset(
    center.dx + math.cos(theta) * radiusX * radial,
    center.dy + math.sin(theta) * radiusY * radial,
  );
}
