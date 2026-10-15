import 'dart:ui' show Offset;

import 'lookout_config.dart';

/// Orientación del mirador, sin interfaz. X mueve la vista en horizontal y
/// Y en vertical; cada eje es independiente y queda dentro de su rango.
class ViewOrientation {
  ViewOrientation(this.config)
    : _x = config.xRange.clamp(config.initialX),
      _y = config.yRange.clamp(config.initialY) {
    assert(
      _targetReachable,
      'El objetivo debe quedar dentro del recorrido de la vista.',
    );
  }

  final LookoutConfig config;
  double _x;
  double _y;

  double get x => _x;
  double get y => _y;

  void setX(double value) => _x = config.xRange.clamp(value);
  void setY(double value) => _y = config.yRange.clamp(value);

  void reset() {
    _x = config.xRange.clamp(config.initialX);
    _y = config.yRange.clamp(config.initialY);
  }

  /// Mitad de la vista, en fracciones del ancho y del alto del panorama.
  double get _halfWidth => config.viewWidthFraction / 2;
  double get _halfHeight =>
      config.viewWidthFraction / config.panoramaAspect / 2;

  /// Centro de la vista dentro del panorama (0..1). Y positivo mira hacia
  /// arriba.
  Offset viewCenterFor(double x, double y) => Offset(
    _halfWidth + config.xRange.normalize(x) * (1 - 2 * _halfWidth),
    (1 - _halfHeight) - config.yRange.normalize(y) * (1 - 2 * _halfHeight),
  );

  Offset get viewCenter => viewCenterFor(_x, _y);

  /// Valores de los ejes que centran el objetivo en la retícula.
  double get targetX => config.xRange.fromNormalized(
    (config.targetPosition.dx - _halfWidth) / (1 - 2 * _halfWidth),
  );
  double get targetY => config.yRange.fromNormalized(
    ((1 - _halfHeight) - config.targetPosition.dy) / (1 - 2 * _halfHeight),
  );

  bool get isXAligned => (_x - targetX).abs() <= config.alignTolerance;
  bool get isYAligned => (_y - targetY).abs() <= config.alignTolerance;
  bool get isAligned => isXAligned && isYAligned;

  bool get _targetReachable {
    final t = config.targetPosition;
    return t.dx >= _halfWidth &&
        t.dx <= 1 - _halfWidth &&
        t.dy >= _halfHeight &&
        t.dy <= 1 - _halfHeight;
  }
}
