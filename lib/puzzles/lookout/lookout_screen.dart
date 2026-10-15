import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/puzzle_top_bar.dart';
import '../../app/vestigia_theme.dart';
import '../../core/dial_feedback.dart';
import '../../core/haptics.dart';
import '../../core/widgets/tuning_knob.dart';
import 'lookout_config.dart';
import 'lookout_game.dart';
import 'widgets/lens_view.dart';
import 'widgets/observation_view.dart';

/// Pantalla del mirador del faro. Traduce los dedos sobre el lente y las
/// perillas a [LookoutGame]; no contiene reglas del puzzle.
class LookoutScreen extends StatefulWidget {
  const LookoutScreen({
    super.key,
    this.config = const LookoutConfig(),
    this.hapticsFactory,
  });

  final LookoutConfig config;
  final Haptics Function()? hapticsFactory;

  static const lensKey = Key('lookout-lens');
  static const xKnobKey = Key('lookout-knob-x');
  static const yKnobKey = Key('lookout-knob-y');
  static const debugKey = Key('lookout-debug');
  static const statusKey = Key('lookout-status');
  static const restartKey = Key('lookout-restart');

  @override
  State<LookoutScreen> createState() => LookoutScreenState();
}

class LookoutScreenState extends State<LookoutScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final LookoutGame _game = LookoutGame(widget.config);
  late final ImageProvider _panorama = AssetImage(widget.config.panoramaAsset);
  late final Haptics _haptics;

  /// Al terminar la limpieza, la suciedad restante se desvanece.
  late final AnimationController _dirtFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final AnimationController _observation =
      AnimationController(vsync: this, duration: _config.observationDuration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(_game.finishObservation);
          }
        });

  final Map<int, int> _strokeByPointer = {};
  final _xDetents = DialDetentTracker();
  final _yDetents = DialDetentTracker();
  final _clock = Stopwatch()..start();
  double _lensDiameter = 1;
  bool _precached = false;

  @visibleForTesting
  LookoutGame get game => _game;

  LookoutConfig get _config => widget.config;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _haptics = (widget.hapticsFactory ?? PlatformHaptics.new)();
    _resetDetents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      precacheImage(_panorama, context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _observation.dispose();
    _dirtFade.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_game.phase == LookoutPhase.observing) _observation.forward();
    } else {
      _observation.stop();
    }
  }

  void _resetDetents() {
    _xDetents.reset(_config.xRange.normalize(_game.view.x));
    _yDetents.reset(_config.yRange.normalize(_game.view.y));
  }

  Offset _toLens(Offset local) =>
      (local - const Offset(LensView.rimWidth, LensView.rimWidth)) /
      _lensDiameter;

  void _onPointerDown(PointerDownEvent event) {
    final result = _game.beginWipe(_toLens(event.localPosition));
    final stroke = result.stroke;
    if (stroke == null) return;
    _strokeByPointer[event.pointer] = stroke;
    _handle(result.event);
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    final stroke = _strokeByPointer[event.pointer];
    if (stroke == null) return;
    _handle(_game.extendWipe(stroke, _toLens(event.localPosition)));
    setState(() {});
  }

  void _onPointerEnd(PointerEvent event) =>
      _strokeByPointer.remove(event.pointer);

  void _onX(double t) {
    if (_game.phase != LookoutPhase.orienting) return;
    _knobFeedback(_xDetents, t);
    _handle(_game.setX(_config.xRange.fromNormalized(t)));
    setState(() {});
  }

  void _onY(double t) {
    if (_game.phase != LookoutPhase.orienting) return;
    _knobFeedback(_yDetents, t);
    _handle(_game.setY(_config.yRange.fromNormalized(t)));
    setState(() {});
  }

  void _knobFeedback(DialDetentTracker tracker, double t) {
    switch (tracker.onMoved(t, _clock.elapsed)) {
      case DialFeedback.detent:
        _haptics.play(HapticCue.tick);
      case DialFeedback.limit:
        _haptics.play(HapticCue.limit);
      case DialFeedback.none:
        break;
    }
  }

  void _handle(LookoutEvent? event) {
    switch (event) {
      case LookoutEvent.lensCleaned:
        _haptics.play(HapticCue.capture);
        _strokeByPointer.clear();
        _dirtFade.forward();
      case LookoutEvent.aligned:
        _haptics.play(HapticCue.signalFound);
        _strokeByPointer.clear();
        _dirtFade.forward();
        _observation.forward(from: 0);
      case null:
        break;
    }
  }

  void _restart() {
    setState(() {
      _game.reset();
      _dirtFade.reset();
      _observation.reset();
      _strokeByPointer.clear();
      _resetDetents();
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
              title: 'Mirador del faro',
              onBack: _backToMenu,
              onRestart: _restart,
              restartKey: LookoutScreen.restartKey,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _lensDiameter =
                      min(
                        constraints.maxWidth - 32,
                        constraints.maxHeight * 0.5,
                      ).clamp(120.0, 380.0) -
                      2 * LensView.rimWidth;
                  return Column(
                    children: [
                      const SizedBox(height: 4),
                      _lens(),
                      if (_config.showDebugValues) _debugValues(),
                      const SizedBox(height: 8),
                      Expanded(child: _phaseControls()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lens() {
    if (_game.phase == LookoutPhase.observing ||
        _game.phase == LookoutPhase.solved) {
      return AnimatedBuilder(
        animation: _observation,
        builder: (_, _) => ObservationView(
          panorama: _panorama,
          progress: _observation.value,
          size: _lensDiameter + 2 * LensView.rimWidth,
        ),
      );
    }
    return Listener(
      key: LookoutScreen.lensKey,
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: AnimatedBuilder(
        animation: _dirtFade,
        builder: (context, _) => LensView(
          diameter: _lensDiameter,
          panorama: _panorama,
          panoramaAspect: _config.panoramaAspect,
          viewWidthFraction: _config.viewWidthFraction,
          viewCenter: _game.view.viewCenter,
          target: _config.targetPosition,
          strokes: _game.lens.strokes,
          strokesRevision: _game.lens.revision,
          brushRadius: _config.brushRadius,
          dirtOpacity: _game.phase == LookoutPhase.cleaning
              ? 1
              : 1 - _dirtFade.value,
          aligned: _game.phase == LookoutPhase.solved,
        ),
      ),
    );
  }

  /// Datos de depuración; se ocultan con `LookoutConfig.showDebugValues`.
  Widget _debugValues() {
    String format(double v) => v.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'X: ${format(_game.view.x)}    Y: ${format(_game.view.y)}',
        key: LookoutScreen.debugKey,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: VestigiaColors.creamMuted,
        ),
      ),
    );
  }

  Widget _phaseControls() {
    final phase = _game.phase;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: phase == LookoutPhase.cleaning
          ? _CleaningStatus(
              key: const ValueKey('cleaning'),
              progress: _game.lens.progress,
            )
          : Column(
              key: const ValueKey('orienting'),
              children: [
                _OrientStatus(phase: phase),
                const SizedBox(height: 8),
                Expanded(
                  child: _knobs(enabled: phase == LookoutPhase.orienting),
                ),
              ],
            ),
    );
  }

  Widget _knobs({required bool enabled}) {
    final sweep = _config.knobTurnsForFullRange * 2 * pi;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(
          (constraints.maxWidth - 48) / 2,
          constraints.maxHeight - 34,
        ).clamp(80.0, 170.0);
        Widget knob({
          required Key key,
          required String label,
          required IconData icon,
          required double value,
          required ValueChanged<double> onChanged,
          required String axis,
          required double Function(double) toAxis,
        }) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: VestigiaColors.brass),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: VestigiaColors.cream,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox.square(
                dimension: size,
                child: TuningKnob(
                  key: key,
                  value: value,
                  sweepRadians: sweep,
                  onChanged: onChanged,
                  enabled: enabled,
                  describeValue: (t) => '$axis ${toAxis(t).toStringAsFixed(1)}',
                ),
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: knob(
                key: LookoutScreen.xKnobKey,
                label: 'Horizontal · X',
                icon: Icons.swap_horiz,
                value: _config.xRange.normalize(_game.view.x),
                onChanged: _onX,
                axis: 'X',
                toAxis: _config.xRange.fromNormalized,
              ),
            ),
            Expanded(
              child: knob(
                key: LookoutScreen.yKnobKey,
                label: 'Vertical · Y',
                icon: Icons.swap_vert,
                value: _config.yRange.normalize(_game.view.y),
                onChanged: _onY,
                axis: 'Y',
                toAxis: _config.yRange.fromNormalized,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CleaningStatus extends StatelessWidget {
  const _CleaningStatus({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Text(
            'Desliza los dedos sobre el lente para limpiarlo',
            key: LookoutScreen.statusKey,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: VestigiaColors.cream),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: VestigiaColors.brass,
              backgroundColor: VestigiaColors.glass,
              semanticsLabel: 'Lente limpio',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lente limpio: ${(progress * 100).floor()} %',
            style: const TextStyle(
              fontSize: 13,
              color: VestigiaColors.creamMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrientStatus extends StatelessWidget {
  const _OrientStatus({required this.phase});

  final LookoutPhase phase;

  @override
  Widget build(BuildContext context) {
    if (phase == LookoutPhase.observing) {
      return const Text(
        'Una luz entre las nubes…',
        key: LookoutScreen.statusKey,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: VestigiaColors.cream),
      );
    }
    if (phase != LookoutPhase.solved) {
      return const Text(
        'Gira las perillas para orientar la vista',
        key: LookoutScreen.statusKey,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: VestigiaColors.cream),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: VestigiaColors.glass,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VestigiaColors.signal, width: 1.5),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: VestigiaColors.signal),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'El faro y el Observatorio responden',
              key: LookoutScreen.statusKey,
              style: TextStyle(fontSize: 16, color: VestigiaColors.cream),
            ),
          ),
        ],
      ),
    );
  }
}
