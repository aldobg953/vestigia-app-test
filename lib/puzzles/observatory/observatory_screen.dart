import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../app/puzzle_top_bar.dart';
import '../../app/vestigia_theme.dart';
import '../../core/haptics.dart';
import 'observatory_game.dart';
import 'orientation_source.dart';
import 'widgets/sky_view.dart';

class ObservatoryScreen extends StatefulWidget {
  const ObservatoryScreen({
    super.key,
    this.config = const ObservatoryConfig(),
    this.orientationFactory,
    this.hapticsFactory,
  });

  final ObservatoryConfig config;
  final OrientationSource Function()? orientationFactory;
  final Haptics Function()? hapticsFactory;

  static const arKey = Key('observatory-ar');
  static const decKey = Key('observatory-dec');
  static const prepareKey = Key('observatory-prepare');
  static const calibrateKey = Key('observatory-calibrate');
  static const skyKey = Key('observatory-sky');
  static const statusKey = Key('observatory-status');
  static const restartKey = Key('observatory-restart');

  @override
  State<ObservatoryScreen> createState() => ObservatoryScreenState();
}

class ObservatoryScreenState extends State<ObservatoryScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final ObservatoryGame _game = ObservatoryGame(widget.config);
  late final OrientationSource _source =
      (widget.orientationFactory ?? PlatformOrientationSource.new)();
  late final Haptics _haptics =
      (widget.hapticsFactory ?? PlatformHaptics.new)();
  late final Ticker _ticker;
  final _ar = TextEditingController();
  final _dec = TextEditingController();
  StreamSubscription<PointingSample>? _subscription;
  Duration _now = Duration.zero;
  Duration _clockOffset = Duration.zero;
  String? _error;
  String? _sensorError;
  bool _paused = false;
  bool _closed = false;

  @visibleForTesting
  ObservatoryGame get game => _game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onFrame);
    _start();
  }

  void _start() {
    if (_closed || _paused || _game.phase == ObservatoryPhase.solved) return;
    _clockOffset = _now;
    if (!_ticker.isActive) _ticker.start();
    _subscription ??= _source.samples.listen(
      (sample) {
        if (!mounted || _closed || _paused) return;
        setState(() => _game.receive(sample, _now));
      },
      onError: (Object error) {
        if (!mounted || _closed) return;
        _stop();
        setState(() {
          _game.suspend();
          _sensorError =
              error is PlatformException && error.code == 'sensor_unavailable'
              ? 'Este teléfono no ofrece el sensor de orientación requerido.'
              : 'No se pudo recibir la orientación del teléfono.';
        });
      },
    );
  }

  void _stop() {
    _ticker.stop();
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(
        subscription.cancel().catchError((Object error) {
          debugPrint('Orientation cancellation failed: $error');
        }),
      );
    }
  }

  void _onFrame(Duration elapsed) {
    final wasFresh = _game.hasFreshSample(_now);
    _now = _clockOffset + elapsed;
    final solved = _game.advance(_now);
    if (solved) {
      _haptics.play(HapticCue.complete);
      _stop();
    }
    if (mounted &&
        (solved ||
            _game.phase == ObservatoryPhase.searching ||
            wasFresh != _game.hasFreshSample(_now))) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_closed) return;
    if (state == AppLifecycleState.resumed) {
      _paused = false;
      _sensorError = null;
      _start();
    } else {
      _paused = true;
      _game.suspend();
      _stop();
    }
    if (mounted) setState(() {});
  }

  void _prepare() {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = _game.submitCodes(_ar.text, _dec.text)
          ? null
          : 'Revisa los dos registros y conserva el signo.';
    });
  }

  void _calibrate() {
    setState(() {
      _error = _game.calibrate(_now)
          ? null
          : 'Espera la lectura y apunta hacia la pantalla, sin mirar al techo.';
    });
  }

  void _restart() {
    _stop();
    _game.reset();
    _ar.clear();
    _dec.clear();
    _error = null;
    _sensorError = null;
    _start();
    setState(() {});
  }

  void _back() {
    _closed = true;
    _stop();
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _closed = true;
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    _ticker.dispose();
    _ar.dispose();
    _dec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = _game.phase;
    final searching = phase == ObservatoryPhase.searching;
    final solved = phase == ObservatoryPhase.solved;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _closed = true;
          _stop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              PuzzleTopBar(
                title: 'Observatorio',
                onBack: _back,
                onRestart: _restart,
                restartKey: ObservatoryScreen.restartKey,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    SizedBox(
                      height: min(MediaQuery.sizeOf(context).width - 40, 300),
                      child: RepaintBoundary(
                        key: ObservatoryScreen.skyKey,
                        child: SkyView(
                          pointing: searching || solved
                              ? _game.pointing
                              : const PointingSample(0, 25),
                          revealed: solved,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _paused ? 'En pausa' : _status,
                      key: ObservatoryScreen.statusKey,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        color: solved
                            ? VestigiaColors.signal
                            : VestigiaColors.cream,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (phase == ObservatoryPhase.coordinates) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: ObservatoryScreen.arKey,
                              controller: _ar,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'AR (°)',
                                hintText: '000',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              key: ObservatoryScreen.decKey,
                              controller: _dec,
                              // Numeric Android keyboards do not always offer '+'.
                              keyboardType: TextInputType.text,
                              autocorrect: false,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[+\-0-9]'),
                                ),
                                LengthLimitingTextInputFormatter(4),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'DEC (°)',
                                hintText: '+000',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: ObservatoryScreen.prepareKey,
                        onPressed: _prepare,
                        icon: const Icon(Icons.settings),
                        label: const Text('Preparar telescopio'),
                      ),
                    ],
                    if (phase == ObservatoryPhase.calibrating) ...[
                      const Text(
                        'Apunta el teléfono hacia la pantalla de la PC.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: ObservatoryScreen.calibrateKey,
                        onPressed: _game.hasFreshSample(_now) && !_paused
                            ? _calibrate
                            : null,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Calibrar'),
                      ),
                      if (!_game.hasFreshSample(_now))
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Esperando orientación del teléfono',
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                    if (searching) ...[
                      LinearProgressIndicator(
                        value: _game.holdProgress,
                        minHeight: 6,
                        semanticsLabel: 'Estabilidad de la observación',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'AZ: ${_game.pointing.azimuth.toStringAsFixed(1)}°   ALT: ${_game.pointing.altitude.toStringAsFixed(1)}°',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _game.requestCalibration()),
                        icon: const Icon(Icons.my_location),
                        label: const Text('Recalibrar'),
                      ),
                    ],
                    if (solved) ...[
                      const Text(
                        'Fuente de la anomalía localizada',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _restart,
                        icon: const Icon(Icons.replay),
                        label: const Text('Repetir'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _back,
                        icon: const Icon(Icons.grid_view),
                        label: const Text('Volver al menú'),
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: VestigiaColors.needle),
                        ),
                      ),
                    if (_sensorError != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _sensorError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: VestigiaColors.needle),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _sensorError = null);
                          _start();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar sensor'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _status => switch (_game.phase) {
    ObservatoryPhase.coordinates => 'Registro astronómico',
    ObservatoryPhase.calibrating => 'Referencia del instrumento',
    ObservatoryPhase.searching =>
      !_game.hasFreshSample(_now)
          ? 'Esperando orientación'
          : _game.separation <= _game.config.toleranceDegrees
          ? 'Señal estable'
          : 'Buscando la señal',
    ObservatoryPhase.solved => 'Magnetar',
  };
}
