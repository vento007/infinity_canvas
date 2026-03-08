import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tiny_ecs/tiny_ecs.dart';

import 'components.dart';

class TdGameEngine {
  TdGameEngine({int seed = 17}) : _rng = math.Random(seed) {
    reset();
  }

  World _world = World();
  final math.Random _rng;

  final ValueNotifier<int> tick = ValueNotifier<int>(0);
  final ValueNotifier<int> gold = ValueNotifier<int>(90);
  final ValueNotifier<int> lives = ValueNotifier<int>(20);
  final ValueNotifier<int> wave = ValueNotifier<int>(0);
  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<bool> paused = ValueNotifier<bool>(false);
  final ValueNotifier<bool> gameOver = ValueNotifier<bool>(false);
  final ValueNotifier<bool> waveRunning = ValueNotifier<bool>(false);

  final Rect boardBounds = const Rect.fromLTWH(-760, -360, 1520, 760);

  final List<Offset> pathPoints = const [
    Offset(-700, -180),
    Offset(-250, -180),
    Offset(-250, 150),
    Offset(120, 150),
    Offset(120, -90),
    Offset(560, -90),
    Offset(700, 130),
  ];

  final List<Offset> _padPositions = const [
    Offset(-560, -290),
    Offset(-430, -80),
    Offset(-170, -290),
    Offset(-110, 30),
    Offset(12, 250),
    Offset(240, 30),
    Offset(320, -230),
    Offset(500, 30),
    Offset(620, -220),
  ];

  final Map<int, Entity> _padEntityByIndex = <int, Entity>{};

  int _remainingToSpawn = 0;
  double _spawnTimer = 0;
  double _elapsedSeconds = 0;
  static const bool _traceProjectiles = false;
  DateTime? _traceProjectileWindowStart;
  int _traceProjectileFired = 0;
  int _traceProjectileHits = 0;
  int _traceProjectileRemoved = 0;

  World get world => _world;
  double get elapsedSeconds => _elapsedSeconds;

  int get creepCount => _world.query<CreepC>().length;
  int get towerCount => _world.query<TowerC>().length;
  int get projectileCount => _world.query<ProjectileC>().length;

  void reset() {
    _world = World();
    _padEntityByIndex.clear();

    gold.value = 90;
    lives.value = 20;
    wave.value = 0;
    score.value = 0;
    paused.value = false;
    gameOver.value = false;
    waveRunning.value = false;

    _remainingToSpawn = 0;
    _spawnTimer = 0;
    _elapsedSeconds = 0;
    _traceProjectileWindowStart = DateTime.now();
    _traceProjectileFired = 0;
    _traceProjectileHits = 0;
    _traceProjectileRemoved = 0;

    _createPads();
    tick.value = tick.value + 1;
  }

  void setPaused(bool value) {
    if (paused.value == value) return;
    paused.value = value;
  }

  bool startNextWave() {
    if (gameOver.value || waveRunning.value) return false;

    wave.value = wave.value + 1;
    _remainingToSpawn = 9 + wave.value * 2;
    _spawnTimer = 0;
    waveRunning.value = true;
    return true;
  }

  int? hitPadIndex(Offset worldPoint, {double maxDistance = 28}) {
    int? bestIndex;
    var bestSq = maxDistance * maxDistance;

    for (final q in _world.query2<PositionC, TowerPadC>()) {
      final p = q.component1.offset;
      final dx = p.dx - worldPoint.dx;
      final dy = p.dy - worldPoint.dy;
      final d2 = dx * dx + dy * dy;
      if (d2 <= bestSq) {
        bestSq = d2;
        bestIndex = q.component2.index;
      }
    }
    return bestIndex;
  }

  bool canBuildOnPad(int padIndex) {
    final data = _padData(padIndex);
    if (data == null) return false;
    return !data.pad.occupied;
  }

