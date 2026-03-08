import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'orbital_models.dart';

OrbitalScene generateOrbitalScene({
  required int seed,
  required int hubCount,
  required int bodiesPerHub,
}) {
  final rng = math.Random(seed);

  final hubs = _generateHubs(rng: rng, count: hubCount);
  final bodies = _generateBodies(
    rng: rng,
    hubs: hubs,
    bodiesPerHub: bodiesPerHub,
  );
  final routes = _generateRoutes(rng: rng, hubs: hubs);

  final maxOrbitByHub = <int, double>{};
  for (final body in bodies) {
    final current = maxOrbitByHub[body.hubIndex] ?? 0;
    if (body.orbitRadius > current) {
      maxOrbitByHub[body.hubIndex] = body.orbitRadius;
    }
  }

  var left = double.infinity;
  var top = double.infinity;
  var right = -double.infinity;
  var bottom = -double.infinity;
  for (var i = 0; i < hubs.length; i++) {
    final h = hubs[i];
    final orbit = maxOrbitByHub[i] ?? 0;
    final radius = orbit + 420;
    left = math.min(left, h.center.dx - radius);
    top = math.min(top, h.center.dy - radius);
    right = math.max(right, h.center.dx + radius);
    bottom = math.max(bottom, h.center.dy + radius);
  }
  if (!left.isFinite) {
    left = -2000;
    top = -2000;
    right = 2000;
    bottom = 2000;
  }

  final bounds = Rect.fromLTRB(left, top, right, bottom);
  final stars = _generateStars(rng: rng, bounds: bounds);

  return OrbitalScene(
    hubs: hubs,
    bodies: bodies,
    routes: routes,
    stars: stars,
    bounds: bounds,
  );
}

List<OrbitalHub> _generateHubs({required math.Random rng, required int count}) {
  const worldRadiusX = 17000.0;
  const worldRadiusY = 12000.0;
  final hubs = <OrbitalHub>[];
  final palette = <Color>[
    const Color(0xFF6EE7F9),
    const Color(0xFFFFD166),
    const Color(0xFF7CF29A),
    const Color(0xFFBAA6FF),
    const Color(0xFFFF9FC5),
    const Color(0xFFFFB86F),
  ];

  var attempts = 0;
  while (hubs.length < count && attempts < count * 120) {
    attempts++;
    final angle = rng.nextDouble() * math.pi * 2;
    final radial = math.pow(rng.nextDouble(), 0.58).toDouble();
    final x = math.cos(angle) * radial * worldRadiusX;
    final y = math.sin(angle) * radial * worldRadiusY;
    final candidate = Offset(x, y);

    var ok = true;
    for (final existing in hubs) {
      final minDistance = 1350 + rng.nextDouble() * 300;
      if ((candidate - existing.center).distance < minDistance) {
        ok = false;
        break;
      }
    }
    if (!ok) continue;

    final hubIndex = hubs.length;
    hubs.add(
      OrbitalHub(
        id: 'H$hubIndex',
        name: 'Helios-$hubIndex',
        center: candidate,
        color: palette[hubIndex % palette.length],
        coreRadius: 34 + rng.nextDouble() * 34,
        ringCount: 5 + rng.nextInt(4),
      ),
    );
  }

  if (hubs.isEmpty) {
    hubs.add(
      const OrbitalHub(
        id: 'H0',
        name: 'Helios-0',
        center: Offset.zero,
        color: Color(0xFF6EE7F9),
        coreRadius: 44,
        ringCount: 6,
      ),
    );
  }

  return hubs;
}

