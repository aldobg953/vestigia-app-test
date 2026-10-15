import 'package:flutter/material.dart';

import '../torn_photo.dart';

/// Reverso de la fotografía armada: papel con las grietas de los cortes
/// (en espejo) y la segunda parte de las coordenadas escrita a mano.
class PhotoBackView extends StatelessWidget {
  const PhotoBackView({
    super.key,
    required this.photo,
    required this.scale,
    required this.text,
  });

  static const textKey = Key('photo-back-text');

  final TornPhoto photo;
  final double scale;
  final String text;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackPainter(photo: photo, scale: scale),
      child: Center(
        child: Transform.rotate(
          angle: -0.07,
          child: Text(
            text,
            key: textKey,
            style: TextStyle(
              fontFamily: 'serif',
              fontStyle: FontStyle.italic,
              fontSize: scale * 0.2,
              letterSpacing: scale * 0.03,
              color: const Color(0xFF2F2B4A),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackPainter extends CustomPainter {
  _BackPainter({required this.photo, required this.scale});

  final TornPhoto photo;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawShadow(Path()..addRect(rect), Colors.black, 6, false);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.9,
          colors: [Color(0xFFF2EAD6), Color(0xFFE2D5B6)],
        ).createShader(rect),
    );
    // Grietas de los cortes, vistas por detrás (en espejo).
    final crack = Paint()
      ..color = const Color(0xFFB9A784)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final piece in photo.pieces) {
      for (final edge in piece.tornEdges) {
        final mirrored = [
          for (final p in edge) Offset((1 - p.dx) * scale, p.dy * scale),
        ];
        canvas.drawPath(Path()..addPolygon(mirrored, false), crack);
      }
    }
  }

  @override
  bool shouldRepaint(_BackPainter old) =>
      old.photo != photo || old.scale != scale;
}