  bool buildTowerOnPad(int padIndex, TdTowerKind kind) {
    if (gameOver.value) return false;
    final data = _padData(padIndex);
    if (data == null || data.pad.occupied) return false;

    if (gold.value < kind.cost) return false;

    final commands = _world.commandBuffer();
    final towerEntity = commands.createEntity();
    commands.addComponent(towerEntity, PositionC(data.pos.x, data.pos.y));
    commands.addComponent(towerEntity, TowerC(kind: kind));
    commands.flush();

    data.pad.occupied = true;
    data.pad.towerEntity = towerEntity;

    gold.value -= kind.cost;
    tick.value = tick.value + 1;
    return true;
  }

  bool hasTowerOnPad(int padIndex) {
    final data = _padData(padIndex);
    if (data == null) return false;
    return _towerOnPad(data.pad) != null;
  }

  TdTowerKind? towerKindOnPad(int padIndex) {
    final data = _padData(padIndex);
    if (data == null) return null;
    return _towerOnPad(data.pad)?.kind;
  }

  int? towerLevelOnPad(int padIndex) {
    final data = _padData(padIndex);
    if (data == null) return null;
    return _towerOnPad(data.pad)?.level;
  }

  int? towerSellValueOnPad(int padIndex) {
    final data = _padData(padIndex);
    if (data == null) return null;
    return _towerOnPad(data.pad)?.sellValue;
  }

  int? towerUpgradeCostOnPad(int padIndex) {
    final data = _padData(padIndex);
    if (data == null) return null;
    final tower = _towerOnPad(data.pad);
    if (tower == null || !tower.canUpgrade) return null;
    return tower.nextUpgradeCost;
  }

  bool upgradeTowerOnPad(int padIndex) {
    if (gameOver.value) return false;
    final data = _padData(padIndex);
    if (data == null) return false;
    final tower = _towerOnPad(data.pad);
    if (tower == null || !tower.canUpgrade) return false;
    final cost = tower.nextUpgradeCost;
    if (gold.value < cost) return false;

    gold.value -= cost;
    tower.level += 1;
    tower.totalSpent += cost;
    tick.value = tick.value + 1;
    return true;
  }

  bool sellTowerOnPad(int padIndex) {
    if (gameOver.value) return false;
    final data = _padData(padIndex);
    if (data == null) return false;
    final towerEntity = data.pad.towerEntity;
    final tower = _towerOnPad(data.pad);
    if (towerEntity == null || tower == null) return false;

    final commands = _world.commandBuffer();
    commands.destroyEntity(towerEntity);
    commands.flush();

    data.pad.occupied = false;
    data.pad.towerEntity = null;
    gold.value += tower.sellValue;
    tick.value = tick.value + 1;
    return true;
  }

  bool moveTower(int fromPadIndex, int toPadIndex) {
    if (gameOver.value || fromPadIndex == toPadIndex) return false;

    final fromData = _padData(fromPadIndex);
    final toData = _padData(toPadIndex);
    if (fromData == null || toData == null) return false;
    if (toData.pad.occupied) return false;

    final towerEntity = fromData.pad.towerEntity;
    final tower = _towerOnPad(fromData.pad);
    if (towerEntity == null || tower == null) return false;

    final pos = _world.getComponent<PositionC>(towerEntity);
    if (pos == null) return false;

    pos.offset = toData.pos.offset;
    fromData.pad.occupied = false;
    fromData.pad.towerEntity = null;
    toData.pad.occupied = true;
    toData.pad.towerEntity = towerEntity;
    tick.value = tick.value + 1;
    return true;
  }

  int? replaceCostDeltaOnPad(int padIndex, TdTowerKind nextKind) {
    final data = _padData(padIndex);
    if (data == null) return null;
    final tower = _towerOnPad(data.pad);
    if (tower == null) return null;
    if (tower.kind == nextKind) return 0;
    return math.max(0, nextKind.cost - tower.sellValue);
  }

