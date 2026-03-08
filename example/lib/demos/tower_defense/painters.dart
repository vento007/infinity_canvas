import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'components.dart';
import 'engine.dart';

class TdBackdropPainter extends CustomPainter {
  final Matrix4 transform;
  final ui.FragmentProgram? program;
  final double timeSeconds;

  TdBackdropPainter({
    required this.transform,
    required this.program,
    required this.timeSeconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (program != null) {
      final shader = program!.fragmentShader();
      shader.setFloat(0, size.width);
      shader.setFloat(1, size.height);
      shader.setFloat(2, timeSeconds);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    } else {
      final bg = Paint()..color = const Color(0xFF0B1020);
      canvas.drawRect(Offset.zero & size, bg);
    }

    final scale = transform.storage[0];
    final tx = transform.storage[12];
    final ty = transform.storage[13];

    final worldStep = 90.0;
    final step = worldStep * scale;
    if (step.abs() < 6) return;

    double firstLine(double spacing, double offset) {
      if (spacing == 0) return 0;
      final m = offset % spacing;
      return m <= 0 ? -m : spacing - m;
    }

    final minor = Paint()
      ..color = const Color(0x1456F1FF)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = const Color(0x2B9D4EDD)
      ..strokeWidth = 1.1;

    final startX = firstLine(step, tx);
    final startY = firstLine(step, ty);
    final majorStep = step * 4;
    final majorX = firstLine(majorStep, tx);
    final majorY = firstLine(majorStep, ty);

    for (double x = startX; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minor);
    }
    for (double y = startY; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minor);
    }
    for (double x = majorX; x <= size.width; x += majorStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), major);
    }
    for (double y = majorY; y <= size.height; y += majorStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), major);
    }
  }

  @override
  bool shouldRepaint(covariant TdBackdropPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.program != program ||
        oldDelegate.timeSeconds != timeSeconds;
  }
}

class TdWorldPainter extends CustomPainter {
  final Matrix4 transform;
  final TdGameEngine engine;
  final TdTowerKind selectedKind;
  final int? hoveredPadIndex;
  final int? selectedPadIndex;

