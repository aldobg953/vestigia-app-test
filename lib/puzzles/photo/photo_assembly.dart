import 'dart:math';
import 'dart:ui' show Offset, Rect, Size;

import 'torn_photo.dart';

/// Arrastre en curso: qué conjunto se mueve y en qué punto lo sujetó el dedo
/// (relativo al origen del conjunto), para que no salte bajo el dedo.
class DragSession {
  const DragSession._(this.group, this.grip);

  final int group;
  final Offset grip;
}

/// Resultado de soltar un conjunto.
class ReleaseResult {
  const ReleaseResult({required this.joins, required this.solved});

  /// Uniones nuevas producidas al soltar.
  final int joins;

  /// `true` solo la primera vez que la fotografía queda completa en la
  /// partida.
  final bool solved;
}

/// Reglas de unión de la fotografía, sin interfaz.
///
/// Todas las medidas están en anchos de foto. Cada pieza guarda su
/// *origen*: dónde quedaría la esquina superior izquierda de la foto armada
/// si la pieza estuviera en su sitio. Dos piezas están bien alineadas
/// exactamente cuando tienen el mismo origen; por eso tocarse o
/// superponerse no basta para encajar.
class PhotoAssembly {
  PhotoAssembly({
    required this.photo,
    required this._surface,
    required this.tolerance,
    Random? random,
    Map<int, Offset>? origins,
  }) : _random = random ?? Random() {
    if (origins != null) {
      _resetGroups();
      _origins.addAll(origins);
      _zOrder.addAll(photo.pieces.map((p) => p.id));
      _clampAll();
    } else {
      reset();
    }
  }

  final TornPhoto photo;

  /// Distancia máxima entre orígenes para encajar.
  final double tolerance;

  final Random _random;
  Size _surface;
  final Map<int, Offset> _origins = {};
  final Map<int, int> _groupOf = {};
  final List<int> _zOrder = [];
  bool _solved = false;

  Size get surface => _surface;
  bool get isSolved => _solved;

  /// Piezas de abajo hacia arriba.
  List<int> get zOrder => List.unmodifiable(_zOrder);

  Offset originOf(int piece) => _origins[piece]!;

  /// Esquina superior izquierda de la pieza sobre la superficie.
  Offset positionOf(int piece) => originOf(piece) + photo.piece(piece).home;

  int groupOf(int piece) => _groupOf[piece]!;

  Set<int> membersOf(int group) => {
    for (final entry in _groupOf.entries)
      if (entry.value == group) entry.key,
  };

  int get groupCount => _groupOf.values.toSet().length;

  bool areJoined(int a, int b) => groupOf(a) == groupOf(b);

  /// Pieza visible bajo [point], respetando el orden de apilado.
  int? pieceAt(Offset point) {
    for (final id in _zOrder.reversed) {
      if (photo.piece(id).contains(point - originOf(id))) return id;
    }
    return null;
  }

  /// Rectángulo que ocupa un conjunto sobre la superficie.
  Rect boundsOfGroup(int group) {
    Rect? bounds;
    for (final id in membersOf(group)) {
      final rect = photo.piece(id).bounds.shift(originOf(id));
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }
    return bounds!;
  }

  DragSession? beginDrag(Offset point) {
    if (_solved) return null;
    final piece = pieceAt(point);
    if (piece == null) return null;
    final group = groupOf(piece);
    _raise(group);
    return DragSession._(group, point - originOf(piece));
  }

  /// Mueve el conjunto para que el punto sujetado siga al dedo, sin salir
  /// de la superficie.
  void dragTo(DragSession session, Offset point) {
    if (_solved) return;
    final anchor = membersOf(session.group).first;
    final desired = point - session.grip;
    _moveGroup(session.group, desired - originOf(anchor));
  }

  /// Suelta el conjunto y encaja las piezas vecinas alineadas dentro de la
  /// tolerancia. La pieza que estaba quieta no se mueve.
  ReleaseResult endDrag(DragSession session) {
    if (_solved) return const ReleaseResult(joins: 0, solved: false);
    var group = session.group;
    var joins = 0;
    while (true) {
      final members = membersOf(group);
      int? target;
      Offset? correction;
      for (final p in members) {
        for (final q in photo.pieces.map((piece) => piece.id)) {
          if (members.contains(q) || !photo.areNeighbors(p, q)) continue;
          final error = originOf(q) - originOf(p);
          if (error.distance > tolerance) continue;
          if (correction == null || error.distance < correction.distance) {
            correction = error;
            target = q;
          }
        }
      }
      if (target == null || correction == null) break;

      // Las piezas de un conjunto comparten origen: se igualan al de la
      // pieza quieta, sin acumular errores de redondeo.
      final aligned = originOf(target);
      for (final id in members) {
        _origins[id] = aligned;
      }
      final targetGroup = groupOf(target);
      for (final id in membersOf(targetGroup)) {
        _groupOf[id] = group;
      }
      _raise(group);
      _moveGroup(group, Offset.zero); // Mantiene el conjunto en la superficie.
      joins++;
    }

    final solvedNow = !_solved && groupCount == 1;
    if (solvedNow) _solved = true;
    return ReleaseResult(joins: joins, solved: solvedNow);
  }

