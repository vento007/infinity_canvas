import 'package:flutter/material.dart';

class OrbitalHub {
  final String id;
  final String name;
  final Offset center;
  final Color color;
  final double coreRadius;
  final int ringCount;

  const OrbitalHub({
    required this.id,
    required this.name,
    required this.center,
    required this.color,
    required this.coreRadius,
    required this.ringCount,
  });
}

class OrbitalBody {
  final String id;
  final int hubIndex;
  final String label;
  final double orbitRadius;
  final double size;
  final double angularVelocity;
  final Color color;
  final bool station;
  final bool hasRing;
  double angle;
  Offset center;

  OrbitalBody({
    required this.id,
    required this.hubIndex,
    required this.label,
    required this.orbitRadius,
    required this.size,
    required this.angularVelocity,
    required this.color,
    required this.station,
    required this.hasRing,
    required this.angle,
    required this.center,
  });
}

class OrbitalRoute {
  final int fromHubIndex;
  final int toHubIndex;
  final double flux;
  final double phase;

  const OrbitalRoute({
    required this.fromHubIndex,
    required this.toHubIndex,
    required this.flux,
    required this.phase,
  });
}

class OrbitalStar {
  final Offset position;
  final double size;
  final double depth;
  final double phase;
  final double twinkleSpeed;
  final Color color;

  const OrbitalStar({
    required this.position,
    required this.size,
    required this.depth,
    required this.phase,
    required this.twinkleSpeed,
    required this.color,
  });
}

class OrbitalScene {
  final List<OrbitalHub> hubs;
  final List<OrbitalBody> bodies;
  final List<OrbitalRoute> routes;
  final List<OrbitalStar> stars;
  final Rect bounds;

  const OrbitalScene({
    required this.hubs,
    required this.bodies,
    required this.routes,
    required this.stars,
    required this.bounds,
  });
}