  TdWorldPainter({
    required this.transform,
    required this.engine,
    required this.selectedKind,
    required this.hoveredPadIndex,
    required this.selectedPadIndex,
    super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBoardBounds(canvas);
    _drawPath(canvas);
    _drawPads(canvas);
    _drawTowers(canvas);
    _drawCreeps(canvas);
    _drawProjectiles(canvas);
    _drawImpactFx(canvas);
  }

  Offset _toScreen(Offset world) =>
      MatrixUtils.transformPoint(transform, world);

  double _scaleLength(double worldLen) {
    final a = MatrixUtils.transformPoint(transform, Offset.zero);
    final b = MatrixUtils.transformPoint(transform, Offset(worldLen, 0));
    return (b - a).distance;
  }

  void _drawBoardBounds(Canvas canvas) {
    final r = engine.boardBounds;
    final topLeft = _toScreen(r.topLeft);
    final topRight = _toScreen(r.topRight);
    final bottomLeft = _toScreen(r.bottomLeft);

    final w = (topRight.dx - topLeft.dx).abs();
    final h = (bottomLeft.dy - topLeft.dy).abs();

    canvas.drawRect(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, w, h),
      Paint()..color = const Color(0x140F172A),
    );

    canvas.drawRect(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, w, h),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x555E6D91),
    );
  }

  void _drawPath(Canvas canvas) {
    final points = engine.pathPoints;
    if (points.length < 2) return;

    final first = _toScreen(points.first);
    final path = Path()..moveTo(first.dx, first.dy);
    for (var i = 1; i < points.length; i++) {
      final p = _toScreen(points[i]);
      path.lineTo(p.dx, p.dy);
    }

    final width = math.max(5.0, _scaleLength(20));

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF1A2240).withValues(alpha: 0.22),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF3A4B6A).withValues(alpha: 0.32),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.9, width * 0.08)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  void _drawPads(Canvas canvas) {
    final canAfford = engine.gold.value >= selectedKind.cost;
    final pads = engine.world.query2<PositionC, TowerPadC>().toList(
      growable: false,
    );

    for (final q in pads) {
      final pos = _toScreen(q.component1.offset);
      final pad = q.component2;

      final radius = _scaleLength(19).clamp(9.0, 28.0);
      final hover = hoveredPadIndex == pad.index;
      final selected = selectedPadIndex == pad.index;
      final occupied = pad.occupied;

      final baseColor = occupied
          ? const Color(0xFF334155)
          : const Color(0xFF1E293B);
      final accent = occupied
          ? const Color(0xFF64748B)
          : (canAfford ? selectedKind.color : const Color(0xFFB45309));

      canvas.drawCircle(pos, radius, Paint()..color = baseColor);
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.8 : (hover ? 2.2 : 1.2)
          ..color = selected
              ? const Color(0xFFFDE047).withValues(alpha: 0.95)
              : accent.withValues(alpha: hover ? 0.95 : 0.6),
      );

      if (!occupied && hover) {
        canvas.drawCircle(
          pos,
          _scaleLength(selectedKind.range),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = selectedKind.color.withValues(alpha: 0.22),
        );
      }

      if (selected && occupied) {
        final range = engine.towerRangeOnPad(pad.index);
        if (range != null) {
          canvas.drawCircle(
            pos,
            _scaleLength(range),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.3
              ..color = const Color(0xFFFDE047).withValues(alpha: 0.22),
          );
        }
      }
    }
  }

  void _drawTowers(Canvas canvas) {
    final towers = engine.world.query2<PositionC, TowerC>().toList(
      growable: false,
    );
    for (final q in towers) {
      final pos = _toScreen(q.component1.offset);
      final tower = q.component2;

      final baseR = _scaleLength(15).clamp(8.0, 24.0);
      final coreR = baseR * 0.62;

      canvas.drawCircle(pos, baseR, Paint()..color = const Color(0xFF0F172A));
      canvas.drawCircle(
        pos,
        baseR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = tower.kind.color.withValues(alpha: 0.75),
      );

      switch (tower.kind) {
        case TdTowerKind.pulse:
          canvas.drawCircle(pos, coreR, Paint()..color = tower.kind.color);
          break;
        case TdTowerKind.cannon:
          canvas.drawRect(
            Rect.fromCenter(
              center: pos,
              width: coreR * 1.8,
              height: coreR * 1.1,
            ),
            Paint()..color = tower.kind.color,
          );
          break;
        case TdTowerKind.freezer:
          final p = Path();
          final spikes = 6;
          for (var i = 0; i < spikes; i++) {
            final a = (math.pi * 2 / spikes) * i;
            final p1 = pos + Offset(math.cos(a), math.sin(a)) * coreR * 1.2;
            if (i == 0) {
              p.moveTo(p1.dx, p1.dy);
            } else {
              p.lineTo(p1.dx, p1.dy);
            }
          }
          p.close();
          canvas.drawPath(p, Paint()..color = tower.kind.color);
          break;
      }
    }
  }

  void _drawCreeps(Canvas canvas) {
    final creeps = engine.world.query2<PositionC, CreepC>().toList(
      growable: false,
    );
    for (final q in creeps) {
      final pos = _toScreen(q.component1.offset);
      final creep = q.component2;

      final radius = _scaleLength(creep.radius).clamp(6.0, 24.0);
      final isSlowed = creep.slowFactor < 0.999;

      canvas.drawCircle(
        pos + Offset(radius * 0.2, radius * 0.22),
        radius * 0.92,
        Paint()..color = Colors.black.withValues(alpha: 0.30),
      );

      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = isSlowed
              ? const Color(0xFF1D3E38)
              : const Color(0xFF402039),
      );

      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = Colors.white.withValues(alpha: 0.28),
      );

      canvas.drawCircle(
        pos + Offset(-radius * 0.32, -radius * 0.34),
        radius * 0.20,
        Paint()..color = Colors.white.withValues(alpha: 0.24),
      );

      if (isSlowed) {
        canvas.drawCircle(
          pos,
          radius * 1.3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white.withValues(alpha: 0.10),
        );
      }

      final hpPct = (creep.hp / creep.maxHp).clamp(0.0, 1.0);
      if (hpPct < 1) {
        final barW = radius * 1.8;
        final barTop = pos + Offset(-barW * 0.5, -radius - 8);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(barTop.dx, barTop.dy, barW, 4),
            const Radius.circular(2),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.45),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(barTop.dx, barTop.dy, barW * hpPct, 4),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFF4ADE80),
        );
      }
    }
  }

  void _drawProjectiles(Canvas canvas) {
    final projectiles = engine.world
        .query3<PositionC, VelocityC, ProjectileC>()
        .toList(growable: false);
    for (final q in projectiles) {
      final pos = _toScreen(q.component1.offset);
      final vel = q.component2;
      final projectile = q.component3;
      final color = projectile.source.color;

      final baseR = _scaleLength(projectile.radius).clamp(3.2, 14.0);
      final worldVel = Offset(vel.x, vel.y);
      final speed = worldVel.distance;
      final dir = speed <= 1e-6 ? const Offset(1, 0) : worldVel / speed;
      final dirLen = _scaleLength(1).clamp(0.1, 4.5);
      final screenDir = dir * dirLen;

      final trailLen = (baseR * 1.8 + speed * 0.010).clamp(6.0, 34.0);
      final tail = pos - screenDir * trailLen;

      canvas.drawLine(
        tail,
        pos,
        Paint()
          ..blendMode = BlendMode.plus
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (baseR * 1.45).clamp(3.0, 12.0)
          ..color = color.withValues(alpha: 0.24),
      );

      canvas.drawLine(
        tail + screenDir * (trailLen * 0.30),
        pos,
        Paint()
          ..blendMode = BlendMode.plus
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (baseR * 0.72).clamp(1.6, 6.0)
          ..color = Colors.white.withValues(alpha: 0.62),
      );

      canvas.drawCircle(
        pos,
        baseR * 1.75,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = color.withValues(alpha: 0.20),
      );

      canvas.drawCircle(
        pos,
        baseR,
        Paint()..color = color.withValues(alpha: 0.98),
      );
      canvas.drawCircle(
        pos,
        baseR * 0.45,
        Paint()..color = Colors.white.withValues(alpha: 0.88),
      );

      if (projectile.splashRadius > 0) {
        canvas.drawCircle(
          pos,
          baseR + 2.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..color = color.withValues(alpha: 0.62),
        );
      }
    }
  }

  void _drawImpactFx(Canvas canvas) {
    final effects = engine.world.query2<PositionC, ImpactFxC>().toList(
      growable: false,
    );
    for (final q in effects) {
      final pos = _toScreen(q.component1.offset);
      final fx = q.component2;

      final t = (1.0 - (fx.ttl / fx.duration)).clamp(0.0, 1.0);
      final eased = 1.0 - math.pow(1.0 - t, 2).toDouble();

      final r = _scaleLength(fx.maxRadius * eased).clamp(2.0, 220.0);
      final alpha = (1.0 - t).clamp(0.0, 1.0);
      final color = fx.source.color;

      canvas.drawCircle(
        pos,
        r,
        Paint()..color = color.withValues(alpha: 0.18 * alpha),
      );
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: 0.85 * alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant TdWorldPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.engine != engine ||
        oldDelegate.selectedKind != selectedKind ||
        oldDelegate.hoveredPadIndex != hoveredPadIndex ||
        oldDelegate.selectedPadIndex != selectedPadIndex;
  }
}

