import 'dart:math';
import 'dart:ui' show Offset;

/// Suciedad del lente y superficie limpiada, sin interfaz.
///
/// El lente es el círculo inscrito en el cuadrado 0..1. La superficie se
/// mide con una rejilla: cada celda cuenta una sola vez, así que frotar el
/// mismo lugar no suma. Los trazos se guardan como polilíneas para dibujar
/// exactamente lo que se limpió.
class LensCleaning {
  LensCleaning({required this.resolution, required this.brushRadius})
    : _clean = List.filled(resolution * resolution, false) {
    for (var j = 0; j < resolution; j++) {
      for (var i = 0; i < resolution; i++) {
        if (_insideLens(_cellCenter(i, j))) _lensCells++;
      }
    }
  }

  final int resolution;

  /// Radio del trazo, en diámetros de lente.
  final double brushRadius;

  final List<bool> _clean;
  final List<List<Offset>> _strokes = [];
  int _lensCells = 0;
  int _cleanCells = 0;
  int _revision = 0;

  /// Fracción del lente limpia (0..1).
  double get progress => _cleanCells / _lensCells;

  /// Trazos realizados, en coordenadas del lente (0..1).
  List<List<Offset>> get strokes => _strokes;

  /// Cambia cada vez que hay algo nuevo que dibujar.
  int get revision => _revision;

  /// Empieza un trazo en [point] y limpia bajo el dedo.
  int beginStroke(Offset point) {
    _strokes.add([point]);
    _revision++;
    _wipe(point, point);
    return _strokes.length - 1;
  }

  /// Continúa el trazo hasta [point]. Limpia todo el segmento desde la
  /// posición anterior, de modo que los trazos rápidos no dejan huecos.
  /// Devuelve las celdas nuevas que se limpiaron.
  int extendStroke(int stroke, Offset point) {
    final points = _strokes[stroke];
    final from = points.last;
    if (from == point) return 0;
    points.add(point);
    _revision++;
    return _wipe(from, point);
  }

  bool isCleanAt(Offset point) {
    final i = (point.dx * resolution).floor().clamp(0, resolution - 1);
    final j = (point.dy * resolution).floor().clamp(0, resolution - 1);
    return _clean[j * resolution + i];
  }

  void reset() {
    _clean.fillRange(0, _clean.length, false);
    _strokes.clear();
    _cleanCells = 0;
    _revision++;
  }

  int _wipe(Offset a, Offset b) {
    final r = brushRadius;
    int cell(double v) => (v * resolution).floor().clamp(0, resolution - 1);
    final i0 = cell(min(a.dx, b.dx) - r), i1 = cell(max(a.dx, b.dx) + r);
    final j0 = cell(min(a.dy, b.dy) - r), j1 = cell(max(a.dy, b.dy) + r);
    var added = 0;
    for (var j = j0; j <= j1; j++) {
      for (var i = i0; i <= i1; i++) {
        final index = j * resolution + i;
        if (_clean[index]) continue;
        final center = _cellCenter(i, j);
        if (!_insideLens(center)) continue;
        if (_distanceToSegment(center, a, b) > r) continue;
        _clean[index] = true;
        added++;
      }
    }
    _cleanCells += added;
    return added;
  }

  Offset _cellCenter(int i, int j) =>
      Offset((i + 0.5) / resolution, (j + 0.5) / resolution);

  static bool _insideLens(Offset p) =>
      (p - const Offset(0.5, 0.5)).distance <= 0.5;

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }
}
