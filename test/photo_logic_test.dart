import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:radio_coordenadas/puzzles/photo/photo_assembly.dart';
import 'package:radio_coordenadas/puzzles/photo/photo_config.dart';
import 'package:radio_coordenadas/puzzles/photo/photo_layout.dart';
import 'package:radio_coordenadas/puzzles/photo/torn_photo.dart';

final photo = TornPhoto.threePieces();
const surface = Size(1.4, 2.4);
const tolerance = 0.08;

/// Origen que deja la esquina de la pieza en [position].
Offset originFor(int id, Offset position) => position - photo.piece(id).home;

/// Piezas separadas y fáciles de razonar.
PhotoAssembly fixedAssembly() => PhotoAssembly(
  photo: photo,
  surface: surface,
  tolerance: tolerance,
  origins: {
    0: originFor(0, const Offset(0.2, 0.05)),
    1: originFor(1, const Offset(0.05, 0.9)),
    2: originFor(2, const Offset(0.8, 1.55)),
  },
);

/// Arrastra la pieza [id] (sujetándola por un punto interior) hasta que su
/// origen quede en [target], y la suelta.
ReleaseResult drop(PhotoAssembly a, int id, Offset target) {
  final grab = a.originOf(id) + photo.piece(id).interiorPoint;
  final session = a.beginDrag(grab)!;
  a.dragTo(session, grab + (target - a.originOf(id)));
  return a.endDrag(session);
}

void expectNear(Offset actual, Offset expected) =>
    expect((actual - expected).distance, lessThan(1e-9));

void expectInside(PhotoAssembly a) {
  for (final id in [0, 1, 2]) {
    final rect = photo.piece(id).bounds.shift(a.originOf(id));
    expect(rect.left, greaterThanOrEqualTo(-1e-9));
    expect(rect.top, greaterThanOrEqualTo(-1e-9));
    expect(rect.right, lessThanOrEqualTo(a.surface.width + 1e-9));
    expect(rect.bottom, lessThanOrEqualTo(a.surface.height + 1e-9));
  }
}

