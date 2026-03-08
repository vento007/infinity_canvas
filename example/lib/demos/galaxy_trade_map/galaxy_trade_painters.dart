import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'galaxy_trade_models.dart';

class GalaxyBackdropPainter extends CustomPainter {
  final Matrix4 transform;
  final GalaxyTradeScene scene;
  final double Function() readTimeSeconds;
  final double Function() readDustStrength;

  GalaxyBackdropPainter({
    required this.transform,
    required this.scene,
    required this.readTimeSeconds,
    required this.readDustStrength,
    required super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final timeSeconds = readTimeSeconds();
    final dustStrength = readDustStrength().clamp(0.0, 8.0);
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF02050F), Color(0xFF061225), Color(0xFF040816)],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.1, -0.15),
          radius: 1.20,
          colors: [
            const Color(0xFF27438A).withValues(alpha: 0.24),
            const Color(0x00000000),
          ],
        ).createShader(rect),
    );

    final scale = transform.storage[0].abs().clamp(0.03, 4.0);
    final tx = transform.storage[12];
    final ty = transform.storage[13];
    final depthStrength = _depthStrength(scale);
    final coreCenter = scene.bounds.center;
    final coreRx = scene.bounds.width * 0.5;
    final coreRy = scene.bounds.height * 0.5;

    void drawNebulaBand(double minDepth, double maxDepth) {
      for (final nebula in scene.nebulas) {
        if (nebula.depth < minDepth || nebula.depth >= maxDepth) continue;
        final halo = _haloFalloff(nebula.center, coreCenter, coreRx, coreRy);
        if (halo <= 0.01) continue;

        final p = _parallaxPoint(nebula.center, nebula.depth, tx, ty, scale);
        final depthScale = 0.58 + nebula.depth * 0.90;
        final r = nebula.radius * scale * depthScale;
        if (r < 6) continue;
        if (!_intersectsScreen(size, p, r)) continue;

        final depthFog = _depthFog(nebula.depth);
        final wobble =
            0.90 +
            0.10 *
                math.sin(
                  timeSeconds * (0.12 + nebula.depth * 0.20) + nebula.phase,
                );
        final drift =
            (3.0 + nebula.depth * 8.0) * (0.40 + 0.60 * depthStrength);
        final center = p.translate(
          math.sin(timeSeconds * (0.09 + nebula.depth * 0.16) + nebula.phase) *
              drift,
          math.cos(
                timeSeconds * (0.08 + nebula.depth * 0.15) + nebula.phase * 1.3,
              ) *
              drift,
        );

        final circle = Rect.fromCircle(center: center, radius: r * wobble);
        final coreAlpha =
            ((0.10 + 0.18 * depthFog) *
                    (0.55 + 0.45 * depthStrength) *
                    (0.35 + 0.65 * halo))
                .clamp(0.018, 0.30);
        final midAlpha =
            ((0.03 + 0.09 * depthFog) *
                    (0.45 + 0.55 * depthStrength) *
                    (0.25 + 0.75 * halo))
                .clamp(0.01, 0.16);
        canvas.drawCircle(
          center,
          r * wobble,
          Paint()
            ..shader = RadialGradient(
              colors: [
                nebula.color.withValues(alpha: coreAlpha),
                nebula.color.withValues(alpha: midAlpha),
                Colors.transparent,
              ],
              stops: const [0.0, 0.44, 1.0],
            ).createShader(circle),
        );
      }
    }

    void drawStarBand(double minDepth, double maxDepth) {
      for (final star in scene.stars) {
        if (star.depth < minDepth || star.depth >= maxDepth) continue;
        final halo = _haloFalloff(star.position, coreCenter, coreRx, coreRy);
        if (halo <= 0.002) continue;

        final p = _parallaxPoint(star.position, star.depth, tx, ty, scale);
        if (p.dx < -36 ||
            p.dy < -36 ||
            p.dx > size.width + 36 ||
            p.dy > size.height + 36) {
          continue;
        }

        final twinkle =
            0.45 +
            0.55 * math.sin(timeSeconds * star.twinkleSpeed + star.phase);
        final sparkleSeed = _starRand(star, 15.3);
        final sparkleEnabled = sparkleSeed > 0.95; // ~5% of stars.
        final sparkleFreq = 0.03 + _starRand(star, 1.7) * 0.17;
        final sparkleDuty = 0.94 + _starRand(star, 9.1) * 0.05;
        final sparkleWave = sparkleEnabled
            ? (0.5 +
                  0.5 *
                      math.sin(
                        timeSeconds * sparkleFreq * math.pi * 2 +
                            star.phase * (1.2 + _starRand(star, 3.4)),
                      ))
            : 0.0;
        final sparkle = sparkleEnabled
            ? _smoothstep(sparkleDuty, 1.0, sparkleWave)
            : 0.0;
        final sparkleGain = sparkleSeed > 0.992
            ? 1.15
            : (sparkleSeed > 0.972 ? 0.85 : 0.60);
        final depthFog = _depthFog(star.depth);
        final radius =
            (0.28 + star.magnitude * 0.76) *
            (0.52 + star.depth * 1.24) *
            (0.82 + 0.18 * scale.clamp(0.4, 1.7));
        final shimmer = 0.78 + 0.22 * twinkle;
        final sparkleBoost =
            1.0 + sparkle * (0.22 + star.magnitude * 0.22) * sparkleGain;
        final alpha =
            (0.12 + twinkle * 0.58) *
            (0.35 + depthFog * 0.75) *
            (0.65 + 0.35 * depthStrength) *
            shimmer *
            sparkleBoost *
            (0.18 + 0.82 * halo);

        canvas.drawCircle(
          p,
          radius,
          Paint()..color = star.color.withValues(alpha: alpha.clamp(0.06, 0.9)),
        );

        if (star.magnitude > 1.05 && sparkle > 0.14) {
          canvas.drawCircle(
            p,
            radius * (1.4 + star.depth * 0.9) * (1.0 + sparkle * 0.35),
            Paint()
              ..color = star.color.withValues(
                alpha:
                    (0.03 + twinkle * 0.18) *
                    (0.28 + depthFog * 0.72) *
                    (0.16 + sparkle * 0.30) *
                    (0.62 + 0.38 * depthStrength) *
                    (0.20 + 0.80 * halo),
              ),
          );
        }

        if (sparkleGain > 1.0 && sparkle > 0.92) {
          canvas.drawCircle(
            p,
            radius * (1.7 + sparkle * 1.0),
            Paint()
              ..color = star.color.withValues(
                alpha:
                    (0.03 + sparkle * 0.10) *
                    (0.35 + depthFog * 0.65) *
                    (0.24 + 0.76 * halo),
              ),
          );
        }
      }
    }

    void drawDustBand(double minDepth, double maxDepth) {
      if (dustStrength <= 0.0) return;
      for (final mote in scene.dustMotes) {
        if (mote.depth < minDepth || mote.depth >= maxDepth) continue;
        final halo = _haloFalloff(mote.position, coreCenter, coreRx, coreRy);
        if (halo <= 0.006) continue;

        final p = _parallaxPoint(mote.position, mote.depth, tx, ty, scale);
        if (p.dx < -28 ||
            p.dy < -28 ||
            p.dx > size.width + 28 ||
            p.dy > size.height + 28) {
          continue;
        }

        final flicker =
            0.5 +
            0.5 *
                math.sin(
                  timeSeconds * mote.flickerSpeed * math.pi * 2 + mote.phase,
                );
        final depthFog = _depthFog(mote.depth);
        final radius =
            (0.14 + mote.size * 0.74) *
            (0.48 + mote.depth * 0.84) *
            (0.82 + 0.18 * scale.clamp(0.4, 1.7));
        final radiusMul = 0.6 + 0.4 * dustStrength;
        final alpha =
            (0.040 + flicker * 0.110) *
            (0.34 + depthFog * 0.66) *
            (0.60 + 0.40 * depthStrength) *
            (0.16 + 0.84 * halo) *
            dustStrength;

        canvas.drawCircle(
          p,
          radius * 1.25 * radiusMul,
          Paint()
            ..color = mote.color.withValues(alpha: alpha.clamp(0.01, 0.58)),
        );

        if (mote.size > 0.95 && flicker > 0.66) {
          canvas.drawCircle(
            p,
            radius * 2.3 * radiusMul,
            Paint()
              ..color = mote.color.withValues(
                alpha:
                    (0.016 + flicker * 0.055) *
                    (0.24 + depthFog * 0.76) *
                    (0.20 + 0.80 * halo) *
                    (0.8 + 0.2 * dustStrength),
              ),
          );
        }
      }
    }

    // Far -> near order creates a strong fake depth stack.
    drawNebulaBand(0.0, 0.34);
    drawNebulaBand(0.34, 0.70);
    drawNebulaBand(0.70, 1.01);
    drawStarBand(0.0, 0.34);
    drawStarBand(0.34, 0.70);
    drawStarBand(0.70, 1.01);
    drawDustBand(0.0, 0.34);
    drawDustBand(0.34, 0.70);
    drawDustBand(0.70, 1.01);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)],
          stops: const [0.72, 1.0],
        ).createShader(rect),
    );
  }

  bool _intersectsScreen(Size size, Offset center, double radius) {
    return center.dx + radius >= 0 &&
        center.dy + radius >= 0 &&
        center.dx - radius <= size.width &&
        center.dy - radius <= size.height;
  }

  Offset _parallaxPoint(
    Offset world,
    double depth,
    double tx,
    double ty,
    double scale,
  ) {
    final p = MatrixUtils.transformPoint(transform, world);
    final factor = _parallaxFactor(depth, scale);
    return p.translate(tx * (factor - 1.0), ty * (factor - 1.0));
  }

  double _parallaxFactor(double depth, double scale) {
    final d = depth.clamp(0.0, 1.0);
    final base = 0.20 + d * 0.80;
    final strength = _depthStrength(scale);
    return 1.0 + (base - 1.0) * strength;
  }

  double _depthFog(double depth) {
    final d = depth.clamp(0.0, 1.0);
    return 0.28 + d * 0.72;
  }

  double _depthStrength(double scale) {
    return ((scale - 0.09) / 0.34).clamp(0.0, 1.0);
  }

  double _starRand(GalaxyStar star, double salt) {
    final x =
        math.sin(
          star.phase * 12.9898 +
              star.magnitude * 78.233 +
              star.depth * 37.719 +
              salt * 19.19,
        ) *
        43758.5453;
    return x - x.floorToDouble();
  }

  double _smoothstep(double edge0, double edge1, double x) {
    if (edge1 <= edge0) return x >= edge1 ? 1.0 : 0.0;
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  double _haloFalloff(
    Offset world,
    Offset center,
    double coreRadiusX,
    double coreRadiusY,
  ) {
    final nx =
        (world.dx - center.dx) / (coreRadiusX <= 1e-6 ? 1.0 : coreRadiusX);
    final ny =
        (world.dy - center.dy) / (coreRadiusY <= 1e-6 ? 1.0 : coreRadiusY);
    final d = math.sqrt(nx * nx + ny * ny);
    if (d <= 1.0) return 1.0;
    if (d >= 3.05) return 0.0;
    final t = ((d - 1.0) / 2.05).clamp(0.0, 1.0);
    final eased = 1.0 - t;
    return eased * eased;
  }

  @override
  bool shouldRepaint(covariant GalaxyBackdropPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.scene != scene ||
        oldDelegate.readTimeSeconds != readTimeSeconds ||
        oldDelegate.readDustStrength != readDustStrength;
  }
}

