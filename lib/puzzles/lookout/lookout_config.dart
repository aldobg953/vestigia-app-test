import 'dart:ui' show Offset;

/// Rango de un eje de orientación.
class AxisRange {
  const AxisRange(this.min, this.max) : assert(max > min);

  final double min;
  final double max;

  double get span => max - min;
  double clamp(double value) => value.clamp(min, max).toDouble();

  /// 0 en [min], 1 en [max].
  double normalize(double value) => (clamp(value) - min) / span;
  double fromNormalized(double t) => min + t.clamp(0.0, 1.0) * span;
}

/// Parámetros del mirador del faro. Todos los valores son provisionales
/// (ver docs/BRUJULA_PROYECTO.md, sección 11.2 y preguntas pendientes).
class LookoutConfig {
  const LookoutConfig({
    this.cleanThreshold = 0.85,
    this.brushRadius = 0.075,
    this.gridResolution = 72,
    this.xRange = const AxisRange(-100, 100),
    this.yRange = const AxisRange(-100, 100),
    this.initialX = 0,
    this.initialY = 0,
    this.targetPosition = const Offset(0.82, 0.40),
    this.alignTolerance = 14,
    this.observationDuration = const Duration(seconds: 4),
    this.panoramaAsset = 'assets/photos/mirador_provisional.jpg',
    this.panoramaAspect = 0.6,
    this.viewWidthFraction = 0.28,
    this.knobTurnsForFullRange = 1.5,
    this.showDebugValues = true,
  }) : assert(cleanThreshold > 0 && cleanThreshold <= 1),
       assert(brushRadius > 0),
       assert(alignTolerance > 0);

  /// Fracción del lente que debe quedar limpia para pasar a la fase 2.
  final double cleanThreshold;

  /// Radio del trazo de limpieza, en diámetros de lente.
  final double brushRadius;

  /// Celdas por lado de la rejilla con que se mide la superficie limpia.
  final int gridResolution;

  final AxisRange xRange;
  final AxisRange yRange;
  final double initialX;
  final double initialY;

  /// Posición del objetivo dentro del panorama (0..1 en ancho y alto).
  final Offset targetPosition;

  /// Diferencia máxima, en unidades de eje, para considerar alineado cada
  /// eje.
  final double alignTolerance;

  final Duration observationDuration;

  /// Imagen provisional observada a través del lente.
  final String panoramaAsset;

  /// Alto del panorama respecto a su ancho.
  final double panoramaAspect;

  /// Ancho de la vista (cuadrada) respecto al ancho del panorama.
  final double viewWidthFraction;

  /// Vueltas de cada perilla para recorrer su eje completo.
  final double knobTurnsForFullRange;

  /// Muestra “X: … Y: …” (datos de depuración del prototipo).
  final bool showDebugValues;
}
