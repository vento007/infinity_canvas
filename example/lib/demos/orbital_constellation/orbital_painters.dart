import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'orbital_models.dart';

class OrbitalBackdropPainter extends CustomPainter {
  final Matrix4 transform;
  final OrbitalScene scene;
  final double Function() readTimeSeconds;
  final Listenable repaint;

  OrbitalBackdropPainter({
    required this.transform,
    required this.scene,
    required this.readTimeSeconds,
    required this.repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final t = readTimeSeconds();
    final screenRect = Offset.zero & size;

    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF02060F), Color(0xFF060B19), Color(0xFF090C16)],
      ).createShader(screenRect);
    canvas.drawRect(screenRect, bg);

    final visibleWorld = _computeVisibleWorldRect(
      transform,
      size,
    ).inflate(1800);
    final twinkleBase = 0.5 + 0.5 * math.sin(t * 0.13);

    final m = transform.storage;
    final zoom = m[0].abs().clamp(0.001, 1000.0);
    final tx = m[12];
    final ty = m[13];

    // Screen-space parallax stars for depth.
    for (final star in scene.stars) {
      if (!visibleWorld.contains(star.position)) continue;
      final px = star.position.dx * zoom + tx * star.depth;
      final py = star.position.dy * zoom + ty * star.depth;
      final flicker =
          0.55 +
          0.45 *
              math.sin(t * star.twinkleSpeed + star.phase + twinkleBase * 0.85);
      final alpha = (0.12 + 0.46 * flicker * star.depth).clamp(0.0, 1.0);
      final radius = (star.size * (0.55 + star.depth * 0.9)).clamp(0.35, 3.6);

      canvas.drawCircle(
        Offset(px, py),
        radius,
        Paint()..color = star.color.withValues(alpha: alpha),
      );
    }

    canvas.save();
    canvas.transform(transform.storage);

    // Large nebula glow around hubs.
    for (final hub in scene.hubs) {
      if (!visibleWorld.contains(hub.center)) continue;
      final pulse = 0.78 + 0.22 * math.sin(t * 0.5 + hub.center.dx * 0.0006);
      final glowRadius = hub.coreRadius * (10.5 + pulse * 3.2);
      canvas.drawCircle(
        hub.center,
        glowRadius,
        Paint()
          ..color = hub.color.withValues(alpha: 0.028)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
      );
      canvas.drawCircle(
        hub.center,
        glowRadius * 0.55,
        Paint()
          ..color = hub.color.withValues(alpha: 0.055)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OrbitalBackdropPainter oldDelegate) {
    return oldDelegate.transform != transform || oldDelegate.scene != scene;
  }
}

class OrbitalNetworkPainter extends CustomPainter {
  final Matrix4 transform;
  final OrbitalScene scene;
  final List<List<OrbitalBody>> bodiesByHub;
  final double Function() readTimeSeconds;
  final Listenable repaint;

  OrbitalNetworkPainter({
    required this.transform,
    required this.scene,
    required this.bodiesByHub,
    required this.readTimeSeconds,
    required this.repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final t = readTimeSeconds();
    final visibleWorld = _computeVisibleWorldRect(transform, size).inflate(900);

    canvas.save();
    canvas.transform(transform.storage);

    // Trade/relay lanes between hubs.
    for (final route in scene.routes) {
      final from = scene.hubs[route.fromHubIndex];
      final to = scene.hubs[route.toHubIndex];
      final bounds = Rect.fromPoints(from.center, to.center).inflate(120);
      if (!visibleWorld.overlaps(bounds)) continue;

      final lanePaint = Paint()
        ..color = const Color(0xFF63D8FF).withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.6;
      canvas.drawLine(from.center, to.center, lanePaint);

      final fluxPulse = 0.5 + 0.5 * math.sin(t * route.flux + route.phase);
      final fluxColor = Color.lerp(
        const Color(0xFF60E8FF),
        const Color(0xFFB4FAFF),
        fluxPulse,
      )!;

      for (var i = 0; i < 2; i++) {
        final p =
            ((t * 0.24 * route.flux) + route.phase * 0.12 + i * 0.47) % 1.0;
        final pos = Offset.lerp(from.center, to.center, p)!;
        canvas.drawCircle(
          pos,
          18,
          Paint()
            ..color = fluxColor.withValues(alpha: 0.08)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawCircle(
          pos,
          3.6,
          Paint()
            ..color = fluxColor.withValues(alpha: 0.95)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // Orbits and hub cores.
    for (var hubIndex = 0; hubIndex < scene.hubs.length; hubIndex++) {
      final hub = scene.hubs[hubIndex];
      final localBodies = bodiesByHub[hubIndex];

      final corePulse = 0.74 + 0.26 * math.sin(t * 1.1 + hubIndex * 0.81);
      final corePaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.96),
                hub.color.withValues(alpha: 0.94),
                hub.color.withValues(alpha: 0.08),
              ],
              stops: const [0.0, 0.52, 1.0],
            ).createShader(
              Rect.fromCircle(center: hub.center, radius: hub.coreRadius * 2.5),
            );
      canvas.drawCircle(
        hub.center,
        hub.coreRadius * (1.0 + 0.06 * corePulse),
        corePaint,
      );

      for (final body in localBodies) {
        final orbitPaint = Paint()
          ..color =
              (body.station ? const Color(0xFF95F9FF) : const Color(0xFF7CA6D3))
                  .withValues(alpha: body.station ? 0.14 : 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = body.station ? 1.4 : 0.9;
        canvas.drawCircle(hub.center, body.orbitRadius, orbitPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OrbitalNetworkPainter oldDelegate) {
    return oldDelegate.transform != transform || oldDelegate.scene != scene;
  }
}

Rect _computeVisibleWorldRect(Matrix4 transform, Size viewport) {
  final inverse = Matrix4.tryInvert(transform);
  if (inverse == null || viewport.isEmpty) {
    return Rect.fromLTWH(0, 0, 0, 0);
  }
  final p0 = MatrixUtils.transformPoint(inverse, Offset.zero);
  final p1 = MatrixUtils.transformPoint(inverse, Offset(viewport.width, 0));
  final p2 = MatrixUtils.transformPoint(inverse, Offset(0, viewport.height));
  final p3 = MatrixUtils.transformPoint(
    inverse,
    Offset(viewport.width, viewport.height),
  );

  final left = math.min(math.min(p0.dx, p1.dx), math.min(p2.dx, p3.dx));
  final right = math.max(math.max(p0.dx, p1.dx), math.max(p2.dx, p3.dx));
  final top = math.min(math.min(p0.dy, p1.dy), math.min(p2.dy, p3.dy));
  final bottom = math.max(math.max(p0.dy, p1.dy), math.max(p2.dy, p3.dy));
  return Rect.fromLTRB(left, top, right, bottom);
}
