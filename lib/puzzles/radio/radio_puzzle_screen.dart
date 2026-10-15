import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/puzzle_top_bar.dart';
import '../../app/vestigia_theme.dart';
import '../../core/dial_feedback.dart';
import '../../core/haptics.dart';
import '../../core/widgets/tuning_knob.dart';
import 'radio_audio.dart';
import 'radio_config.dart';
import 'radio_tuning_game.dart';
import 'widgets/tuning_window.dart';

/// Pantalla del puzzle de radio. Conecta la lógica ([RadioTuningGame]) con
/// la interfaz, el audio y la vibración; no contiene reglas del puzzle.
class RadioPuzzleScreen extends StatefulWidget {
  const RadioPuzzleScreen({
    super.key,
    this.config = const RadioPuzzleConfig(),
    this.audioFactory,
    this.hapticsFactory,
    this.planner,
    this.random,
  });

  final RadioPuzzleConfig config;
  final RadioAudio Function()? audioFactory;
  final Haptics Function()? hapticsFactory;

  /// Sustituye la generación aleatoria de señales (pruebas).
  final SignalPlanner? planner;
  final Random? random;

  static const knobKey = Key('radio-knob');
  static const statusKey = Key('radio-status');
  static const restartKey = Key('radio-restart');

  @override
  State<RadioPuzzleScreen> createState() => _RadioPuzzleScreenState();
}

class _RadioPuzzleScreenState extends State<RadioPuzzleScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _maxFrameStep = Duration(milliseconds: 250);

  late final RadioTuningGame _game;
  late final RadioAudio _audio;
  late final Haptics _haptics;
  late final Ticker _ticker;
  final _detents = DialDetentTracker();
  final _clock = Stopwatch()..start();

  Duration _lastTick = Duration.zero;
  double _time = 0;

  /// El doble clic de “señal encontrada” suena una vez y no se rearma hasta
  /// alejarse claramente, para no vibrar en cada roce con el borde.
  bool _signalCueArmed = true;
  bool _foreground = true;
  bool _shutDown = false;

  RadioPuzzleConfig get _config => widget.config;

  @override
  void initState() {
    super.initState();
    _game = RadioTuningGame(
      config: _config,
      random: widget.random,
      planner: widget.planner,
    );
    _audio = (widget.audioFactory ?? PlatformRadioAudio.new)();
    _haptics = (widget.hapticsFactory ?? PlatformHaptics.new)();
    _detents.reset(_game.dial);
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addObserver(this);
    _audio.start(_game.signalStrength);
  }

  @override
  void dispose() {
    _shutdown();
    _ticker.dispose();
    super.dispose();
  }

  /// Detiene audio, reloj y espera. Se llama en cuanto se sale de la
  /// pantalla (sin esperar a que termine la transición) y en [dispose].
  void _shutdown() {
    if (_shutDown) return;
    _shutDown = true;
    _ticker.stop();
    _game.cancelHold();
    _audio.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_shutDown) return;
    if (state == AppLifecycleState.resumed) {
      if (_foreground) return;
      _foreground = true;
      _lastTick = Duration.zero;
      _ticker.start();
      _audio.resume();
    } else {
      if (!_foreground) return;
      _foreground = false;
      _ticker.stop();
      _game.cancelHold();
      _audio.pause();
      setState(() {});
    }
  }

  void _onTick(Duration elapsed) {
    var step = elapsed - _lastTick;
    _lastTick = elapsed;
    if (step > _maxFrameStep) step = _maxFrameStep;
    _time += step.inMicroseconds / Duration.microsecondsPerSecond;

    final capture = _game.advance(step);
    if (capture != null) {
      _haptics.play(
        capture.completesPuzzle ? HapticCue.complete : HapticCue.capture,
      );
    }
    _syncFeedback();
    setState(() {});
  }

  void _onDialChanged(double value) {
    if (_shutDown || _game.isComplete) return;
    _game.setDial(value);
    switch (_detents.onMoved(_game.dial, _clock.elapsed)) {
      case DialFeedback.detent:
        _haptics.play(HapticCue.tick);
      case DialFeedback.limit:
        _haptics.play(HapticCue.limit);
      case DialFeedback.none:
        break;
    }
    _syncFeedback();
    setState(() {});
  }

  /// Vibración al entrar en la franja y sonido según la misma intensidad
  /// que dibuja la ventana.
  void _syncFeedback() {
    if (_game.isInBand) {
      if (_signalCueArmed) _haptics.play(HapticCue.signalFound);
      _signalCueArmed = false;
    } else if ((_game.distanceToSignal ?? 0) > _config.bandHalfWidth * 2) {
      _signalCueArmed = true;
    }
    _audio.setSignalStrength(_game.signalStrength);
  }

  void _restart() {
    if (_shutDown) return;
    setState(() {
      _game.restart();
      _detents.reset(_game.dial);
      _signalCueArmed = true;
      _audio.setSignalStrength(_game.signalStrength);
    });
  }

  void _backToMenu() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _shutdown();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              PuzzleTopBar(
                title: 'Radio',
                onBack: _backToMenu,
                onRestart: _restart,
                restartKey: RadioPuzzleScreen.restartKey,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RadioFace(config: _config, game: _game, time: _time),
                      const SizedBox(height: 14),
                      _StatusLine(game: _game, paused: !_foreground),
                      const SizedBox(height: 14),
                      _DigitSlots(game: _game),
                      const SizedBox(height: 12),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _game.isComplete
                              ? _CompletionPanel(
                                  digits: _game.capturedDigits,
                                  onRepeat: _restart,
                                  onMenu: _backToMenu,
                                )
                              : _knob(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _knob() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(
          min(constraints.maxWidth, constraints.maxHeight),
          320.0,
        );
        return Center(
          child: SizedBox.square(
            dimension: side,
            child: TuningKnob(
              key: RadioPuzzleScreen.knobKey,
              value: _game.dial,
              sweepRadians: _config.knobTurnsForFullScale * 2 * pi,
              onChanged: _onDialChanged,
              describeValue: (dial) =>
                  '${_config.frequencyAt(dial).round()} kilohercios',
            ),
          ),
        );
      },
    );
  }
}

