import '../../core/celestial_target.dart';

/// Parámetros del puzzle de la fotografía.
///
/// Las medidas de la lógica están en “anchos de foto”: la fotografía
/// completa mide 1 de ancho y [aspect] de alto. La pantalla decide cuántos
/// píxeles mide ese ancho según el espacio disponible.
class PhotoPuzzleConfig {
  const PhotoPuzzleConfig({
    this.coordinatePart = provisionalCoordinatePart,
    this.photoAsset = 'assets/photos/foto_provisional.jpg',
    this.aspect = 1.25,
    this.snapTolerance = 0.08,
    this.minSnapTolerancePx = 20,
  });

  /// Segunda parte de las coordenadas, escrita en el reverso. Es provisional
  /// y es independiente de los dígitos de la radio (ver
  /// `RadioPuzzleConfig.provisionalDigits`).
  static const String provisionalCoordinatePart = PrototypeSky.photoCode;

  final String coordinatePart;

  /// Imagen provisional; se puede reemplazar por otra con la misma
  /// proporción ([aspect] = alto / ancho).
  final String photoAsset;
  final double aspect;

  /// Distancia máxima, en anchos de foto, entre la posición de una pieza y
  /// la que le corresponde respecto a otra para que encajen.
  final double snapTolerance;

  /// Tolerancia mínima en píxeles, para pantallas pequeñas.
  final double minSnapTolerancePx;
}
