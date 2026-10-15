import 'dart:ui' show Offset;

import 'lens_cleaning.dart';
import 'lookout_config.dart';
import 'view_orientation.dart';

enum LookoutPhase {
  /// Fase 1: limpiar el lente.
  cleaning,

  /// Fase 2: orientar la vista con las perillas.
  orienting,

  /// Evento de observación; las perillas ya están bloqueadas.
  observing,

  /// Evento de observación completado.
  solved,
}

/// Sucesos que la interfaz convierte en animación o vibración. Cada uno se
/// produce una sola vez por partida.
enum LookoutEvent { lensCleaned, aligned }

/// Fases del mirador: une la limpieza y la orientación y decide cuándo se
/// pasa de una a otra. No contiene interfaz.
class LookoutGame {
  LookoutGame(this.config)
    : lens = LensCleaning(
        resolution: config.gridResolution,
        brushRadius: config.brushRadius,
      ),
      view = ViewOrientation(config);

  final LookoutConfig config;
  final LensCleaning lens;
  final ViewOrientation view;

  LookoutPhase _phase = LookoutPhase.cleaning;
  LookoutPhase get phase => _phase;

  /// Empieza un trazo de limpieza. Fuera de la fase 1 no hace nada.
  ({int? stroke, LookoutEvent? event}) beginWipe(Offset point) {
    if (_phase != LookoutPhase.cleaning) return (stroke: null, event: null);
    final stroke = lens.beginStroke(point);
    return (stroke: stroke, event: _checkCleaned());
  }

  LookoutEvent? extendWipe(int stroke, Offset point) {
    if (_phase != LookoutPhase.cleaning) return null;
    lens.extendStroke(stroke, point);
    return _checkCleaned();
  }

  /// Las perillas solo responden en la fase 2.
  LookoutEvent? setX(double value) {
    if (_phase != LookoutPhase.orienting) return null;
    view.setX(value);
    return _checkAligned();
  }

  LookoutEvent? setY(double value) {
    if (_phase != LookoutPhase.orienting) return null;
    view.setY(value);
    return _checkAligned();
  }

  /// Restaura la suciedad, los ejes iniciales y la fase 1.
  void reset() {
    lens.reset();
    view.reset();
    _phase = LookoutPhase.cleaning;
  }

  void finishObservation() {
    if (_phase == LookoutPhase.observing) _phase = LookoutPhase.solved;
  }

  LookoutEvent? _checkCleaned() {
    if (lens.progress < config.cleanThreshold) return null;
    _phase = LookoutPhase.orienting;
    // Si la vista inicial ya estuviera alineada, se resuelve al entrar.
    return _checkAligned() ?? LookoutEvent.lensCleaned;
  }

  LookoutEvent? _checkAligned() {
    if (!view.isAligned) return null;
    _phase = LookoutPhase.observing;
    return LookoutEvent.aligned;
  }
}