/// Mueble de madera con la ventana de canales y la frecuencia actual.
class _RadioFace extends StatelessWidget {
  const _RadioFace({
    required this.config,
    required this.game,
    required this.time,
  });

  final RadioPuzzleConfig config;
  final RadioTuningGame game;
  final double time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [VestigiaColors.woodLight, VestigiaColors.wood],
        ),
        border: Border.all(color: Colors.black54, width: 2),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.9,
            child: TuningWindow(
              config: config,
              dial: game.dial,
              strength: game.signalStrength,
              time: time,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${config.frequencyAt(game.dial).round()} kHz',
            style: const TextStyle(
              fontSize: 15,
              letterSpacing: 2,
              color: VestigiaColors.creamMuted,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.game, required this.paused});

  final RadioTuningGame game;
  final bool paused;

  /// Sin pistas de cercanía: la señal se encuentra solo de oído.
  String get _message {
    if (game.isComplete) return 'Mensaje completo';
    if (paused) return 'En pausa';
    return 'Gira la perilla y escucha';
  }

  @override
  Widget build(BuildContext context) {
    final rounds = game.config.rounds;
    final current = min(game.round + 1, rounds);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              game.isComplete
                  ? 'Señales $rounds de $rounds'
                  : 'Señal $current de $rounds',
              style: const TextStyle(
                fontSize: 14,
                color: VestigiaColors.brass,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _message,
                key: RadioPuzzleScreen.statusKey,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 15,
                  color: VestigiaColors.cream,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: game.holdProgress,
            minHeight: 6,
            color: VestigiaColors.signal,
            backgroundColor: VestigiaColors.glass,
            semanticsLabel: 'Captura de la señal',
          ),
        ),
      ],
    );
  }
}

class _DigitSlots extends StatelessWidget {
  const _DigitSlots({required this.game});

  final RadioTuningGame game;

  @override
  Widget build(BuildContext context) {
    final digits = game.capturedDigits;
    return Column(
      children: [
        const Text(
          'Mensaje recibido',
          style: TextStyle(fontSize: 13, color: VestigiaColors.creamMuted),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < game.config.rounds; i++)
              Container(
                key: Key('digit-slot-$i'),
                width: 56,
                height: 64,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: VestigiaColors.glass,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: i < digits.length
                        ? VestigiaColors.signal
                        : VestigiaColors.brassDark,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  i < digits.length ? '${digits[i]}' : '–',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: i < digits.length
                        ? VestigiaColors.glow
                        : VestigiaColors.brassDark,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CompletionPanel extends StatelessWidget {
  const _CompletionPanel({
    required this.digits,
    required this.onRepeat,
    required this.onMenu,
  });

  final List<int> digits;
  final VoidCallback onRepeat;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Mensaje registrado',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: VestigiaColors.creamMuted),
            ),
            const SizedBox(height: 4),
            Text(
              digits.join(),
              key: const Key('radio-coordinates'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 44,
                letterSpacing: 12,
                fontWeight: FontWeight.w600,
                color: VestigiaColors.glow,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRepeat,
              icon: const Icon(Icons.replay),
              label: const Text('Repetir'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onMenu,
              icon: const Icon(Icons.grid_view),
              label: const Text('Volver al menú'),
            ),
          ],
        ),
      ),
    );
  }
}
