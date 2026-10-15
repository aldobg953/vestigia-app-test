import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/celestial_target.dart';
import '../orientation_source.dart';

/// Projection shared with the lookout so its flash anticipates this target.
Offset? projectSkyDirection(
  PointingSample direction,
  PointingSample camera,
  Size size, {
  double fieldOfView = 80,
}) {
  const rad = pi / 180;
  final az = direction.azimuth * rad;
  final alt = direction.altitude * rad;
  final h = camera.azimuth * rad;
  final a = camera.altitude * rad;
  final east = sin(az) * cos(alt);
  final north = cos(az) * cos(alt);
  final up = sin(alt);
  final forward =
      east * sin(h) * cos(a) + north * cos(h) * cos(a) + up * sin(a);
  if (forward <= 0.01) return null;
  final right = east * cos(h) - north * sin(h);
  final vertical =
      -east * sin(h) * sin(a) - north * cos(h) * sin(a) + up * cos(a);
  final focal = size.shortestSide / (2 * tan(fieldOfView * rad / 2));
  return size.center(Offset.zero) +
      Offset(right, -vertical) * (focal / forward);
}

class SkyView extends StatelessWidget {
  const SkyView({super.key, required this.pointing, required this.revealed});

  final PointingSample pointing;
  final bool revealed;

  @override
  Widget build(BuildContext context) => ClipOval(
    child: CustomPaint(
      painter: _SkyPainter(pointing, revealed),
      child: const SizedBox.expand(),
    ),
  );
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.pointing, this.revealed);

  final PointingSample pointing;
  final bool revealed;
  static final stars = _stars();

  static List<PointingSample> _stars() {
    final random = Random(137042);
    return List.generate(
      650,
      (_) => PointingSample(
        random.nextDouble() * 360,
        asin(random.nextDouble() * 1.2 - 0.2) * 180 / pi,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF102B2E));
    final ink = Paint()..color = const Color(0xFFD3E7DD);
    for (var i = 0; i < stars.length; i++) {
      final p = projectSkyDirection(stars[i], pointing, size);
      if (p == null || !rect.contains(p)) continue;
      final radius = i % 13 == 0 ? 1.7 : 0.8;
      canvas.drawCircle(p, radius, ink);
      if (i % 13 == 0) {
        canvas.drawLine(p - const Offset(3, 0), p + const Offset(3, 0), ink);
      }
    }
    final target = projectSkyDirection(
      const PointingSample(
        PrototypeSky.azimuthDegrees,
        PrototypeSky.altitudeDegrees,
      ),
      pointing,
      size,
    );
    if (target != null && rect.contains(target)) {
      final light = Paint()..color = const Color(0xFFF0B7D2);
      canvas.drawCircle(target, revealed ? 7 : 3, light);
      for (final angle in [0.0, pi / 4, pi / 2, pi * 3 / 4]) {
        final ray = Offset(cos(angle), sin(angle)) * (revealed ? 25 : 7);
        canvas.drawLine(target - ray, target + ray, light..strokeWidth = 1.4);
      }
      if (revealed) {
        canvas.drawOval(
          Rect.fromCenter(center: target, width: 68, height: 24),
          light..style = PaintingStyle.stroke,
        );
      }
    }
    final center = size.center(Offset.zero);
    final reticle = Paint()
      ..color = revealed ? const Color(0xFF7FD6A0) : const Color(0xFFD4A24C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 18, reticle);
    for (final axis in [const Offset(1, 0), const Offset(0, 1)]) {
      for (final sign in [-1, 1]) {
        canvas.drawLine(
          center + axis * (22.0 * sign),
          center + axis * (39.0 * sign),
          reticle,
        );
      }
    }
    canvas.drawCircle(
      center,
      size.shortestSide / 2 - 2,
      reticle..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.pointing != pointing || old.revealed != revealed;
}
