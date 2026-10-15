import 'dart:math';
import 'dart:ui' show Size;

import 'photo_config.dart';
import 'torn_photo.dart';

/// Escala de la fotografía según el tamaño de la superficie de trabajo.
///
/// Elige el ancho de foto más grande que permite repartir las piezas en dos
/// filas sin encimarse y armar la foto completa dentro de la superficie.
class PhotoLayout {
  const PhotoLayout({required this.scale, required this.surface});

  /// Píxeles lógicos que mide un ancho de foto.
  final double scale;

  /// Superficie medida en anchos de foto.
  final Size surface;

  static const gapPx = 14.0;

  factory PhotoLayout.fit(Size pixels, TornPhoto photo) {
    final pieces = [...photo.pieces]
      ..sort((a, b) => b.bounds.width.compareTo(a.bounds.width));
    final wide = pieces[0].bounds;
    final pairWidth = pieces[1].bounds.width + pieces[2].bounds.width;
    final pairHeight = max(pieces[1].bounds.height, pieces[2].bounds.height);

    final candidates = [
      // Dos filas con huecos entre ellas.
      (pixels.height - 3 * gapPx) / (wide.height + pairHeight),
      // La pieza ancha con margen para variar su posición.
      (pixels.width - 2 * gapPx) / wide.width * 0.86,
      // Las dos piezas de la otra fila, una al lado de la otra.
      (pixels.width - 3 * gapPx) / pairWidth,
      // La foto completa debe caber.
      pixels.width * 0.92,
      pixels.height * 0.92 / photo.aspect,
    ];
    final scale = max(1.0, candidates.reduce(min));
    return PhotoLayout(
      scale: scale,
      surface: Size(pixels.width / scale, pixels.height / scale),
    );
  }

  /// Tolerancia de encaje en anchos de foto, nunca menor que
  /// [PhotoPuzzleConfig.minSnapTolerancePx] en pantalla.
  double toleranceFor(PhotoPuzzleConfig config) =>
      max(config.snapTolerance, config.minSnapTolerancePx / scale);
}