  bool replaceTowerOnPad(int padIndex, TdTowerKind nextKind) {
    if (gameOver.value) return false;
    final data = _padData(padIndex);
    if (data == null) return false;
    final tower = _towerOnPad(data.pad);
    if (tower == null) return false;
    if (tower.kind == nextKind) return false;

    final delta = math.max(0, nextKind.cost - tower.sellValue);
    if (gold.value < delta) return false;

    gold.value -= delta;
    tower.kind = nextKind;
    tower.level = 1;
    tower.totalSpent = nextKind.cost;
    tower.cooldown = 0;
    tick.value = tick.value + 1;
    return true;
  }

  double? towerRangeOnPad(int padIndex) {
    final data = _padData(padIndex);
    if (data == null) return null;
    return _towerOnPad(data.pad)?.range;
  }

  void step(double dt) {
    if (paused.value || gameOver.value) return;
    if (dt <= 0) return;

    final frameDt = dt.clamp(0.0, 0.05);
    _elapsedSeconds += frameDt;
    final commands = _world.commandBuffer();

    _spawnCreeps(frameDt, commands);
    _moveCreeps(frameDt, commands);
    _fireTowers(frameDt, commands);
    _moveProjectiles(frameDt, commands);
    _advanceEffects(frameDt, commands);
    _cleanupAndRewards(commands);
    commands.flush();

    if (lives.value <= 0 && !gameOver.value) {
      gameOver.value = true;
      paused.value = true;
    }

    if (waveRunning.value &&
        _remainingToSpawn <= 0 &&
        _world.entitiesWith<CreepC>().isEmpty) {
      waveRunning.value = false;
      final bonus = 8 + wave.value * 2;
      gold.value += bonus;
      score.value += 20 + wave.value * 4;
    }

    _traceProjectileStats();
    tick.value = tick.value + 1;
  }

  void _createPads() {
    for (var i = 0; i < _padPositions.length; i++) {
      final pad = _world.createEntity();
      final p = _padPositions[i];
      _world.addComponent(pad, PositionC(p.dx, p.dy));
      _world.addComponent(pad, TowerPadC(index: i));
      _padEntityByIndex[i] = pad;
    }
  }

  void _spawnCreeps(double dt, CommandBuffer commands) {
    if (!waveRunning.value || _remainingToSpawn <= 0) return;

    final interval = (0.62 - wave.value * 0.02).clamp(0.20, 0.62);
    _spawnTimer -= dt;

    while (_remainingToSpawn > 0 && _spawnTimer <= 0) {
      _spawnTimer += interval;
      _remainingToSpawn -= 1;
      _spawnOneCreep(commands);
    }
  }

  void _spawnOneCreep(CommandBuffer commands) {
    final start = pathPoints.first;

    final hpBase = 26 + wave.value * 6;
    final hp = hpBase + _rng.nextDouble() * 6;
    final speed = 66 + wave.value * 2.4 + _rng.nextDouble() * 10;
    final radius = 10.5 + _rng.nextDouble() * 2.2;
    final reward = 4 + (wave.value ~/ 2);

    final entity = commands.createEntity();
    commands.addComponent(entity, PositionC(start.dx, start.dy));
    commands.addComponent(
      entity,
      CreepC(hp: hp, maxHp: hp, speed: speed, reward: reward, radius: radius),
    );
  }