class TdWorldFxPainter extends CustomPainter {
  final Matrix4 transform;
  final TdGameEngine engine;
  final ui.FragmentProgram? orbProgram;

  TdWorldFxPainter({
    required this.transform,
    required this.engine,
    required this.orbProgram,
    super.repaint,
  });

  Offset _toScreen(Offset world) =>
      MatrixUtils.transformPoint(transform, world);

  double _scaleLength(double worldLen) {
    final a = MatrixUtils.transformPoint(transform, Offset.zero);
    final b = MatrixUtils.transformPoint(transform, Offset(worldLen, 0));
    return (b - a).distance;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawTowerAuras(canvas);
    _drawCreepFx(canvas);
    _drawProjectileFx(canvas);
    _drawImpactFx(canvas);
  }

  void _drawTowerAuras(Canvas canvas) {
    final towers = engine.world.query2<PositionC, TowerC>().toList(
      growable: false,
    );
    for (final q in towers) {
      final pos = _toScreen(q.component1.offset);
      final baseR = _scaleLength(18).clamp(10.0, 32.0);
      final tower = q.component2;
      _drawOrb(
        canvas,
        center: pos,
        radius: baseR * 1.45,
        style: 2.0,
        intensity: 1.02,
        state: tower.kind.index.toDouble(),
        seed: q.entity.hashCode.toDouble() * 0.017,
      );
    }
  }

