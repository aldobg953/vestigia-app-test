/// Tipo de vibración que corresponde a un movimiento de la perilla.
enum DialFeedback { none, detent, limit }

/// Decide cuándo vibrar al girar la perilla: un toque ligero por cada
/// muesca recorrida (limitado en frecuencia) y un golpe al llegar a un tope.
class DialDetentTracker {
  DialDetentTracker({
    this.detentStep = 0.01,
    this.minInterval = const Duration(milliseconds: 45),
  });

  final double detentStep;
  final Duration minInterval;

  int? _lastDetent;
  Duration? _lastTickAt;
  bool _atLimit = false;

  /// [now] es un reloj monotónico cualquiera; solo se usan diferencias.
  DialFeedback onMoved(double dial, Duration now) {
    final atLimit = dial <= 0 || dial >= 1;
    final reachedLimit = atLimit && !_atLimit;
    _atLimit = atLimit;

    final detent = (dial / detentStep).floor();
    final crossed = _lastDetent != null && detent != _lastDetent;
    _lastDetent = detent;

    if (reachedLimit) {
      _lastTickAt = now;
      return DialFeedback.limit;
    }
    if (!crossed) return DialFeedback.none;
    final last = _lastTickAt;
    if (last != null && now - last < minInterval) return DialFeedback.none;
    _lastTickAt = now;
    return DialFeedback.detent;
  }

  void reset(double dial) {
    _lastDetent = (dial / detentStep).floor();
    _atLimit = dial <= 0 || dial >= 1;
    _lastTickAt = null;
  }
}
