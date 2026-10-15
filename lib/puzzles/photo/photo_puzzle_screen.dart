import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/puzzle_top_bar.dart';
import '../../app/vestigia_theme.dart';
import '../../core/haptics.dart';
import 'photo_assembly.dart';
import 'photo_config.dart';
import 'photo_layout.dart';
import 'torn_photo.dart';
import 'widgets/photo_back_view.dart';
import 'widgets/photo_piece_view.dart';

/// Pantalla del puzzle de la fotografía. Traduce el arrastre del dedo a la
/// lógica de unión ([PhotoAssembly]) y presenta las piezas y el volteo.
class PhotoPuzzleScreen extends StatefulWidget {
  const PhotoPuzzleScreen({
    super.key,
    this.config = const PhotoPuzzleConfig(),
    this.hapticsFactory,
    this.random,
  });

  final PhotoPuzzleConfig config;
  final Haptics Function()? hapticsFactory;
  final Random? random;

  static const surfaceKey = Key('photo-surface');
  static const restartKey = Key('photo-restart');
  static const captionKey = Key('photo-caption');

  @override
  State<PhotoPuzzleScreen> createState() => PhotoPuzzleScreenState();
}

class PhotoPuzzleScreenState extends State<PhotoPuzzleScreen>
    with SingleTickerProviderStateMixin {
  static const _flipDuration = Duration(milliseconds: 1600);

  /// Pausa breve antes de voltear, para ver la foto armada.
  static const _flipDelay = 0.15;

  late final TornPhoto _photo = TornPhoto.threePieces(
    aspect: widget.config.aspect,
  );
  late final ImageProvider _image = AssetImage(widget.config.photoAsset);
  late final Haptics _haptics;
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: _flipDuration,
  );

  PhotoAssembly? _assembly;
  PhotoLayout? _layout;
  Size? _surfacePixels;
  DragSession? _drag;
  Offset _flipStart = Offset.zero;
  bool _precached = false;

  @visibleForTesting
  PhotoAssembly? get assembly => _assembly;

  @visibleForTesting
  PhotoLayout? get layout => _layout;

  PhotoPuzzleConfig get _config => widget.config;

  @override
  void initState() {
    super.initState();
    _haptics = (widget.hapticsFactory ?? PlatformHaptics.new)();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      precacheImage(_image, context);
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  /// Ajusta escala y superficie al espacio disponible. La partida se crea la
  /// primera vez que se conoce el tamaño.
  void _configure(Size pixels) {
    if (pixels == _surfacePixels) return;
    _surfacePixels = pixels;
    final layout = PhotoLayout.fit(pixels, _photo);
    _layout = layout;
    final assembly = _assembly;
    if (assembly == null) {
      _assembly = PhotoAssembly(
        photo: _photo,
        surface: layout.surface,
        tolerance: layout.toleranceFor(_config),
        random: widget.random,
      );
      // El texto inferior se construye antes que la superficie; se actualiza
      // en cuanto existe la partida.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      assembly.resize(layout.surface);
    }
  }

  Offset _toUnits(Offset local) => local / _layout!.scale;

  void _onPanStart(DragStartDetails details) {
    final session = _assembly?.beginDrag(_toUnits(details.localPosition));
    if (session != null) setState(() => _drag = session);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final session = _drag;
    if (session == null) return;
    setState(() => _assembly!.dragTo(session, _toUnits(details.localPosition)));
  }

  void _onPanEnd([Object? _]) {
    final session = _drag;
    if (session == null) return;
    final result = _assembly!.endDrag(session);
    setState(() => _drag = null);
    if (result.solved) {
      // Una sola vez por partida: endDrag solo informa la primera resolución.
      _haptics.play(HapticCue.photoSolved);
      _flipStart = _assembly!.originOf(0);
      _flip.forward(from: 0);
    }
  }

  void _restart() {
    setState(() {
      _drag = null;
      _flip.reset();
      _assembly?.reset();
    });
  }

  void _backToMenu() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PuzzleTopBar(
              title: 'Fotografía',
              onBack: _backToMenu,
              onRestart: _restart,
              restartKey: PhotoPuzzleScreen.restartKey,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _configure(constraints.biggest);
                    return _surface();
                  },
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _flip,
              builder: (context, _) => _Caption(
                assembly: _assembly,
                flipDone: _flip.isCompleted,
                coordinatePart: _config.coordinatePart,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _surface() {
    final assembly = _assembly!;
    final scale = _layout!.scale;
    final dragged = _drag == null
        ? const <int>{}
        : assembly.membersOf(_drag!.group);

    return GestureDetector(
      key: PhotoPuzzleScreen.surfaceKey,
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanEnd,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [VestigiaColors.woodLight, VestigiaColors.wood],
          ),
          border: Border.all(color: Colors.black54, width: 2),
        ),
        child: SizedBox.expand(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                if (!assembly.isSolved)
                  for (final id in assembly.zOrder)
                    Positioned(
                      left: assembly.positionOf(id).dx * scale,
                      top: assembly.positionOf(id).dy * scale,
                      child: _pieceView(id, lifted: dragged.contains(id)),
                    )
                else
                  _flippingPhoto(assembly, scale),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PhotoPieceView _pieceView(int id, {bool lifted = false}) => PhotoPieceView(
    key: ValueKey('photo-piece-$id'),
    piece: _photo.piece(id),
    scale: _layout!.scale,
    aspect: _photo.aspect,
    image: _image,
    lifted: lifted,
  );

  /// La foto armada gira como un solo objeto hacia el centro hasta mostrar
  /// su reverso.
  Widget _flippingPhoto(PhotoAssembly assembly, double scale) {
    return AnimatedBuilder(
      animation: _flip,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(
          const Interval(_flipDelay, 1).transform(_flip.value),
        );
        final surface = assembly.surface;
        final center = Offset(
          (surface.width - 1) / 2,
          (surface.height - _photo.aspect) / 2,
        );
        final origin = Offset.lerp(_flipStart, center, t)!;
        final angle = pi * t;
        final showBack = angle > pi / 2;

        final Widget face = showBack
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(pi),
                child: PhotoBackView(
                  photo: _photo,
                  scale: scale,
                  text: _config.coordinatePart,
                ),
              )
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final piece in _photo.pieces)
                    Positioned(
                      left: piece.home.dx * scale,
                      top: piece.home.dy * scale,
                      child: _pieceView(piece.id),
                    ),
                ],
              );

        return Positioned(
          left: origin.dx * scale,
          top: origin.dy * scale,
          width: scale,
          height: _photo.aspect * scale,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: Transform.scale(scale: 1 + 0.06 * sin(pi * t), child: face),
          ),
        );
      },
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({
    required this.assembly,
    required this.flipDone,
    required this.coordinatePart,
  });

  final PhotoAssembly? assembly;
  final bool flipDone;
  final String coordinatePart;

  String get _text {
    final a = assembly;
    if (a == null) return '';
    if (a.isSolved) {
      return flipDone
          ? 'Inscripción en el reverso: $coordinatePart'
          : 'Fotografía completa';
    }
    return switch (a.groupCount) {
      3 => 'Arrastra los pedazos y une sus bordes',
      _ => 'Dos pedazos unidos · falta uno',
    };
  }

  @override
  Widget build(BuildContext context) {
    final solvedAndShown = (assembly?.isSolved ?? false) && flipDone;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _text,
            key: PhotoPuzzleScreen.captionKey,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: solvedAndShown ? 17 : 15,
              color: solvedAndShown
                  ? VestigiaColors.glow
                  : VestigiaColors.cream,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            ' ',
            style: const TextStyle(
              fontSize: 12,
              color: VestigiaColors.creamMuted,
            ),
          ),
        ],
      ),
    );
  }
}
