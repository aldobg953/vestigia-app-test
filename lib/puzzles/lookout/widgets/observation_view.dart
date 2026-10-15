import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/celestial_target.dart';
import '../../observatory/orientation_source.dart';
import '../../observatory/widgets/sky_view.dart' show projectSkyDirection;
import 'lens_view.dart';

class ObservationTimeline {
  const ObservationTimeline(this.progress);

  final double progress;

  double get skyFlash =>
      progress < 0.32 ? sin(pi * (progress / 0.32).clamp(0.0, 1.0)) : 0;

  // Both receivers share these three pulses, after the flash in the sky.
  double get receiverPulse {
    for (final (start, end) in [(0.36, 0.48), (0.54, 0.66), (0.73, 0.95)]) {
      if (progress >= start && progress <= end) {
        return sin(pi * (progress - start) / (end - start));
      }
    }
    return 0;
  }
}

class ObservationView extends StatelessWidget {
  const ObservationView({
    super.key,
    required this.panorama,
    required this.progress,
    required this.size,
  });

  final ImageProvider panorama;
  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(image: panorama, fit: BoxFit.fill),
          const ColoredBox(color: Color(0x660E1920)),
          CustomPaint(
            painter: _ObservationPainter(ObservationTimeline(progress)),
          ),
        ],
      ),
    ),
  );
}

class _ObservationPainter extends CustomPainter {
  _ObservationPainter(this.timeline);

  final ObservationTimeline timeline;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = projectSkyDirection(
      const PointingSample(
        PrototypeSky.azimuthDegrees,
        PrototypeSky.altitudeDegrees,
      ),
      const PointingSample(0, 35),
      size,
      fieldOfView: 110,
    )!;
    if (timeline.skyFlash > 0) {
      final glow = Paint()
        ..color = const Color(
          0xFFF0B7D2,
        ).withValues(alpha: timeline.skyFlash * 0.8)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.055);
      canvas.drawOval(
        Rect.fromCenter(
          center: sky,
          width: size.width * 0.5,
          height: size.height * 0.11,
        ),
        glow,
      );
      canvas.drawLine(
        sky - Offset(size.width * 0.13, 0),
        sky + Offset(size.width * 0.13, 0),
        Paint()
          ..color = Colors.white.withValues(alpha: timeline.skyFlash)
          ..strokeWidth = 2,
      );
    }

    final unit = size.width * 0.038;
    final base = Offset(size.width * 0.2, size.height * 0.51);
    final paper = Paint()..color = const Color(0xFFEDE2C8);
    final ink = Paint()..color = const Color(0xFF332C2C);
    final tower = Path()
      ..moveTo(base.dx - unit, base.dy)
      ..lineTo(base.dx - unit * 0.7, base.dy - unit * 4)
      ..lineTo(base.dx + unit * 0.7, base.dy - unit * 4)
      ..lineTo(base.dx + unit, base.dy)
      ..close();
    canvas.drawPath(tower, paper);
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          base.dx - unit * 0.8,
          base.dy - unit * (1.2 + i),
          unit * 1.6,
          unit * 0.3,
        ),
        ink,
      );
    }
    final lantern = base - Offset(0, unit * 4.3);
    canvas.drawRect(
      Rect.fromCenter(center: lantern, width: unit * 1.5, height: unit * 0.8),
      Paint()
        ..color = Color.lerp(
          const Color(0xFF594E43),
          const Color(0xFFFFEBA3),
          timeline.receiverPulse,
        )!,
    );
    canvas.drawPath(
      Path()
        ..moveTo(lantern.dx - unit, lantern.dy - unit * 0.4)
        ..lineTo(lantern.dx, lantern.dy - unit * 1.2)
        ..lineTo(lantern.dx + unit, lantern.dy - unit * 0.4)
        ..close(),
      ink,
    );
    if (timeline.receiverPulse > 0) {
      canvas.drawCircle(
        lantern,
        unit * 2.8,
        Paint()
          ..color = const Color(
            0xFFFFEBA3,
          ).withValues(alpha: timeline.receiverPulse * 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit),
      );
    }
    TargetPainter(
      const Offset(0.78, 0.42),
      scale: 2.4,
      pulse: timeline.receiverPulse,
    ).paint(canvas, size);
    for (final (label, x) in [('Faro', 0.2), ('Observatorio', 0.78)]) {
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Color(0xFFF1E4C6),
            fontSize: 13,
            fontFamily: 'serif',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(size.width * x - text.width / 2, size.height * 0.58),
      );
    }
  }

  @override
  bool shouldRepaint(_ObservationPainter old) =>
      old.timeline.progress != timeline.progress;
}