  void _drawProjectileFx(Canvas canvas) {
    final projectiles = engine.world
        .query3<PositionC, VelocityC, ProjectileC>()
        .toList(growable: false);
    for (final q in projectiles) {
      final pos = _toScreen(q.component1.offset);
      final vel = q.component2;
      final projectile = q.component3;
      final speedBoost = (Offset(vel.x, vel.y).distance * 0.0018).clamp(
        0.0,
        1.0,
      );
      final radius =
          _scaleLength(projectile.radius).clamp(2.0, 14.0) *
          (1.18 + speedBoost);
      _drawOrb(
        canvas,
        center: pos,
        radius: radius * 1.72,
        style: 0.0,
        intensity: 1.16 + speedBoost * 0.45,
        state: projectile.source.index.toDouble(),
        seed: q.entity.hashCode.toDouble() * 0.019,
      );
    }
  }

  void _drawCreepFx(Canvas canvas) {
    final creeps = engine.world.query2<PositionC, CreepC>().toList(
      growable: false,
    );
    for (final q in creeps) {
      final pos = _toScreen(q.component1.offset);
      final creep = q.component2;
      final isSlowed = creep.slowFactor < 0.999;
      final radius = _scaleLength(creep.radius).clamp(6.0, 24.0);

      _drawOrb(
        canvas,
        center: pos,
        radius: radius * 2.1,
        style: 3.0,
        intensity: isSlowed ? 1.18 : 1.10,
        state: isSlowed ? 1.0 : 0.0,
        seed: q.entity.hashCode.toDouble() * 0.013,
      );
    }
  }

  void _drawImpactFx(Canvas canvas) {
    final impacts = engine.world.query2<PositionC, ImpactFxC>().toList(
      growable: false,
    );
    for (final q in impacts) {
      final pos = _toScreen(q.component1.offset);
      final fx = q.component2;
      final t = (1.0 - (fx.ttl / fx.duration)).clamp(0.0, 1.0);
      final radius = _scaleLength(
        fx.maxRadius * (0.20 + t * 0.80),
      ).clamp(8.0, 240.0);
      final alpha = (1.0 - t).clamp(0.0, 1.0);
      _drawOrb(
        canvas,
        center: pos,
        radius: radius,
        style: 1.0,
        intensity: 1.45 * alpha,
        state: fx.source.index.toDouble(),
        seed: q.entity.hashCode.toDouble() * 0.023,
      );
    }
  }