  void _moveCreeps(double dt, CommandBuffer commands) {
    final escaped = <Entity>[];
    final creeps = _world.query2<PositionC, CreepC>().toList(growable: false);

    for (final q in creeps) {
      final entity = q.entity;
      final pos = q.component1;
      final creep = q.component2;

      if (creep.slowTimer > 0) {
        creep.slowTimer = math.max(0.0, creep.slowTimer - dt);
        if (creep.slowTimer <= 0) {
          creep.slowFactor = 1.0;
        }
      }

      final speed = creep.speed * creep.slowFactor;
      var remain = speed * dt;

      while (remain > 0 && creep.pathSegment < pathPoints.length - 1) {
        final a = pathPoints[creep.pathSegment];
        final b = pathPoints[creep.pathSegment + 1];
        final seg = b - a;
        final segLen = seg.distance;
        if (segLen <= 0.0001) {
          creep.pathSegment += 1;
          creep.segmentT = 0;
          continue;
        }

        final onSegment = segLen * creep.segmentT;
        final left = segLen - onSegment;

        if (remain < left) {
          final newDist = onSegment + remain;
          creep.segmentT = (newDist / segLen).clamp(0.0, 1.0);
          pos.offset = a + seg * creep.segmentT;
          creep.pathProgress += remain;
          remain = 0;
        } else {
          remain -= left;
          creep.pathProgress += left;
          creep.pathSegment += 1;
          creep.segmentT = 0;
          pos.offset = b;
        }
      }

      if (creep.pathSegment >= pathPoints.length - 1) {
        escaped.add(entity);
      }
    }

    if (escaped.isNotEmpty) {
      for (final entity in escaped) {
        commands.destroyEntity(entity);
        lives.value -= 1;
      }
    }
  }

  void _fireTowers(double dt, CommandBuffer commands) {
    final creeps = _world.query2<PositionC, CreepC>().toList(growable: false);
    final towers = _world.query2<PositionC, TowerC>().toList(growable: false);
    if (creeps.isEmpty) {
      final towerOnly = _world.query<TowerC>().toList(growable: false);
      for (final q in towerOnly) {
        q.component1.cooldown = math.max(0, q.component1.cooldown - dt);
      }
      return;
    }

    for (final q in towers) {
      final towerPos = q.component1;
      final tower = q.component2;

      tower.cooldown = math.max(0, tower.cooldown - dt);
      if (tower.cooldown > 0) continue;

      final target = _pickTarget(towerPos.offset, tower, creeps);
      if (target == null) continue;

      final targetPos = target.component1.offset;
      var dir = targetPos - towerPos.offset;
      final len = dir.distance;
      if (len <= 0.0001) continue;
      dir /= len;

      final projectile = commands.createEntity();
      commands.addComponent(projectile, PositionC(towerPos.x, towerPos.y));
      commands.addComponent(
        projectile,
        VelocityC(
          dir.dx * tower.projectileSpeed,
          dir.dy * tower.projectileSpeed,
        ),
      );
      commands.addComponent(
        projectile,
        ProjectileC(
          source: tower.kind,
          ttl: 2.4,
          damage: tower.damage,
          radius: tower.kind == TdTowerKind.cannon ? 6.2 : 4.6,
          splashRadius: tower.splashRadius,
          slowSeconds: tower.slowSeconds,
          slowFactor: tower.slowFactor,
        ),
      );
      if (_traceProjectiles) {
        _traceProjectileFired++;
      }

      tower.cooldown = tower.fireInterval;
    }
  }

  QueryResult2<PositionC, CreepC>? _pickTarget(
    Offset towerPos,
    TowerC tower,
    List<QueryResult2<PositionC, CreepC>> creeps,
  ) {
    QueryResult2<PositionC, CreepC>? best;
    var bestProgress = -1.0;

    final rangeSq = tower.range * tower.range;
    for (final c in creeps) {
      final p = c.component1.offset;
      final d = p - towerPos;
      final distSq = d.dx * d.dx + d.dy * d.dy;
      if (distSq > rangeSq) continue;

      if (c.component2.pathProgress > bestProgress) {
        bestProgress = c.component2.pathProgress;
        best = c;
      }
    }
    return best;
  }

  ({Entity padEntity, PositionC pos, TowerPadC pad})? _padData(int padIndex) {
    final entity = _padEntityByIndex[padIndex];
    if (entity == null) return null;
    final pad = _world.getComponent<TowerPadC>(entity);
    final pos = _world.getComponent<PositionC>(entity);
    if (pad == null || pos == null) return null;
    return (padEntity: entity, pos: pos, pad: pad);
  }

