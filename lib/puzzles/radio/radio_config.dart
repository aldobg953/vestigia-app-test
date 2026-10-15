import '../../core/celestial_target.dart';

/// Parámetros del puzzle de radio.
///
/// La escala del dial está normalizada de 0 a 1; la interfaz la traduce a
/// kilohercios solo para mostrarla.
class RadioPuzzleConfig {
  const RadioPuzzleConfig({
    this.digits = provisionalDigits,
    this.captureDuration = const Duration(seconds: 2),
    this.bandHalfWidth = 0.025,
    this.centerZone = 0.2,
    this.edgeCaptureRate = 0.25,
    this.audibleRange = 0.2,
    this.minSignalSeparation = 0.2,
    this.minDistanceFromStart = 0.15,
    this.edgeMargin = 0.06,
    this.initialDial = 0.5,
    this.knobTurnsForFullScale = 1.5,
    this.minFrequencyKhz = 530,
    this.maxFrequencyKhz = 1610,
  }) : assert(bandHalfWidth > 0 && audibleRange > 0),
       assert(centerZone >= 0 && centerZone < 1),
       assert(edgeCaptureRate > 0 && edgeCaptureRate <= 1),
       assert(initialDial >= 0 && initialDial <= 1);

  /// Dígitos provisionales de la coordenada. Su valor definitivo y su posible
  /// transmisión por voz siguen pendientes (ver docs/BRUJULA_PROYECTO.md).
  static const List<int> provisionalDigits = PrototypeSky.radioDigits;

  /// Un dígito por ronda: la partida tiene tantas rondas como dígitos.
  final List<int> digits;

  /// Tiempo continuo en el centro de la franja necesario para captar un
  /// dígito. Lejos del centro la captura avanza más lento.
  final Duration captureDuration;

  /// Mitad del ancho de la franja de sintonía, en unidades del dial.
  final double bandHalfWidth;

  /// Fracción central de la franja (respecto a [bandHalfWidth]) donde la
  /// captura avanza a velocidad completa; da margen a la imprecisión del dedo.
  final double centerZone;

  /// Velocidad de captura en el borde de la franja (1 = tiempo real). Entre
  /// [centerZone] y el borde baja de forma lineal.
  final double edgeCaptureRate;

  /// Distancia, desde el borde de la franja, a partir de la cual la señal
  /// deja de oírse por completo.
  final double audibleRange;

  /// Separación mínima entre las señales de una partida.
  final double minSignalSeparation;

  /// Distancia mínima entre la posición inicial del dial y cualquier señal,
  /// para que la partida empiece siempre con ruido.
  final double minDistanceFromStart;

  /// Margen para que ninguna señal quede pegada a los extremos de la escala.
  final double edgeMargin;

  /// Posición del dial al entrar al puzzle.
  final double initialDial;

  /// Vueltas completas de la perilla para recorrer toda la escala.
  final double knobTurnsForFullScale;

  final double minFrequencyKhz;
  final double maxFrequencyKhz;

  int get rounds => digits.length;

  double frequencyAt(double dial) =>
      minFrequencyKhz + dial * (maxFrequencyKhz - minFrequencyKhz);
}