class GalaxyTradeRoutesPainter extends CustomPainter {
  final Matrix4 transform;
  final GalaxyTradeScene scene;
  final List<TradeShipment> shipments;
  final String? selectedSystemId;
  final String? hoveredSystemId;
  final bool flowEnabled;
  final double Function() readTimeSeconds;

  GalaxyTradeRoutesPainter({
    required this.transform,
    required this.scene,
    required this.shipments,
    required this.selectedSystemId,
    required this.hoveredSystemId,
    required this.flowEnabled,
    required this.readTimeSeconds,
    required super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final timeSeconds = readTimeSeconds();
    final scale = transform.storage[0].abs().clamp(0.03, 4.0);

    for (final route in scene.routes) {
      final from = scene.systems[route.fromIndex];
      final to = scene.systems[route.toIndex];
      final a = MatrixUtils.transformPoint(transform, from.center);
      final b = MatrixUtils.transformPoint(transform, to.center);

      final segmentBounds = Rect.fromPoints(a, b).inflate(140);
      if (!segmentBounds.overlaps(Offset.zero & size)) {
        continue;
      }

      final selected =
          selectedSystemId != null &&
          (from.id == selectedSystemId || to.id == selectedSystemId);
      final hovered =
          hoveredSystemId != null &&
          (from.id == hoveredSystemId || to.id == hoveredSystemId);
      final hot = selected || hovered;

      final coreWidth = (0.9 + route.capacity * 1.9) * scale.clamp(0.55, 1.45);
      final glowWidth = coreWidth + (hot ? 5.4 : 3.1);
      final color = route.color;

      canvas.drawLine(
        a,
        b,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = glowWidth
          ..color = color.withValues(alpha: hot ? 0.26 : 0.16),
      );

      canvas.drawLine(
        a,
        b,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = coreWidth
          ..color = color.withValues(alpha: hot ? 0.86 : 0.57),
      );

      if (!flowEnabled) continue;

      final flowBase = (timeSeconds * route.flowSpeed + route.flowOffset) % 1;
      for (var i = 0; i < 2; i++) {
        final t = (flowBase + i * 0.5) % 1;
        final p = Offset.lerp(a, b, t);
        if (p == null) continue;
        final pulse = 0.6 + 0.4 * math.sin(timeSeconds * 2.3 + i * 1.7);
        final r = (1.2 + route.capacity * 2.0) * pulse;

        canvas.drawCircle(
          p,
          r * 2.2,
          Paint()..color = color.withValues(alpha: 0.12 + 0.15 * pulse),
        );
        canvas.drawCircle(
          p,
          r,
          Paint()..color = Colors.white.withValues(alpha: 0.75),
        );
      }
    }

    for (final shipment in shipments) {
      if (shipment.routeIndex < 0 ||
          shipment.routeIndex >= scene.routes.length) {
        continue;
      }
      final route = scene.routes[shipment.routeIndex];
      final from = scene.systems[route.fromIndex].center;
      final to = scene.systems[route.toIndex].center;

      final world = Offset.lerp(from, to, shipment.progress);
      if (world == null) continue;

      final p = MatrixUtils.transformPoint(transform, world);
      if (p.dx < -80 ||
          p.dy < -80 ||
          p.dx > size.width + 80 ||
          p.dy > size.height + 80) {
        continue;
      }

      final r = (1.3 + shipment.size * 1.3) * scale.clamp(0.56, 1.6);
      final color = shipment.color;

      final trailT = (shipment.progress - 0.04).clamp(0.0, 1.0);
      final trailWorld = Offset.lerp(from, to, trailT);
      if (trailWorld != null) {
        final trail = MatrixUtils.transformPoint(transform, trailWorld);
        canvas.drawLine(
          trail,
          p,
          Paint()
            ..strokeWidth = r * 1.2
            ..strokeCap = StrokeCap.round
            ..color = color.withValues(alpha: 0.34),
        );
      }

      canvas.drawCircle(
        p,
        r * 2.6,
        Paint()..color = color.withValues(alpha: 0.14),
      );
      canvas.drawCircle(p, r, Paint()..color = color);
      canvas.drawCircle(
        p,
        r * 0.50,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant GalaxyTradeRoutesPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.scene != scene ||
        oldDelegate.shipments != shipments ||
        oldDelegate.selectedSystemId != selectedSystemId ||
        oldDelegate.hoveredSystemId != hoveredSystemId ||
        oldDelegate.flowEnabled != flowEnabled ||
        oldDelegate.readTimeSeconds != readTimeSeconds;
  }
}

class GalaxyMeteorsPainter extends CustomPainter {
  final Matrix4 transform;
  final List<GalaxyMeteor> meteors;

  GalaxyMeteorsPainter({
    required this.transform,
    required this.meteors,
    required super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = transform.storage[0].abs().clamp(0.03, 4.0);
    if (meteors.isEmpty) return;

    for (final meteor in meteors) {
      final speed = meteor.velocity.distance;
      if (speed <= 1e-6) continue;

      final dir = Offset(
        meteor.velocity.dx / speed,
        meteor.velocity.dy / speed,
      );
      final tailWorld =
          meteor.position -
          Offset(dir.dx * meteor.length, dir.dy * meteor.length);

      final head = MatrixUtils.transformPoint(transform, meteor.position);
      final tail = MatrixUtils.transformPoint(transform, tailWorld);

      final bounds = Rect.fromPoints(head, tail).inflate(120);
      if (!bounds.overlaps(Offset.zero & size)) {
        continue;
      }

      final lifeT = (meteor.life / meteor.maxLife).clamp(0.0, 1.0);
      final width =
          (meteor.width * scale).clamp(0.8, 5.5) * (0.65 + 0.35 * lifeT);
      final color = meteor.color;

      canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width * 3.6
          ..color = color.withValues(alpha: 0.05 + 0.16 * lifeT),
      );

      canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width
          ..color = color.withValues(alpha: 0.40 + 0.50 * lifeT),
      );

      canvas.drawCircle(
        head,
        width * 1.4,
        Paint()..color = Colors.white.withValues(alpha: 0.75 * lifeT + 0.20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant GalaxyMeteorsPainter oldDelegate) {
    return oldDelegate.transform != transform || oldDelegate.meteors != meteors;
  }
}