  TowerC? _towerOnPad(TowerPadC pad) {
    final towerEntity = pad.towerEntity;
    if (towerEntity == null) {
      if (pad.occupied) {
        pad.occupied = false;
      }
      return null;
    }
    final tower = _world.getComponent<TowerC>(towerEntity);
    if (tower == null) {
      pad.occupied = false;
      pad.towerEntity = null;
      return null;
    }
    if (!pad.occupied) {
      pad.occupied = true;
    }
    return tower;
  }

  void _moveProjectiles(double dt, CommandBuffer commands) {
    final creeps = _world.query2<PositionC, CreepC>().toList(growable: false);
    final projectiles = _world
        .query3<PositionC, VelocityC, ProjectileC>()
        .toList(growable: false);
    if (creeps.isEmpty) {
      final toRemove = <Entity>[];
      for (final q in projectiles) {
        final p = q.component1;
        final v = q.component2;
        final projectile = q.component3;
        p.x += v.x * dt;
        p.y += v.y * dt;
        projectile.ageSeconds += dt;
        projectile.ttl -= dt;
        if (projectile.ttl <= 0) toRemove.add(q.entity);
      }
      for (final entity in toRemove) {
        commands.destroyEntity(entity);
      }
      return;
    }

    final projectileRemovals = <Entity>{};
    final damagedCreeps = <Entity, double>{};
    final slowEffects = <Entity, ({double seconds, double factor})>{};

    for (final q in projectiles) {
      final projectileEntity = q.entity;
      final pos = q.component1;
      final vel = q.component2;
      final projectile = q.component3;

      final prevPos = pos.offset;
      final nextPos = Offset(pos.x + vel.x * dt, pos.y + vel.y * dt);
      pos.offset = nextPos;
      projectile.ageSeconds += dt;
      projectile.ttl -= dt;
      if (projectile.ttl <= 0) {
        projectileRemovals.add(projectileEntity);
        continue;
      }
      if (projectile.ageSeconds < projectile.armingDelaySeconds) {
        continue;
      }

      Entity? directHit;
      var bestDistanceSq = double.infinity;
      for (final creep in creeps) {
        final creepPos = creep.component1.offset;
        final creepData = creep.component2;
        final hitR = creepData.radius + projectile.radius;
        final distSq = _segmentDistanceSq(prevPos, nextPos, creepPos);
        if (distSq <= hitR * hitR && distSq < bestDistanceSq) {
          bestDistanceSq = distSq;
          directHit = creep.entity;
        }
      }

      if (directHit == null) continue;
      if (_traceProjectiles) {
        _traceProjectileHits++;
      }

      if (projectile.splashRadius > 0) {
        final center =
            _world.getComponent<PositionC>(directHit)?.offset ?? pos.offset;
        final splashSq = projectile.splashRadius * projectile.splashRadius;
        for (final creep in creeps) {
          final d = creep.component1.offset - center;
          if (d.dx * d.dx + d.dy * d.dy <= splashSq) {
            damagedCreeps[creep.entity] =
                (damagedCreeps[creep.entity] ?? 0) + projectile.damage;
          }
        }
        _spawnImpactFx(commands, center: center, projectile: projectile);
      } else {
        damagedCreeps[directHit] =
            (damagedCreeps[directHit] ?? 0) + projectile.damage;
        final center =
            _world.getComponent<PositionC>(directHit)?.offset ?? pos.offset;
        _spawnImpactFx(commands, center: center, projectile: projectile);
      }

      if (projectile.slowSeconds > 0) {
        for (final creep in creeps) {
          final d = creep.component1.offset - pos.offset;
          final slowRadius = math.max(
            14.0,
            projectile.splashRadius > 0
                ? projectile.splashRadius
                : projectile.radius + creep.component2.radius + 2,
          );
          if (d.dx * d.dx + d.dy * d.dy <= slowRadius * slowRadius) {
            final prev = slowEffects[creep.entity];
            if (prev == null || projectile.slowSeconds > prev.seconds) {
              slowEffects[creep.entity] = (
                seconds: projectile.slowSeconds,
                factor: projectile.slowFactor,
              );
            }
          }
        }
      }

      projectileRemovals.add(projectileEntity);
    }

    for (final entry in damagedCreeps.entries) {
      final creep = _world.getComponent<CreepC>(entry.key);
      if (creep != null) {
        creep.hp -= entry.value;
      }
    }

    for (final entry in slowEffects.entries) {
      final creep = _world.getComponent<CreepC>(entry.key);
      if (creep == null) continue;
      creep.slowTimer = math.max(creep.slowTimer, entry.value.seconds);
      creep.slowFactor = math.min(creep.slowFactor, entry.value.factor);
    }

    for (final entity in projectileRemovals) {
      commands.destroyEntity(entity);
    }
    if (_traceProjectiles && projectileRemovals.isNotEmpty) {
      _traceProjectileRemoved += projectileRemovals.length;
    }
  }

