import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_coordenadas/app/vestigia_app.dart';
import 'package:radio_coordenadas/core/haptics.dart';
import 'package:radio_coordenadas/menu/puzzle_entry.dart';
import 'package:radio_coordenadas/puzzles/observatory/observatory_game.dart';
import 'package:radio_coordenadas/puzzles/observatory/observatory_screen.dart';
import 'package:radio_coordenadas/puzzles/observatory/orientation_source.dart';

import 'support/fakes.dart';
import 'support/visual_verification.dart';

class FakeOrientation implements OrientationSource {
  int listens = 0;
  int cancels = 0;
  late final controller = StreamController<PointingSample>.broadcast(
    sync: true,
    onListen: () => listens++,
    onCancel: () => cancels++,
  );

  @override
  Stream<PointingSample> get samples => controller.stream;

  void point(double azimuth, double altitude) =>
      controller.add(PointingSample(azimuth, altitude));
}

class ObservatoryHarness {
  final orientation = FakeOrientation();
  final haptics = FakeHaptics();
  final boundary = GlobalKey();

  Widget app() => RepaintBoundary(
    key: boundary,
    child: VestigiaApp(
      puzzles: [
        PuzzleEntry(
          id: 'observatory',
          title: 'Observatorio',
          description: 'Prueba',
          icon: Icons.travel_explore,
          builder: (_) => ObservatoryScreen(
            orientationFactory: () => orientation,
            hapticsFactory: () => haptics,
          ),
        ),
      ],
    ),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Observatorio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> prepare(WidgetTester tester, {String dec = '+042'}) async {
    await tester.enterText(find.byKey(ObservatoryScreen.arKey), '137');
    await tester.enterText(find.byKey(ObservatoryScreen.decKey), dec);
    await tester.tap(find.byKey(ObservatoryScreen.prepareKey));
    await tester.pump();
  }

  Future<void> calibrate(WidgetTester tester) async {
    await prepare(tester);
    await pumpFrames(tester, const Duration(milliseconds: 100));
    orientation.point(200, 0);
    await tester.pump();
    await tester.ensureVisible(find.byKey(ObservatoryScreen.calibrateKey));
    await tester.pump();
    await tester.tap(find.byKey(ObservatoryScreen.calibrateKey));
    await tester.pump();
    expect(gameOf(tester).phase, ObservatoryPhase.searching);
  }

  Future<void> hold(WidgetTester tester, int frames) async {
    for (var i = 0; i < frames; i++) {
      orientation.point(200, 68);
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> snapshot(WidgetTester tester, String name) async {
    await captureScreen(tester, find.byKey(boundary), name);
  }
}

ObservatoryGame gameOf(WidgetTester tester) =>
    tester.state<ObservatoryScreenState>(find.byType(ObservatoryScreen)).game;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVerificationFonts);
  testWidgets('campos AR/DEC conservan el signo y rechazan código incorrecto', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final harness = ObservatoryHarness();
    await harness.open(tester);
    await harness.snapshot(tester, 'observatorio-registros');
    await harness.prepare(tester, dec: '042');
    expect(gameOf(tester).phase, ObservatoryPhase.coordinates);
    expect(
      find.text('Revisa los dos registros y conserva el signo.'),
      findsOneWidget,
    );
    await harness.prepare(tester);
    expect(gameOf(tester).phase, ObservatoryPhase.calibrating);
    expect(
      tester
          .widget<FilledButton>(find.byKey(ObservatoryScreen.calibrateKey))
          .onPressed,
      isNull,
    );
    harness.orientation.point(200, 0);
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(ObservatoryScreen.calibrateKey))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('mover el teléfono actualiza el cielo y confirma una sola vez', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final harness = ObservatoryHarness();
    await harness.open(tester);
    await harness.calibrate(tester);
    expect(find.text('AZ: 0.0°   ALT: 0.0°'), findsOneWidget);
    await harness.hold(tester, 19);
    expect(gameOf(tester).phase, ObservatoryPhase.searching);
    await harness.snapshot(tester, 'observatorio-busqueda');
    await harness.hold(tester, 2);
    expect(gameOf(tester).phase, ObservatoryPhase.solved);
    expect(find.text('Magnetar'), findsOneWidget);
    expect(
      harness.haptics.cues.where((cue) => cue == HapticCue.complete),
      hasLength(1),
    );
    expect(harness.orientation.cancels, 1);
    await harness.snapshot(tester, 'observatorio-magnetar');
    await pumpFrames(tester, const Duration(seconds: 3));
    expect(
      harness.haptics.cues.where((cue) => cue == HapticCue.complete),
      hasLength(1),
    );
    await tester.tap(find.byKey(ObservatoryScreen.restartKey));
    await tester.pump();
    expect(gameOf(tester).phase, ObservatoryPhase.coordinates);
    expect(
      tester
          .widget<TextField>(find.byKey(ObservatoryScreen.arKey))
          .controller!
          .text,
      isEmpty,
    );
    expect(harness.orientation.listens, 2);
  });

  testWidgets('sin lecturas no completa y pausa obliga a recalibrar', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final harness = ObservatoryHarness();
    await harness.open(tester);
    await harness.calibrate(tester);
    await harness.hold(tester, 10);
    await pumpFrames(tester, const Duration(seconds: 2));
    expect(gameOf(tester).phase, ObservatoryPhase.searching);
    expect(gameOf(tester).holdProgress, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(harness.orientation.cancels, 1);
    expect(gameOf(tester).phase, ObservatoryPhase.calibrating);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(harness.orientation.listens, 2);
    expect(
      tester
          .widget<FilledButton>(find.byKey(ObservatoryScreen.calibrateKey))
          .onPressed,
      isNull,
    );
  });

  testWidgets('sensor no disponible se informa y permite reintento', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final harness = ObservatoryHarness();
    await harness.open(tester);
    harness.orientation.controller.addError(
      PlatformException(code: 'sensor_unavailable'),
    );
    await tester.pump();
    expect(
      find.text('Este teléfono no ofrece el sensor de orientación requerido.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reintentar sensor'));
    await tester.pump();
    expect(harness.orientation.listens, 2);
  });

  for (final androidBack in [false, true]) {
    testWidgets(
      'salir libera sensor inmediatamente, AndroidBack=$androidBack',
      (tester) async {
        usePhoneScreen(tester);
        final harness = ObservatoryHarness();
        await harness.open(tester);
        if (androidBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byTooltip('Volver al menú'));
        }
        await tester.pump();
        expect(harness.orientation.cancels, 1);
        await tester.pumpAndSettle();
        expect(find.text('VESTIGIA'), findsOneWidget);
        await tester.tap(find.text('Observatorio'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(gameOf(tester).phase, ObservatoryPhase.coordinates);
        expect(harness.orientation.listens, 2);
      },
    );
  }

  testWidgets('teléfono pequeño y texto grande sin desbordes', (tester) async {
    usePhoneScreen(tester);
    tester.view.physicalSize = const Size(960, 1920);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = ObservatoryHarness();
    await harness.open(tester);
    await harness.snapshot(tester, 'observatorio-320-registros');
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(ObservatoryScreen.prepareKey));
    await harness.calibrate(tester);
    expect(tester.takeException(), isNull);
    await harness.hold(tester, 21);
    expect(gameOf(tester).phase, ObservatoryPhase.solved);
    await harness.snapshot(tester, 'observatorio-320-magnetar');
    expect(tester.takeException(), isNull);
  });
}
