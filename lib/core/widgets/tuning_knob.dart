import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/vestigia_theme.dart';

/// Perilla giratoria. El valor cambia según el ángulo que recorre el dedo
/// alrededor del centro (no salta a la posición tocada) y se detiene en los
/// topes 0 y 1.
class TuningKnob extends StatefulWidget {
  const TuningKnob({
    super.key,
    required this.value,
    required this.sweepRadians,
    required this.onChanged,
    required this.describeValue,
    this.enabled = true,
  });

  final double value;

  /// Giro total de la perilla para recorrer la escala completa.
  final double sweepRadians;
  final ValueChanged<double> onChanged;
  final bool enabled;

  /// Texto para lectores de pantalla (por ejemplo, la frecuencia).
  final String Function(double value) describeValue;

  @override
  State<TuningKnob> createState() => _TuningKnobState();
}

class _TuningKnobState extends State<TuningKnob> {
  double? _lastAngle;

  /// Valor acumulado durante el arrastre; puede haber varios eventos antes
  /// de que el padre reconstruya la perilla con el valor nuevo.
  double? _dragValue;

  void _onPanStart(DragStartDetails details) {
    _lastAngle = _angleAt(details.localPosition);
    _dragValue = widget.value;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final angle = _angleAt(details.localPosition);
    final last = _lastAngle;
    _lastAngle = angle;
    if (angle == null || last == null) return;

    var delta = angle - last;
    if (delta > pi) delta -= 2 * pi;
    if (delta < -pi) delta += 2 * pi;
    final current = _dragValue ?? widget.value;
    final next = (current + delta / widget.sweepRadians).clamp(0.0, 1.0);
    _dragValue = next;
    if (next != current) widget.onChanged(next);
  }

  void _onPanEnd([Object? _]) {
    _lastAngle = null;
    _dragValue = null;
  }

  /// Ángulo del dedo respecto al centro; `null` muy cerca del centro, donde
  /// el ángulo es inestable.
  double? _angleAt(Offset local) {
    final size = context.size;
    if (size == null) return null;
    final v = local - size.center(Offset.zero);
    if (v.distance < size.shortestSide * 0.1) return null;
    return atan2(v.dy, v.dx);
  }

  static const _semanticStep = 0.01;

  double _nudged(double amount) => (widget.value + amount).clamp(0.0, 1.0);

  void _nudge(double amount) => widget.onChanged(_nudged(amount));

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Perilla de sintonía',
      slider: true,
      enabled: widget.enabled,
      value: widget.describeValue(widget.value),
      increasedValue: widget.describeValue(_nudged(_semanticStep)),
      decreasedValue: widget.describeValue(_nudged(-_semanticStep)),
      onIncrease: widget.enabled ? () => _nudge(_semanticStep) : null,
      onDecrease: widget.enabled ? () => _nudge(-_semanticStep) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: widget.enabled ? _onPanStart : null,
        onPanUpdate: widget.enabled ? _onPanUpdate : null,
        onPanEnd: widget.enabled ? _onPanEnd : null,
        onPanCancel: widget.enabled ? _onPanEnd : null,
        child: CustomPaint(
          painter: _KnobPainter(
            rotation: (widget.value - 0.5) * widget.sweepRadians,
            enabled: widget.enabled,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  _KnobPainter({required this.rotation, required this.enabled});

  final double rotation;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 * 0.92;

    canvas.drawCircle(
      center.translate(0, 6),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Anillo estriado.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF2B1A0F),
            Color(0xFF4D3220),
            Color(0xFF2B1A0F),
            Color(0xFF4D3220),
            Color(0xFF2B1A0F),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    final ridge = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = 2;
    const ridges = 48;
    for (var i = 0; i < ridges; i++) {
      final a = i * 2 * pi / ridges;
      final dir = Offset(cos(a), sin(a));
      canvas.drawLine(dir * radius * 0.8, dir * radius * 0.99, ridge);
    }

    // Tapa de latón.
    final capRadius = radius * 0.74;
    canvas.drawCircle(
      Offset.zero,
      capRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: enabled
              ? const [
                  Color(0xFFF3D38C),
                  VestigiaColors.brass,
                  VestigiaColors.brassDark,
                ]
              : const [Color(0xFF9C8B6A), Color(0xFF7A6A4C), Color(0xFF51452F)],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: capRadius)),
    );
    canvas.drawCircle(
      Offset.zero,
      capRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black.withValues(alpha: 0.35),
    );

    // Marca de posición y hueco para el dedo, apuntando hacia arriba en 0.
    final pointer = Paint()
      ..color = VestigiaColors.needle
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, -capRadius * 0.92),
      Offset(0, -capRadius * 0.55),
      pointer,
    );
    canvas.drawCircle(
      Offset(0, -capRadius * 0.3),
      capRadius * 0.14,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KnobPainter old) =>
      old.rotation != rotation || old.enabled != enabled;
}