  void _spawnImpactFx(
    CommandBuffer commands, {
    required Offset center,
    required ProjectileC projectile,
  }) {
    final entity = commands.createEntity();
    commands.addComponent(entity, PositionC(center.dx, center.dy));

    final duration = projectile.splashRadius > 0 ? 0.34 : 0.22;
    final maxRadius = projectile.splashRadius > 0
        ? projectile.splashRadius * 0.85
        : math.max(16.0, projectile.radius * 5.2);

    commands.addComponent(
      entity,
      ImpactFxC(
        ttl: duration,
        duration: duration,
        maxRadius: maxRadius,
        source: projectile.source,
      ),
    );
  }

  void _advanceEffects(double dt, CommandBuffer commands) {
    final effects = _world.query<ImpactFxC>().toList(growable: false);
    for (final q in effects) {
      final fx = q.component1;
      fx.ttl -= dt;
      if (fx.ttl <= 0) {
        commands.destroyEntity(q.entity);
      }
    }
  }

  double _segmentDistanceSq(Offset a, Offset b, Offset p) {
    final ab = b - a;
    final ap = p - a;
    final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq <= 1e-9) {
      final dx = p.dx - a.dx;
      final dy = p.dy - a.dy;
      return dx * dx + dy * dy;
    }
    final t = ((ap.dx * ab.dx) + (ap.dy * ab.dy)) / abLenSq;
    final clampedT = t.clamp(0.0, 1.0);
    final closest = Offset(a.dx + ab.dx * clampedT, a.dy + ab.dy * clampedT);
    final d = p - closest;
    return d.dx * d.dx + d.dy * d.dy;
  }

  void _cleanupAndRewards(CommandBuffer commands) {
    final dead = <Entity>[];
    final creeps = _world.query<CreepC>().toList(growable: false);
    for (final q in creeps) {
      if (q.component1.hp <= 0) {
        dead.add(q.entity);
      }
    }

    if (dead.isEmpty) return;

    for (final entity in dead) {
      final creep = _world.getComponent<CreepC>(entity);
      if (creep != null) {
        gold.value += creep.reward;
        score.value += 5 + wave.value;
      }
      commands.destroyEntity(entity);
    }
  }

  void dispose() {
    tick.dispose();
    gold.dispose();
    lives.dispose();
    wave.dispose();
    score.dispose();
    paused.dispose();
    gameOver.dispose();
    waveRunning.dispose();
  }

  void _traceProjectileStats() {
    if (!_traceProjectiles) return;
    final now = DateTime.now();
    final windowStart = _traceProjectileWindowStart ?? now;
    final elapsedMs = now.difference(windowStart).inMilliseconds;
    if (elapsedMs < 1000) return;
    // ignore: avoid_print
    print(
      'td proj dbg '
      'alive=$projectileCount '
      'fired/s=$_traceProjectileFired '
      'hits/s=$_traceProjectileHits '
      'removed/s=$_traceProjectileRemoved '
      'towers=$towerCount creeps=$creepCount '
      'wave=${wave.value} running=${waveRunning.value}',
    );
    _traceProjectileWindowStart = now;
    _traceProjectileFired = 0;
    _traceProjectileHits = 0;
    _traceProjectileRemoved = 0;
  }
}
