import 'dart:math';

import 'radio_config.dart';

/// Genera las posiciones de las señales de una partida a partir de la
/// posición del dial en ese momento.
typedef SignalPlanner = List<double> Function(double startDial);

/// Resultado de captar un dígito.
class DigitCapture {
  const DigitCapture({
    required this.index,
    required this.digit,
    required this.completesPuzzle,
  });

  final int index;
  final int digit;
  final bool completesPuzzle;
}

/// Lógica de sintonía, independiente de la interfaz y del audio.
///
/// Las posiciones se generan una vez por partida y no cambian hasta
/// [restart]. El tiempo avanza solo mediante [advance], de modo que las
/// pruebas controlan el reloj.
class RadioTuningGame {
  RadioTuningGame({
    required this.config,
    Random? random,
    SignalPlanner? planner,
  }) : _dial = config.initialDial {
    _planner =
        planner ??
        (start) => generateSignalPositions(config, random ?? Random(), start);
    _startNewGame();
  }

  final RadioPuzzleConfig config;
  late final SignalPlanner _planner;

  double _dial;
  late List<double> _signals;
  final List<int> _captured = [];
  Duration _hold = Duration.zero;

  double get dial => _dial;
  List<double> get signalPositions => List.unmodifiable(_signals);
  List<int> get capturedDigits => List.unmodifiable(_captured);
  int get round => _captured.length;
  bool get isComplete => _captured.length >= config.rounds;
  Duration get holdTime => _hold;

  double get holdProgress => isComplete
      ? 1
      : (_hold.inMicroseconds / config.captureDuration.inMicroseconds).clamp(
          0.0,
          1.0,
        );

  /// Señal que se busca ahora; `null` al completar la partida.
  double? get activeSignal => isComplete ? null : _signals[round];

  /// Señal que representan la franja, las ondas y el sonido. Al terminar se
  /// mantiene la última captada para que la radio quede sintonizada.
  double get displayedSignal => activeSignal ?? _signals.last;

  /// Distancia del dial a la señal activa; `null` al completar.
  double? get distanceToSignal {
    final signal = activeSignal;
    return signal == null ? null : (_dial - signal).abs();
  }

  bool get isInBand {
    final distance = distanceToSignal;
    return distance != null && distance <= config.bandHalfWidth;
  }

  /// Intensidad de la señal (0 = solo ruido, 1 = señal limpia). Es la única
  /// medida que usan las ondas y el audio.
  double get signalStrength => strengthAt(_dial, displayedSignal, config);

  /// Velocidad a la que avanza la captura ahora (0 fuera de la franja).
  double get captureRate =>
      isComplete ? 0 : captureRateAt(_dial, activeSignal!, config);

  /// Pico en el centro exacto y caída continua hacia los lados, sin mesetas:
  /// cada movimiento de la perilla cambia algo y no hay saltos en el borde
  /// de la franja.
  static double strengthAt(
    double dial,
    double signal,
    RadioPuzzleConfig config,
  ) {
    final reach = config.bandHalfWidth + config.audibleRange;
    final t = (1 - (dial - signal).abs() / reach).clamp(0.0, 1.0);
    return t * t;
  }

  /// 1 en la zona central de la franja, baja de forma lineal hasta
  /// [RadioPuzzleConfig.edgeCaptureRate] en el borde y es 0 fuera.
  static double captureRateAt(
    double dial,
    double signal,
    RadioPuzzleConfig config,
  ) {
    final offset = (dial - signal).abs() / config.bandHalfWidth;
    if (offset > 1) return 0;
    if (offset <= config.centerZone) return 1;
    final t = (offset - config.centerZone) / (1 - config.centerZone);
    return 1 - t * (1 - config.edgeCaptureRate);
  }

  /// Mueve el dial (limitado a 0..1). Salir de la franja reinicia la espera.
  void setDial(double value) {
    _dial = value.clamp(0.0, 1.0);
    if (!isInBand) _hold = Duration.zero;
  }

  /// Avanza el reloj. El tiempo dentro de la franja cuenta según
  /// [captureRate]; devuelve la captura al completar [captureDuration].
  DigitCapture? advance(Duration elapsed) {
    if (isComplete || elapsed <= Duration.zero) return null;
    if (!isInBand) {
      _hold = Duration.zero;
      return null;
    }
    _hold += elapsed * captureRate;
    if (_hold < config.captureDuration) return null;

    final index = _captured.length;
    final digit = config.digits[index];
    _captured.add(digit);
    _hold = Duration.zero;
    return DigitCapture(
      index: index,
      digit: digit,
      completesPuzzle: isComplete,
    );
  }

  /// Descarta una espera incompleta (por ejemplo, al pasar la app al fondo).
  void cancelHold() => _hold = Duration.zero;

  /// Nueva partida: borra los dígitos y genera otras posiciones.
  void restart() => _startNewGame();

  void _startNewGame() {
    _captured.clear();
    _hold = Duration.zero;
    _signals = List.of(_planner(_dial));
    assert(_signals.length == config.rounds);
  }
}

/// Genera una posición por ronda, separadas entre sí, lejos de los extremos
/// y lejos de la posición inicial del dial.
List<double> generateSignalPositions(
  RadioPuzzleConfig config,
  Random random,
  double startDial,
) {
  final low = config.edgeMargin;
  final span = 1 - 2 * config.edgeMargin;

  for (var attempt = 0; attempt < 500; attempt++) {
    final positions = <double>[];
    var tries = 0;
    while (positions.length < config.rounds && tries < 200) {
      tries++;
      final candidate = low + random.nextDouble() * span;
      if ((candidate - startDial).abs() < config.minDistanceFromStart) continue;
      if (positions.any(
        (p) => (p - candidate).abs() < config.minSignalSeparation,
      )) {
        continue;
      }
      positions.add(candidate);
    }
    if (positions.length == config.rounds) return positions;
  }
  throw StateError(
    'No caben ${config.rounds} señales con la separación configurada.',
  );
}
