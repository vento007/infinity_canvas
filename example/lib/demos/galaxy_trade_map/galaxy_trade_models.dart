import 'package:flutter/material.dart';

class GalaxySystem {
  final String id;
  final String name;
  final Offset center;
  final Color factionColor;
  final double supply;
  final double demand;
  final double influence;

  const GalaxySystem({
    required this.id,
    required this.name,
    required this.center,
    required this.factionColor,
    required this.supply,
    required this.demand,
    required this.influence,
  });
}

class TradeRoute {
  final int fromIndex;
  final int toIndex;
  final double capacity;
  final double flowSpeed;
  final double flowOffset;
  final Color color;

  const TradeRoute({
    required this.fromIndex,
    required this.toIndex,
    required this.capacity,
    required this.flowSpeed,
    required this.flowOffset,
    required this.color,
  });
}

class TradeShipment {
  int routeIndex;
  double progress;
  double speed;
  double size;
  Color color;

  TradeShipment({
    required this.routeIndex,
    required this.progress,
    required this.speed,
    required this.size,
    required this.color,
  });
}

class GalaxyMeteor {
  Offset position;
  Offset velocity;
  double length;
  double life;
  final double maxLife;
  double width;
  Color color;

  GalaxyMeteor({
    required this.position,
    required this.velocity,
    required this.length,
    required this.life,
    required this.maxLife,
    required this.width,
    required this.color,
  });
}

class GalaxyDustMote {
  final Offset position;
  final double size;
  final double depth;
  final double phase;
  final double flickerSpeed;
  final Color color;

  const GalaxyDustMote({
    required this.position,
    required this.size,
    required this.depth,
    required this.phase,
    required this.flickerSpeed,
    required this.color,
  });
}

class GalaxyNebula {
  final Offset center;
  final double radius;
  final Color color;
  final double phase;
  final double depth;

  const GalaxyNebula({
    required this.center,
    required this.radius,
    required this.color,
    required this.phase,
    required this.depth,
  });
}

class GalaxyStar {
  final Offset position;
  final double magnitude;
  final double twinkleSpeed;
  final double phase;
  final Color color;
  final double depth;

  const GalaxyStar({
    required this.position,
    required this.magnitude,
    required this.twinkleSpeed,
    required this.phase,
    required this.color,
    required this.depth,
  });
}

class GalaxyTradeScene {
  final List<GalaxySystem> systems;
  final List<TradeRoute> routes;
  final List<GalaxyNebula> nebulas;
  final List<GalaxyDustMote> dustMotes;
  final List<GalaxyStar> stars;
  final Rect bounds;

  const GalaxyTradeScene({
    required this.systems,
    required this.routes,
    required this.nebulas,
    required this.dustMotes,
    required this.stars,
    required this.bounds,
  });
}

class GalaxyTradeGenerated {
  final GalaxyTradeScene scene;
  final List<TradeShipment> shipments;

  const GalaxyTradeGenerated({required this.scene, required this.shipments});
}