List<OrbitalBody> _generateBodies({
  required math.Random rng,
  required List<OrbitalHub> hubs,
  required int bodiesPerHub,
}) {
  final bodies = <OrbitalBody>[];
  const retrogradeChance = 0.08;

  const planetPalette = <Color>[
    Color(0xFF8AC6FF),
    Color(0xFFF8B26A),
    Color(0xFF76F0B6),
    Color(0xFFF3A2D4),
    Color(0xFFC5B8FF),
    Color(0xFFFFE27A),
  ];

  for (var hubIndex = 0; hubIndex < hubs.length; hubIndex++) {
    final hub = hubs[hubIndex];
    final dominantSign = rng.nextBool() ? 1.0 : -1.0;
    final base = hub.coreRadius + 54;
    final spacing = 19 + rng.nextDouble() * 9;
    for (var i = 0; i < bodiesPerHub; i++) {
      final orbitRadius = base + i * spacing + rng.nextDouble() * 7;
      final angle = rng.nextDouble() * math.pi * 2;
      final isRetrograde = rng.nextDouble() < retrogradeChance;
      final velocitySign = isRetrograde ? -dominantSign : dominantSign;
      final angularVelocity =
          velocitySign * (0.06 + rng.nextDouble() * 0.19) / (1 + i * 0.07);
      final station = i % 9 == 0;
      final size = station
          ? 15 + rng.nextDouble() * 6
          : 7 + rng.nextDouble() * 8;
      final color = planetPalette[(hubIndex + i) % planetPalette.length];
      final center =
          hub.center + Offset(math.cos(angle), math.sin(angle)) * orbitRadius;

      bodies.add(
        OrbitalBody(
          id: 'B${hubIndex}_$i',
          hubIndex: hubIndex,
          label: station ? 'S$hubIndex-$i' : 'P$hubIndex-$i',
          orbitRadius: orbitRadius,
          size: size,
          angularVelocity: angularVelocity,
          color: color,
          station: station,
          hasRing: !station && (i % 7 == 0),
          angle: angle,
          center: center,
        ),
      );
    }
  }

  return bodies;
}

List<OrbitalRoute> _generateRoutes({
  required math.Random rng,
  required List<OrbitalHub> hubs,
}) {
  final routes = <OrbitalRoute>[];
  final seen = <String>{};

  for (var i = 0; i < hubs.length; i++) {
    final from = hubs[i];
    final neighbors = <({int index, double distance})>[];
    for (var j = 0; j < hubs.length; j++) {
      if (i == j) continue;
      final d = (hubs[j].center - from.center).distance;
      neighbors.add((index: j, distance: d));
    }
    neighbors.sort((a, b) => a.distance.compareTo(b.distance));
    final picks = math.min(3, neighbors.length);

    for (var n = 0; n < picks; n++) {
      final j = neighbors[n].index;
      final a = math.min(i, j);
      final b = math.max(i, j);
      final key = '$a:$b';
      if (!seen.add(key)) continue;
      routes.add(
        OrbitalRoute(
          fromHubIndex: i,
          toHubIndex: j,
          flux: 0.45 + rng.nextDouble() * 0.85,
          phase: rng.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  return routes;
}

List<OrbitalStar> _generateStars({
  required math.Random rng,
  required Rect bounds,
}) {
  final stars = <OrbitalStar>[];
  const extra = 6400.0;
  final area = Rect.fromLTRB(
    bounds.left - extra,
    bounds.top - extra,
    bounds.right + extra,
    bounds.bottom + extra,
  );

  final count = math.max(1200, (area.width * area.height / 240000).round());
  for (var i = 0; i < count; i++) {
    final p = Offset(
      area.left + rng.nextDouble() * area.width,
      area.top + rng.nextDouble() * area.height,
    );
    final depth = 0.2 + rng.nextDouble() * 0.8;
    final hueSeed = rng.nextDouble();
    final color = Color.lerp(
      const Color(0xFFB5D8FF),
      hueSeed > 0.75 ? const Color(0xFFFFE2B5) : const Color(0xFFE8EEFF),
      rng.nextDouble(),
    )!;
    stars.add(
      OrbitalStar(
        position: p,
        size: 0.4 + rng.nextDouble() * 1.6,
        depth: depth,
        phase: rng.nextDouble() * math.pi * 2,
        twinkleSpeed: 0.6 + rng.nextDouble() * 2.2,
        color: color,
      ),
    );
  }
  return stars;
}