void main() {
  group('fotografía rasgada', () {
    test('los tres pedazos cubren la foto completa sin huecos', () {
      final total = photo.pieces.map((p) => p.area).reduce((a, b) => a + b);
      expect(total, closeTo(photo.aspect, 1e-9));

      // Cada punto de la foto pertenece a exactamente un pedazo.
      for (var i = 0; i < 37; i++) {
        for (var j = 0; j < 41; j++) {
          final p = Offset((i + 0.37) / 37, (j + 0.53) / 41 * photo.aspect);
          final owners = photo.pieces.where((piece) => piece.contains(p));
          expect(owners, hasLength(1), reason: 'punto $p');
        }
      }
    });

    test('todos los pedazos son vecinos y tienen bordes rasgados', () {
      for (final a in [0, 1, 2]) {
        for (final b in [0, 1, 2]) {
          if (a != b) expect(photo.areNeighbors(a, b), isTrue);
        }
        expect(photo.piece(a).tornEdges, isNotEmpty);
        final interior = photo.piece(a).interiorPoint;
        expect(photo.piece(a).contains(interior), isTrue);
      }
    });
  });

  group('encaje', () {
    test(
      'encaja con la posición relativa correcta dentro de la tolerancia',
      () {
        final a = fixedAssembly();
        final still = a.originOf(0);
        final result = drop(a, 1, still + const Offset(0.04, -0.05));

        expect(result.joins, 1);
        expect(result.solved, isFalse);
        expect(a.areJoined(0, 1), isTrue);
        expect(a.groupCount, 2);
        // Queda exactamente alineada y la pieza quieta no se mueve.
        expect(a.originOf(1), still);
        expect(a.originOf(0), still);
      },
    );

    test('no encaja fuera de la tolerancia', () {
      final a = fixedAssembly();
      final result = drop(a, 1, a.originOf(0) + const Offset(0.07, 0.05));
      expect(result.joins, 0);
      expect(a.areJoined(0, 1), isFalse);
    });

    test('superponer o tocar sin alinear no resuelve', () {
      final a = fixedAssembly();
      // Encima de la otra pieza, en la misma esquina.
      drop(a, 1, originFor(1, a.positionOf(0)));
      expect(a.groupCount, 3);

      // Junto al borde correcto pero desplazada en horizontal.
      drop(a, 2, a.originOf(0) + const Offset(0.3, 0));
      expect(a.groupCount, 3);
    });

    test('dos piezas unidas se mueven como un solo objeto', () {
      final a = fixedAssembly();
      drop(a, 1, a.originOf(0));
      final before = a.originOf(0);

      const delta = Offset(0.1, 0.35);
      final result = drop(a, 1, before + delta);
      expect(result.joins, 0);
      expectNear(a.originOf(0), before + delta);
      expect(a.originOf(1), a.originOf(0));
      expect(a.areJoined(0, 1), isTrue);
    });

    test('un conjunto puede encajar con la tercera pieza', () {
      final a = fixedAssembly();
      drop(a, 1, a.originOf(0));
      final still = a.originOf(2);
      // Se arrastra el conjunto (sujetando la pieza 0) hacia la pieza 2.
      final result = drop(a, 0, still + const Offset(-0.03, 0.02));
      expect(result.solved, isTrue);
      expect(a.groupCount, 1);
      expect(a.originOf(2), still);
      expect(a.originOf(0), still);
      expect(a.originOf(1), still);
    });

    test('la resolución se informa una sola vez', () {
      final a = fixedAssembly();
      drop(a, 1, a.originOf(0));
      expect(drop(a, 2, a.originOf(0)).solved, isTrue);
      expect(a.isSolved, isTrue);

      // Ya no se puede arrastrar ni volver a resolver.
      final grab = a.originOf(0) + photo.piece(0).interiorPoint;
      expect(a.beginDrag(grab), isNull);
    });
  });

  group('arrastre', () {
    test('conserva el punto donde el dedo sujetó la pieza', () {
      final a = fixedAssembly();
      final grab = a.originOf(2) + photo.piece(2).interiorPoint;
      final start = a.positionOf(2);
      final session = a.beginDrag(grab)!;

      a.dragTo(session, grab + const Offset(-0.2, -0.3));
      expectNear(a.positionOf(2), start + const Offset(-0.2, -0.3));

      // Fuera de la superficie se detiene en el borde...
      a.dragTo(session, grab + const Offset(5, 5));
      expectInside(a);
      // ...y al volver, la pieza regresa bajo el mismo punto del dedo.
      a.dragTo(session, grab + const Offset(-0.1, 0));
      expectNear(a.positionOf(2), start + const Offset(-0.1, 0));
    });

    test('la pieza tocada pasa arriba de las demás', () {
      final a = PhotoAssembly(
        photo: photo,
        surface: surface,
        tolerance: tolerance,
        origins: {
          0: originFor(0, const Offset(0.1, 0.1)),
          1: originFor(1, const Offset(0.15, 0.2)),
          2: originFor(2, const Offset(0.7, 1.5)),
        },
      );
      // Un punto cubierto por las dos primeras piezas.
      final shared = const Offset(0.3, 0.4);
      expect(photo.piece(0).contains(shared - a.originOf(0)), isTrue);
      expect(photo.piece(1).contains(shared - a.originOf(1)), isTrue);
      expect(a.pieceAt(shared), 1);

      // Tocar una zona visible de la pieza 0 la sube.
      final session = a.beginDrag(const Offset(1.0, 0.15))!;
      a.endDrag(session);
      expect(a.pieceAt(shared), 0);
    });

    test('tocar la superficie vacía no arrastra nada', () {
      final a = fixedAssembly();
      expect(a.beginDrag(const Offset(1.35, 0.95)), isNull);
    });
  });

  group('reparto y reinicio', () {
    test('reiniciar separa las piezas y permite resolver de nuevo', () {
      final a = PhotoAssembly(
        photo: photo,
        surface: surface,
        tolerance: tolerance,
        random: Random(4),
      );
      drop(a, 1, a.originOf(0));
      a.reset();
      expect(a.groupCount, 3);
      expect(a.isSolved, isFalse);
      expectInside(a);
    });

    test('las piezas empiezan dentro, separadas y lejos de encajar', () {
      for (final pixels in const [
        Size(336, 560),
        Size(336, 630),
        Size(300, 480),
        Size(392, 700),
        Size(700, 950),
      ]) {
        final layout = PhotoLayout.fit(pixels, photo);
        final tol = layout.toleranceFor(const PhotoPuzzleConfig());
        for (var seed = 0; seed < 40; seed++) {
          final a = PhotoAssembly(
            photo: photo,
            surface: layout.surface,
            tolerance: tol,
            random: Random(seed),
          );
          expectInside(a);
          final rects = [
            for (final id in [0, 1, 2])
              photo.piece(id).bounds.shift(a.originOf(id)),
          ];
          for (var i = 0; i < 3; i++) {
            for (var j = i + 1; j < 3; j++) {
              expect(rects[i].overlaps(rects[j]), isFalse, reason: '$pixels');
              expect(
                (a.originOf(i) - a.originOf(j)).distance,
                greaterThan(tol * 3),
              );
            }
          }
        }
      }
    });

    test('la escala se adapta a la pantalla y la foto armada cabe', () {
      for (final pixels in const [
        Size(300, 480),
        Size(336, 630),
        Size(700, 950),
      ]) {
        final layout = PhotoLayout.fit(pixels, photo);
        expect(layout.scale, lessThanOrEqualTo(pixels.width));
        expect(layout.scale * photo.aspect, lessThanOrEqualTo(pixels.height));
        // Tolerancia cómoda: al menos 20 px en pantalla.
        final tolPx =
            layout.toleranceFor(const PhotoPuzzleConfig()) * layout.scale;
        expect(tolPx, greaterThanOrEqualTo(20));
      }
      final small = PhotoLayout.fit(const Size(300, 480), photo);
      final big = PhotoLayout.fit(const Size(700, 950), photo);
      expect(big.scale, greaterThan(small.scale));
    });

    test('al cambiar la superficie los conjuntos siguen dentro', () {
      final a = fixedAssembly();
      a.resize(const Size(1.2, 1.9));
      expectInside(a);
    });
  });
}