  /// Nueva partida: piezas separadas y repartidas por la superficie.
  void reset() {
    _solved = false;
    _resetGroups();
    _zOrder
      ..clear()
      ..addAll(photo.pieces.map((p) => p.id).toList()..shuffle(_random));
    _origins.addAll(scatter(photo, _surface, tolerance, _random));
    _clampAll();
  }

  /// Ajusta la superficie (por ejemplo, al cambiar el tamaño de pantalla) y
  /// vuelve a meter los conjuntos dentro.
  void resize(Size surface) {
    _surface = surface;
    _clampAll();
  }

  void _resetGroups() {
    _groupOf.clear();
    _origins.clear();
    for (final p in photo.pieces) {
      _groupOf[p.id] = p.id;
    }
  }

  void _clampAll() {
    for (final group in _groupOf.values.toSet()) {
      _moveGroup(group, Offset.zero);
    }
  }

  void _moveGroup(int group, Offset delta) {
    final bounds = boundsOfGroup(group).shift(delta);
    double fit(double start, double length, double limit) =>
        length >= limit ? 0 : start.clamp(0.0, limit - length);
    final corrected = Offset(
      fit(bounds.left, bounds.width, _surface.width) - bounds.left,
      fit(bounds.top, bounds.height, _surface.height) - bounds.top,
    );
    final total = delta + corrected;
    for (final id in membersOf(group)) {
      _origins[id] = originOf(id) + total;
    }
  }

  void _raise(int group) {
    final members = membersOf(group);
    _zOrder
      ..removeWhere(members.contains)
      ..addAll(members);
  }
}

/// Reparte las tres piezas en dos filas: la pieza más ancha sola y las otras
/// dos juntas, en orden y altura aleatorios. Evita que alguna pareja quede
/// por casualidad cerca de encajar.
Map<int, Offset> scatter(
  TornPhoto photo,
  Size surface,
  double tolerance,
  Random random,
) {
  final pieces = [...photo.pieces]
    ..sort((a, b) => b.bounds.width.compareTo(a.bounds.width));
  Map<int, Offset> best = {};
  var bestScore = -1.0;

  for (var attempt = 0; attempt < 60; attempt++) {
    final pair = [pieces[1], pieces[2]]..shuffle(random);
    final rows = [
      [pieces[0]],
      pair,
    ];
    if (random.nextBool()) rows.setAll(0, rows.reversed.toList());

    final rowHeights = [
      for (final row in rows) row.map((p) => p.bounds.height).reduce(max),
    ];
    final freeY = max(0.0, surface.height - rowHeights.reduce((a, b) => a + b));
    final gapY = freeY / 3;
    var y = gapY * (0.5 + random.nextDouble());

    final origins = <int, Offset>{};
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final widths = row.map((p) => p.bounds.width).reduce((a, b) => a + b);
      final freeX = max(0.0, surface.width - widths);
      // Reparte el espacio libre en huecos aleatorios a los lados y entre piezas.
      final weights = List.generate(
        row.length + 1,
        (_) => 0.4 + random.nextDouble(),
      );
      final weightSum = weights.reduce((a, b) => a + b);
      var x = freeX * weights[0] / weightSum;
      for (var i = 0; i < row.length; i++) {
        final piece = row[i];
        final rowSlack = rowHeights[r] - piece.bounds.height;
        final position = Offset(x, y + rowSlack * random.nextDouble());
        origins[piece.id] = position - piece.home;
        x += piece.bounds.width + freeX * weights[i + 1] / weightSum;
      }
      y += rowHeights[r] + gapY * (0.6 + 0.8 * random.nextDouble());
    }

    // La pareja más cercana a encajar debe quedar lejos de la tolerancia.
    var closest = double.infinity;
    for (final a in photo.pieces) {
      for (final b in photo.pieces) {
        if (a.id < b.id && photo.areNeighbors(a.id, b.id)) {
          closest = min(closest, (origins[a.id]! - origins[b.id]!).distance);
        }
      }
    }
    if (closest > bestScore) {
      best = origins;
      bestScore = closest;
    }
    if (closest > tolerance * 3) break;
  }
  return best;
}
