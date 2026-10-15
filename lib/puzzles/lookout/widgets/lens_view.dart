import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/vestigia_theme.dart';

/// Ventana de observación del mirador: el panorama visto a través de un
/// lente redondo con retícula fija, la suciedad encima y un aro de cartón
/// alrededor (fuera del cristal, para que toda la superficie medible se vea).
class LensView extends StatelessWidget {
  const LensView({
    super.key,
    required this.diameter,
    required this.panorama,
    required this.panoramaAspect,
    required this.viewWidthFraction,
    required this.viewCenter,
    required this.target,
    required this.strokes,
    required this.strokesRevision,
    required this.brushRadius,
    required this.dirtOpacity,
    required this.aligned,
  });

  /// Grosor del aro de cartón, por fuera del cristal.
  static const rimWidth = 14.0;

  /// Diámetro del cristal (sin el aro).
  final double diameter;
  final ImageProvider panorama;
  final double panoramaAspect;
  final double viewWidthFraction;

  /// Centro de la vista dentro del panorama (0..1).
  final Offset viewCenter;

  /// Objetivo dentro del panorama (0..1).
  final Offset target;

  /// Trazos de limpieza en coordenadas del lente (0..1).
  final List<List<Offset>> strokes;
  final int strokesRevision;
  final double brushRadius;
  final double dirtOpacity;
  final bool aligned;

  @override
  Widget build(BuildContext context) {
    final imageWidth = diameter / viewWidthFraction;
    final imageHeight = imageWidth * panoramaAspect;
    return SizedBox.square(
      dimension: diameter + 2 * rimWidth,
      child: Stack(
        children: [
          Positioned(
            left: rimWidth,
            top: rimWidth,
            width: diameter,
            height: diameter,
            child: ClipOval(
              child: Stack(
                children: [
                  Positioned(
                    left: diameter / 2 - viewCenter.dx * imageWidth,
                    top: diameter / 2 - viewCenter.dy * imageHeight,
                    width: imageWidth,
                    height: imageHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image(
                          image: panorama,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                        ),
                        CustomPaint(painter: TargetPainter(target)),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(painter: _ReticlePainter(aligned)),
                  ),
                  if (dirtOpacity > 0)
                    Positioned.fill(
                      child: Opacity(
                        opacity: dirtOpacity,
                        child: CustomPaint(
                          painter: _DirtPainter(
                            strokes: strokes,
                            revision: strokesRevision,
                            brushRadius: brushRadius,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _RimPainter())),
          ),
        ],
      ),
    );
  }
}

/// Objetivo provisional: un observatorio recortado en papel sobre la
/// colina. Se dibuja encima del panorama para poder moverlo por
/// configuración.
class TargetPainter extends CustomPainter {
  TargetPainter(this.position, {this.scale = 1, this.pulse = 0});

  final Offset position;
  final double scale;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(position.dx * size.width, position.dy * size.height);
    final unit = size.width * 0.016 * scale;
    final paper = Paint()..color = const Color(0xFFEDE2C8);
    final ink = Paint()
      ..color = const Color(0xFF2E2620)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.12;

    // Edificio bajo la cúpula, hasta la ladera.
    final building = Rect.fromLTRB(
      c.dx - unit * 1.15,
      c.dy,
      c.dx + unit * 1.15,
      c.dy + unit * 2.6,
    );
    canvas.drawRect(building, paper);
    canvas.drawRect(building, ink);
    // Cúpula con su rendija.
    final dome = Rect.fromCircle(center: c, radius: unit * 1.15);
    canvas.drawArc(dome, pi, pi, true, paper);
    canvas.drawArc(dome, pi, pi, true, ink);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.5);
    canvas.drawRect(
      Rect.fromLTWH(-unit * 0.12, -unit * 1.1, unit * 0.24, unit * 1.0),
      Paint()..color = const Color(0xFF2E2620),
    );
    canvas.restore();
    // Puerta y ventana iluminada.
    canvas.drawRect(
      Rect.fromLTWH(c.dx - unit * 0.25, c.dy + unit * 1.6, unit * 0.5, unit),
      Paint()..color = const Color(0xFF2E2620),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        c.dx + unit * 0.45,
        c.dy + unit * 0.6,
        unit * 0.4,
        unit * 0.4,
      ),
      Paint()
        ..color = Color.lerp(
          const Color(0xFF594E43),
          const Color(0xFFFFEBA3),
          pulse,
        )!,
    );
    if (pulse > 0) {
      canvas.drawCircle(
        c,
        unit * 2.8,
        Paint()
          ..color = const Color(0xFFFFEBA3).withValues(alpha: pulse * 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit),
      );
    }
  }

  @override
  bool shouldRepaint(TargetPainter old) =>
      old.position != position || old.scale != scale || old.pulse != pulse;
}

class _ReticlePainter extends CustomPainter {
  _ReticlePainter(this.aligned);

  final bool aligned;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final color = aligned ? VestigiaColors.signal : const Color(0xE6F1E4C6);
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke;

    void cross(Paint p) {
      final gap = r * 0.06;
      canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx - gap, c.dy), p);
      canvas.drawLine(Offset(c.dx + gap, c.dy), Offset(c.dx + r, c.dy), p);
      canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy - gap), p);
      canvas.drawLine(Offset(c.dx, c.dy + gap), Offset(c.dx, c.dy + r), p);
      canvas.drawCircle(c, r * 0.16, p);
      for (var i = 1; i <= 4; i++) {
        final d = r * 0.2 * i;
        for (final s in [-1, 1]) {
          canvas.drawLine(
            Offset(c.dx + s * d, c.dy - r * 0.025),
            Offset(c.dx + s * d, c.dy + r * 0.025),
            p,
          );
          canvas.drawLine(
            Offset(c.dx - r * 0.025, c.dy + s * d),
            Offset(c.dx + r * 0.025, c.dy + s * d),
            p,
          );
        }
      }
    }

    cross(shadow);
    cross(line);
  }

  @override
  bool shouldRepaint(_ReticlePainter old) => old.aligned != aligned;
}