  void _drawOrb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double style,
    required double intensity,
    required double state,
    required double seed,
  }) {
    final floorColor = _orbFloorColor(style: style, state: state);
    canvas.drawCircle(
      center,
      radius * 0.96,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = floorColor.withValues(
          alpha: (0.16 * intensity).clamp(0.0, 0.55),
        ),
    );

    final drawRect = Rect.fromCircle(center: center, radius: radius * 1.25);

    if (orbProgram == null) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = floorColor.withValues(alpha: 0.34),
      );
      return;
    }

    final shader = orbProgram!.fragmentShader();
    shader.setFloat(0, center.dx);
    shader.setFloat(1, center.dy);
    shader.setFloat(2, radius);
    shader.setFloat(3, engine.elapsedSeconds);
    shader.setFloat(4, style);
    shader.setFloat(5, intensity);
    shader.setFloat(6, state);
    shader.setFloat(7, seed);

    canvas.drawRect(
      drawRect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = shader,
    );
  }

  Color _orbFloorColor({required double style, required double state}) {
    Color sourceColorFromState() {
      if (state < 0.5) return const Color(0xFF4EA8DE); // pulse
      if (state < 1.5) return const Color(0xFFE76F51); // cannon
      return const Color(0xFF80ED99); // freezer
    }

    if (style < 0.5) {
      return sourceColorFromState();
    }
    if (style < 1.5) {
      return sourceColorFromState().withValues(alpha: 0.95);
    }
    if (style < 2.5) {
      return sourceColorFromState();
    }
    final slowed = state >= 0.5;
    return slowed ? const Color(0xFF80ED99) : const Color(0xFFF43F5E);
  }

  @override
  bool shouldRepaint(covariant TdWorldFxPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.engine != engine ||
        oldDelegate.orbProgram != orbProgram;
  }
}

class TdPathFxPainter extends CustomPainter {
  final Matrix4 transform;
  final TdGameEngine engine;
  final ui.FragmentProgram? lineProgram;

  TdPathFxPainter({
    required this.transform,
    required this.engine,
    required this.lineProgram,
    super.repaint,
  });

  Offset _toScreen(Offset world) =>
      MatrixUtils.transformPoint(transform, world);

  double _scaleLength(double worldLen) {
    final a = MatrixUtils.transformPoint(transform, Offset.zero);
    final b = MatrixUtils.transformPoint(transform, Offset(worldLen, 0));
    return (b - a).distance;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final points = engine.pathPoints;
    if (points.length < 2) return;

    final baseWidth = _scaleLength(26).clamp(8.0, 34.0);

    for (var i = 0; i < points.length - 1; i++) {
      final a = _toScreen(points[i]);
      final b = _toScreen(points[i + 1]);
      final seedBase = (i + 1) * 0.731;

      _drawBeam(
        canvas,
        a: a,
        b: b,
        width: baseWidth * 1.70,
        intensity: 1.35,
        variant: 0.0,
        seed: seedBase,
      );

      _drawBeam(
        canvas,
        a: a,
        b: b,
        width: baseWidth * 0.90,
        intensity: 1.95,
        variant: 1.0,
        seed: seedBase + 1.337,
      );
    }
  }

  void _drawBeam(
    Canvas canvas, {
    required Offset a,
    required Offset b,
    required double width,
    required double intensity,
    required double variant,
    required double seed,
  }) {
    final floorColor = variant < 0.5
        ? const Color(0xFF50C8FF)
        : const Color(0xFFFF4DD2);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..blendMode = BlendMode.plus
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width * 0.84
        ..color = floorColor.withValues(
          alpha: (0.18 * intensity).clamp(0.0, 0.6),
        ),
    );

    if (lineProgram == null) {
      canvas.drawLine(
        a,
        b,
        Paint()
          ..blendMode = BlendMode.plus
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width
          ..color = floorColor.withValues(alpha: 0.34),
      );
      return;
    }

    final pad = width * 2.4;
    final drawRect = Rect.fromLTRB(
      math.min(a.dx, b.dx) - pad,
      math.min(a.dy, b.dy) - pad,
      math.max(a.dx, b.dx) + pad,
      math.max(a.dy, b.dy) + pad,
    );

    final shader = lineProgram!.fragmentShader();
    shader.setFloat(0, a.dx);
    shader.setFloat(1, a.dy);
    shader.setFloat(2, b.dx);
    shader.setFloat(3, b.dy);
    shader.setFloat(4, width);
    shader.setFloat(5, engine.elapsedSeconds);
    shader.setFloat(6, intensity);
    shader.setFloat(7, variant);
    shader.setFloat(8, seed);

    canvas.drawRect(
      drawRect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant TdPathFxPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.engine != engine ||
        oldDelegate.lineProgram != lineProgram;
  }
}
