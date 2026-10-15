import 'package:flutter/material.dart';

import '../torn_photo.dart';

/// Un pedazo de la fotografía: la parte correspondiente de la imagen,
/// recortada con su contorno rasgado y con el alma blanca del papel visible
/// en los bordes rotos.
class PhotoPieceView extends StatelessWidget {
  const PhotoPieceView({
    super.key,
    required this.piece,
    required this.scale,
    required this.aspect,
    required this.image,
    this.lifted = false,
  });

  final PhotoPiece piece;

  /// Píxeles por ancho de foto.
  final double scale;
  final double aspect;
  final ImageProvider image;

  /// Se dibuja más elevado mientras se arrastra.
  final bool lifted;

  Path _localPath() {
    final origin = piece.home;
    final points = piece.outline.map((p) => (p - origin) * scale).toList();
    return Path()..addPolygon(points, true);
  }

  @override
  Widget build(BuildContext context) {
    final bounds = piece.bounds;
    final path = _localPath();
    return Semantics(
      label: 'Pedazo ${piece.id + 1} de la fotografía',
      child: SizedBox(
        width: bounds.width * scale,
        height: bounds.height * scale,
        child: CustomPaint(
          painter: _ShadowPainter(path: path, lifted: lifted),
          child: ClipPath(
            clipper: _PathClipper(path),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -bounds.left * scale,
                  top: -bounds.top * scale,
                  width: scale,
                  height: aspect * scale,
                  child: Image(
                    image: image,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TornEdgePainter(
                      edges: [
                        for (final edge in piece.tornEdges)
                          [for (final p in edge) (p - piece.home) * scale],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PathClipper extends CustomClipper<Path> {
  _PathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PathClipper old) => old.path != path;
}

class _ShadowPainter extends CustomPainter {
  _ShadowPainter({required this.path, required this.lifted});

  final Path path;
  final bool lifted;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawShadow(path, Colors.black, lifted ? 10 : 3, false);
  }

  @override
  bool shouldRepaint(_ShadowPainter old) =>
      old.path != path || old.lifted != lifted;
}

/// Fibras blancas del papel a lo largo de los bordes rasgados.
class _TornEdgePainter extends CustomPainter {
  _TornEdgePainter({required this.edges});

  final List<List<Offset>> edges;

  @override
  void paint(Canvas canvas, Size size) {
    final paper = Paint()
      ..color = const Color(0xFFF4ECDA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round;
    final fiber = Paint()
      ..color = const Color(0x55A08A66)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final edge in edges) {
      final path = Path()..addPolygon(edge, false);
      canvas.drawPath(path, paper);
      canvas.drawPath(path.shift(const Offset(0.6, 0.6)), fiber);
    }
  }

  @override
  bool shouldRepaint(_TornEdgePainter old) => old.edges != edges;
}