/// Suciedad del lente: capa de mugre con manchas, borrada por los trazos.
class _DirtPainter extends CustomPainter {
  _DirtPainter({
    required this.strokes,
    required this.revision,
    required this.brushRadius,
  });

  final List<List<Offset>> strokes;
  final int revision;
  final double brushRadius;

  /// Manchas fijas (posición, radio, tono) en coordenadas del lente.
  static final List<(Offset, double, Color)> _blotches = () {
    final random = Random(9);
    return [
      for (var i = 0; i < 70; i++)
        (
          Offset(random.nextDouble(), random.nextDouble()),
          0.03 + random.nextDouble() * 0.12,
          Color.lerp(
            const Color(0xFF4A3C2C),
            const Color(0xFF9C8A6A),
            random.nextDouble(),
          )!.withValues(alpha: 0.35 + random.nextDouble() * 0.4),
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = const Color(0xF2706048));
    for (final (center, radius, color) in _blotches) {
      canvas.drawCircle(
        Offset(center.dx * size.width, center.dy * size.height),
        radius * size.width,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            radius * size.width * 0.4,
          ),
      );
    }

    final width = brushRadius * 2 * size.width;
    final wipe = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dot = Paint()..blendMode = BlendMode.clear;
    for (final stroke in strokes) {
      final points = [
        for (final p in stroke) Offset(p.dx * size.width, p.dy * size.height),
      ];
      if (points.length == 1) {
        canvas.drawCircle(points.first, width / 2, dot);
      } else {
        canvas.drawPath(Path()..addPolygon(points, false), wipe);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DirtPainter old) =>
      old.revision != revision || old.brushRadius != brushRadius;
}

/// Aro de cartón alrededor del lente.
class _RimPainter extends CustomPainter {
  const _RimPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    const width = LensView.rimWidth;
    canvas.drawCircle(
      c,
      r - width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = const Color(0xFFB08A5C),
    );
    // Ondas del cartón corrugado.
    final corrugation = Paint()
      ..color = const Color(0x557A5A36)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 90; i++) {
      final a = i * 2 * pi / 90;
      final dir = Offset(cos(a), sin(a));
      canvas.drawLine(
        c + dir * (r - width + 2),
        c + dir * (r - 1),
        corrugation,
      );
    }
    canvas.drawCircle(
      c,
      r - width,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF4A3420),
    );
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF4A3420),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) => false;
}
