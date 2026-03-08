import 'package:flutter/material.dart';
import 'package:tiny_ecs/tiny_ecs.dart';

enum TdTowerKind { pulse, cannon, freezer }

extension TdTowerKindExt on TdTowerKind {
  String get label {
    switch (this) {
      case TdTowerKind.pulse:
        return 'Pulse';
      case TdTowerKind.cannon:
        return 'Cannon';
      case TdTowerKind.freezer:
        return 'Freezer';
    }
  }

  int get cost {
    switch (this) {
      case TdTowerKind.pulse:
        return 24;
      case TdTowerKind.cannon:
        return 40;
      case TdTowerKind.freezer:
        return 34;
    }
  }

  double get range {
    switch (this) {
      case TdTowerKind.pulse:
        return 210;
      case TdTowerKind.cannon:
        return 185;
      case TdTowerKind.freezer:
        return 225;
    }
  }

  double get fireInterval {
    switch (this) {
      case TdTowerKind.pulse:
        return 0.28;
      case TdTowerKind.cannon:
        return 0.74;
      case TdTowerKind.freezer:
        return 0.44;
    }
  }

  double get projectileSpeed {
    switch (this) {
      case TdTowerKind.pulse:
        return 520;
      case TdTowerKind.cannon:
        return 410;
      case TdTowerKind.freezer:
        return 500;
    }
  }

  double get damage {
    switch (this) {
      case TdTowerKind.pulse:
        return 14;
      case TdTowerKind.cannon:
        return 38;
      case TdTowerKind.freezer:
        return 10;
    }
  }

  double get splashRadius {
    switch (this) {
      case TdTowerKind.cannon:
        return 74;
      default:
        return 0;
    }
  }

  double get slowFactor {
    switch (this) {
      case TdTowerKind.freezer:
        return 0.36;
      default:
        return 1.0;
    }
  }

  double get slowSeconds {
    switch (this) {
      case TdTowerKind.freezer:
        return 1.9;
      default:
        return 0.0;
    }
  }

  Color get color {
    switch (this) {
      case TdTowerKind.pulse:
        return const Color(0xFF4EA8DE);
      case TdTowerKind.cannon:
        return const Color(0xFFE76F51);
      case TdTowerKind.freezer:
        return const Color(0xFF80ED99);
    }
  }
}

class PositionC extends Component {
  double x;
  double y;

  PositionC(this.x, this.y);

  Offset get offset => Offset(x, y);
  set offset(Offset v) {
    x = v.dx;
    y = v.dy;
  }
}

class VelocityC extends Component {
  double x;
  double y;

  VelocityC(this.x, this.y);

  Offset get offset => Offset(x, y);
}

class TowerC extends Component {
  TdTowerKind kind;
  double cooldown;
  int level;
  int totalSpent;

  TowerC({
    required this.kind,
    this.cooldown = 0,
    this.level = 1,
    int? totalSpent,
  }) : totalSpent = totalSpent ?? kind.cost;

  static const int maxLevel = 5;

  bool get canUpgrade => level < maxLevel;

  int get nextUpgradeCost {
    final factor = 0.70 + level * 0.55;
    return (kind.cost * factor).round();
  }

  int get sellValue => (totalSpent * 0.70).round();

  double get range => kind.range * (1.0 + (level - 1) * 0.12);

  double get fireInterval {
    final v = kind.fireInterval * (1.0 - (level - 1) * 0.06);
    return v.clamp(kind.fireInterval * 0.65, kind.fireInterval).toDouble();
  }

  double get projectileSpeed =>
      kind.projectileSpeed * (1.0 + (level - 1) * 0.05);

  double get damage => kind.damage * (1.0 + (level - 1) * 0.42);

  double get splashRadius => kind.splashRadius > 0
      ? kind.splashRadius * (1.0 + (level - 1) * 0.08)
      : 0;

  double get slowFactor {
    if (kind.slowFactor >= 1.0) return 1.0;
    final v = kind.slowFactor - (level - 1) * 0.04;
    return v.clamp(0.18, 1.0).toDouble();
  }

  double get slowSeconds =>
      kind.slowSeconds > 0 ? kind.slowSeconds * (1.0 + (level - 1) * 0.10) : 0;
}

class TowerPadC extends Component {
  final int index;
  bool occupied;
  Entity? towerEntity;

  TowerPadC({required this.index, this.occupied = false, this.towerEntity});
}

class CreepC extends Component {
  double hp;
  double maxHp;
  double speed;
  int reward;
  double radius;

  int pathSegment;
  double segmentT;
  double pathProgress;

  double slowTimer;
  double slowFactor;

  CreepC({
    required this.hp,
    required this.maxHp,
    required this.speed,
    required this.reward,
    required this.radius,
    this.pathSegment = 0,
    this.segmentT = 0,
    this.pathProgress = 0,
    this.slowTimer = 0,
    this.slowFactor = 1.0,
  });
}

class ProjectileC extends Component {
  final TdTowerKind source;
  double ttl;
  double damage;
  double radius;
  double splashRadius;
  double slowSeconds;
  double slowFactor;
  double ageSeconds;
  double armingDelaySeconds;

  ProjectileC({
    required this.source,
    required this.ttl,
    required this.damage,
    required this.radius,
    this.splashRadius = 0,
    this.slowSeconds = 0,
    this.slowFactor = 1.0,
    this.ageSeconds = 0.0,
    this.armingDelaySeconds = 0.028,
  });
}

class ImpactFxC extends Component {
  double ttl;
  final double duration;
  final double maxRadius;
  final TdTowerKind source;

  ImpactFxC({
    required this.ttl,
    required this.duration,
    required this.maxRadius,
    required this.source,
  });
}
