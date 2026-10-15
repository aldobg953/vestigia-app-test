import 'dart:math';
import 'dart:ui' show Offset, Rect;

/// Un pedazo de la fotografía. Su contorno está en coordenadas de la foto
/// completa (ancho 1), es decir, en la posición que ocupa al estar armada.
class PhotoPiece {
  PhotoPiece({
    required this.id,
    required List<Offset> outline,
    required List<List<Offset>> tornEdges,
  }) : outline = List.unmodifiable(outline),
       tornEdges = List.unmodifiable(tornEdges.map(List<Offset>.unmodifiable)),
       bounds = _boundsOf(outline);

  final int id;
  final List<Offset> outline;

  /// Tramos rasgados del contorno (los que no son borde de la foto).
  final List<List<Offset>> tornEdges;

  /// Rectángulo que contiene la pieza dentro de la foto armada.
  final Rect bounds;

  /// Esquina superior izquierda de [bounds] dentro de la foto armada.
  Offset get home => bounds.topLeft;

  /// Si [point] (en coordenadas de la foto armada) cae dentro de la pieza.
  bool contains(Offset point) {
    var inside = false;
    for (var i = 0, j = outline.length - 1; i < outline.length; j = i++) {
      final a = outline[i];
      final b = outline[j];
      if ((a.dy > point.dy) != (b.dy > point.dy) &&
          point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Un punto garantizado dentro de la pieza (útil para tocarla).
  Offset get interiorPoint {
    final center = bounds.center;
    if (contains(center)) return center;
    for (var gy = 1; gy < 10; gy++) {
      for (var gx = 1; gx < 10; gx++) {
        final p = Offset(
          bounds.left + bounds.width * gx / 10,
          bounds.top + bounds.height * gy / 10,
        );
        if (contains(p)) return p;
      }
    }
    return outline.first;
  }

  /// Área del contorno (fórmula del polígono).
  double get area {
    var sum = 0.0;
    for (var i = 0, j = outline.length - 1; i < outline.length; j = i++) {
      sum += outline[j].dx * outline[i].dy - outline[i].dx * outline[j].dy;
    }
    return sum.abs() / 2;
  }

  static Rect _boundsOf(List<Offset> points) {
    var left = double.infinity, top = double.infinity;
    var right = -double.infinity, bottom = -double.infinity;
    for (final p in points) {
      left = min(left, p.dx);
      top = min(top, p.dy);
      right = max(right, p.dx);
      bottom = max(bottom, p.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

/// Fotografía rasgada en tres pedazos: uno superior (0) y dos inferiores,
/// izquierdo (1) y derecho (2). Los tres comparten bordes entre sí.
class TornPhoto {
  TornPhoto._(this.aspect, this.pieces, this._neighbors);

  /// Alto de la foto respecto a su ancho (1).
  final double aspect;
  final List<PhotoPiece> pieces;
  final Set<(int, int)> _neighbors;

  PhotoPiece piece(int id) => pieces[id];

  /// Si dos piezas comparten un borde rasgado y, por tanto, pueden encajar.
  bool areNeighbors(int a, int b) =>
      _neighbors.contains((a, b)) || _neighbors.contains((b, a));

  /// Los cortes son siempre los mismos ([seed] fijo) para que la imagen y
  /// las piezas coincidan; solo cambia dónde aparecen en la mesa.
  factory TornPhoto.threePieces({double aspect = 1.25, int seed = 11}) {
    final random = Random(seed);
    double jag(double size) =>
        (random.nextDouble() - 0.5) * 2 * size +
        (random.nextDouble() < 0.18
            ? (random.nextDouble() - 0.5) * size * 2.4
            : 0);

    // Corte horizontal de izquierda a derecha, ligeramente inclinado.
    const steps = 28;
    final tearTop = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final edge = i == 0 || i == steps;
      final x = edge ? t : t + jag(0.006);
      final baseY = aspect * (0.42 + 0.06 * t);
      tearTop.add(Offset(x, baseY + jag(0.014)));
    }
    final junction = (steps * 0.46).round();

    // Corte vertical desde el cruce hasta el borde inferior.
    const downSteps = 24;
    final start = tearTop[junction];
    final tearDown = <Offset>[start];
    for (var k = 1; k <= downSteps; k++) {
      final t = k / downSteps;
      final last = k == downSteps;
      final y = last ? aspect : start.dy + (aspect - start.dy) * t + jag(0.005);
      final baseX = start.dx + (0.55 - start.dx) * t;
      tearDown.add(Offset(baseX + jag(0.015), y));
    }

    final top = PhotoPiece(
      id: 0,
      outline: [const Offset(0, 0), const Offset(1, 0), ...tearTop.reversed],
      tornEdges: [tearTop],
    );
    final leftTear = tearTop.sublist(0, junction + 1);
    final rightTear = tearTop.sublist(junction);
    final bottomLeft = PhotoPiece(
      id: 1,
      outline: [...leftTear, ...tearDown.skip(1), Offset(0, aspect)],
      tornEdges: [leftTear, tearDown],
    );
    final bottomRight = PhotoPiece(
      id: 2,
      outline: [
        ...rightTear,
        Offset(1, aspect),
        ...tearDown.reversed.take(tearDown.length - 1),
      ],
      tornEdges: [rightTear, tearDown],
    );

    return TornPhoto._(
      aspect,
      [top, bottomLeft, bottomRight],
      {(0, 1), (0, 2), (1, 2)},
    );
  }
}
