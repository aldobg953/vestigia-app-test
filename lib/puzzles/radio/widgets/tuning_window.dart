import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/vestigia_theme.dart';
import '../radio_config.dart';

/// Ventana de canales: escala, ondas y aguja.
///
/// La franja de la señal no se dibuja: el jugador debe encontrarla por el
/// sonido y por las ondas, que salen de la misma [strength] que el audio.
class TuningWindow extends StatelessWidget {
  const TuningWindow({
    super.key,
    required this.config,
    required this.dial,
    required this.strength,
    required this.time,
  });

  final RadioPuzzleConfig config;
  final double dial;
  final double strength;

  /// Segundos de animación; solo mueve las ondas.
  final double time;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VestigiaColors.brass, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: CustomPaint(
          painter: TuningWindowPainter(
            config: config,
            dial: dial,
            strength: strength,
            time: time,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class TuningWindowPainter extends CustomPainter {
  TuningWindowPainter({
    required this.config,
    required this.dial,
    required this.strength,
    required this.time,
  });

  final RadioPuzzleConfig config;
  final double dial;
  final double strength;
  final double time;

  static const _sidePadding = 18.0;

  double _xFor(double position, Size size) =>
      _sidePadding + position * (size.width - 2 * _sidePadding);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.1,
          colors: [
            Color.lerp(VestigiaColors.glass, VestigiaColors.glow, 0.16)!,
            VestigiaColors.glass,
          ],
        ).createShader(rect),
    );

    final scaleBottom = size.height * 0.34;
    _paintScale(canvas, size, scaleBottom);
    _paintWaves(canvas, size, scaleBottom);
    _paintNeedle(canvas, size);
  }

  void _paintScale(Canvas canvas, Size size, double bottom) {
    final tick = Paint()
      ..color = VestigiaColors.cream.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    final range = config.maxFrequencyKhz - config.minFrequencyKhz;
    final first = (config.minFrequencyKhz / 50).ceil() * 50;
    for (var f = first; f <= config.maxFrequencyKhz; f += 50) {
      final x = _xFor((f - config.minFrequencyKhz) / range, size);
      final major = f % 200 == 0;
      final length = major ? bottom * 0.42 : bottom * 0.2;
      canvas.drawLine(Offset(x, bottom - length), Offset(x, bottom), tick);
      if (major) {
        final label = TextPainter(
          text: TextSpan(
            text: '${f ~/ 100}',
            style: const TextStyle(
              color: VestigiaColors.cream,
              fontSize: 13,
              fontFamily: 'serif',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(
          canvas,
          Offset(x - label.width / 2, bottom - length - label.height - 2),
        );
      }
    }
    canvas.drawLine(
      Offset(_sidePadding, bottom),
      Offset(size.width - _sidePadding, bottom),
      tick,
    );
    // Topes de la escala.
    final stop = Paint()
      ..color = VestigiaColors.brass
      ..strokeWidth = 3;
    for (final x in [_sidePadding, size.width - _sidePadding]) {
      canvas.drawLine(Offset(x, bottom - 10), Offset(x, size.height), stop);
    }
  }

  void _paintWaves(Canvas canvas, Size size, double top) {
    final centerY = top + (size.height - top) / 2;
    final amplitude = (size.height - top) * 0.36;
    final s = strength.clamp(0.0, 1.0);
    final frame = (time * 24).floor();
    final path = Path();
    const step = 3.0;
    final width = size.width - 2 * _sidePadding;
    for (var x = 0.0; x <= width; x += step) {
      final i = (x / step).round();
      final clean = sin(x / width * 2 * pi * 6 - time * 5);
      final noise =
          0.65 * _hash(i, frame) +
          0.35 * sin(i * 0.9 + time * 23) * sin(i * 0.31 - time * 11);
      final y = centerY + amplitude * (s * clean + (1 - s) * noise * 1.1);
      final px = _sidePadding + x;
      if (x == 0) {
        path.moveTo(px, y);
      } else {
        path.lineTo(px, y);
      }
    }
    final color = Color.lerp(VestigiaColors.glow, VestigiaColors.signal, s)!;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color,
    );
  }

  void _paintNeedle(Canvas canvas, Size size) {
    final x = _xFor(dial, size);
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = VestigiaColors.needle.withValues(alpha: 0.35)
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = VestigiaColors.needle
        ..strokeWidth = 2.5,
    );
    canvas.drawPath(
      Path()
        ..moveTo(x - 7, 0)
        ..lineTo(x + 7, 0)
        ..lineTo(x, 10)
        ..close(),
      Paint()..color = VestigiaColors.needle,
    );
  }

  /// Ruido pseudoaleatorio estable por muestra y fotograma, en -1..1.
  static double _hash(int i, int frame) {
    var h = (i * 374761393 + frame * 668265263) & 0x7fffffff;
    h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff;
    h ^= h >> 16;
    return (h & 0xffff) / 0x7fff - 1;
  }

  @override
  bool shouldRepaint(TuningWindowPainter old) =>
      old.dial != dial ||
      old.strength != strength ||
      old.time != time ||
      old.config != config;
}
