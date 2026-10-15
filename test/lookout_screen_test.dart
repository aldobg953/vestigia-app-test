import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_coordenadas/app/vestigia_app.dart';
import 'package:radio_coordenadas/core/haptics.dart';
import 'package:radio_coordenadas/menu/puzzle_entry.dart';
import 'package:radio_coordenadas/puzzles/lookout/lookout_config.dart';
import 'package:radio_coordenadas/puzzles/lookout/lookout_game.dart';
import 'package:radio_coordenadas/puzzles/lookout/lookout_screen.dart';
import 'package:radio_coordenadas/puzzles/lookout/widgets/lens_view.dart';

import 'support/fakes.dart';
import 'support/visual_verification.dart';

const config = LookoutConfig();

class LookoutHarness {
  final haptics = FakeHaptics();
  final boundary = GlobalKey();

  Widget app() => RepaintBoundary(
    key: boundary,
    child: VestigiaApp(
      puzzles: [
        PuzzleEntry(
          id: 'lookout',
          title: 'Mirador del faro',
          description: 'Prueba',
          icon: Icons.visibility,
          builder: (_) => LookoutScreen(hapticsFactory: () => haptics),
        ),
      ],
    ),
  );

  int count(HapticCue cue) => haptics.cues.where((c) => c == cue).length;
}

Future<void> openLookout(WidgetTester tester) async {
  await tester.tap(find.text('Mirador del faro'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byType(LookoutScreen), findsOneWidget);
}

LookoutGame gameOf(WidgetTester tester) =>
    tester.state<LookoutScreenState>(find.byType(LookoutScreen)).game;

String statusText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(LookoutScreen.statusKey)).data!;

String debugText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(LookoutScreen.debugKey)).data!;

/// Frota el lente en zigzag con un dedo, hasta la fila [untilY] (0..1).
Future<void> wipeLens(WidgetTester tester, {double untilY = 0.97}) async {
  final glass = tester
      .getRect(find.byKey(LookoutScreen.lensKey))
      .deflate(LensView.rimWidth);
  Offset at(double x, double y) =>
      glass.topLeft + Offset(x * glass.width, y * glass.height);

  var y = 0.03;
  var x = 0.0;
  final gesture = await tester.startGesture(at(x, y));
  Future<void> moveTo(double nx, double ny) async {
    const steps = 8;
    final from = Offset(x, y);
    for (var i = 1; i <= steps; i++) {
      final p = Offset.lerp(from, Offset(nx, ny), i / steps)!;
      await gesture.moveTo(at(p.dx, p.dy));
    }
    x = nx;
    y = ny;
  }

  while (y <= untilY) {
    await moveTo(x == 0 ? 1 : 0, y);
    if (y + 0.08 <= untilY) await moveTo(x, y + 0.08);
    if (y + 0.08 > untilY) break;
  }
  await gesture.up();
  await tester.pump();
}

/// Radianes de perilla para cambiar un eje en [delta] unidades.
double turnFor(double delta, AxisRange range) =>
    delta / range.span * config.knobTurnsForFullRange * 2 * pi;

Future<void> cleanLens(WidgetTester tester) async {
  await wipeLens(tester);
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVerificationFonts);
  testWidgets('el menú incluye el mirador y empieza en la limpieza', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const VestigiaApp());
    expect(find.text('Mirador del faro'), findsOneWidget);

    await openLookout(tester);
    expect(gameOf(tester).phase, LookoutPhase.cleaning);
    expect(
      statusText(tester),
      'Desliza los dedos sobre el lente para limpiarlo',
    );
    expect(find.byKey(LookoutScreen.xKnobKey), findsNothing);
    expect(find.byKey(LookoutScreen.yKnobKey), findsNothing);
    expect(debugText(tester), 'X: 0.0    Y: 0.0');
    expect(find.text('Lente limpio: 0 %'), findsOneWidget);
  });

  testWidgets('frotar limpia zonas nuevas; repetir no suma', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(LookoutHarness().app());
    await openLookout(tester);

    await wipeLens(tester, untilY: 0.4);
    final game = gameOf(tester);
    final progress = game.lens.progress;
    expect(progress, greaterThan(0.2));
    expect(progress, lessThan(config.cleanThreshold));
    expect(
      find.text('Lente limpio: ${(progress * 100).floor()} %'),
      findsOneWidget,
    );

    // El mismo recorrido otra vez no cuenta como zona nueva.
    await wipeLens(tester, untilY: 0.4);
    expect(game.lens.progress, progress);
    expect(game.phase, LookoutPhase.cleaning);
  });

  testWidgets('al limpiar el lente pasa sola a las perillas', (tester) async {
    usePhoneScreen(tester);
    final harness = LookoutHarness();
    await tester.pumpWidget(harness.app());
    await openLookout(tester);

    await cleanLens(tester);
    expect(gameOf(tester).phase, LookoutPhase.orienting);
    expect(harness.count(HapticCue.capture), 1);
    expect(statusText(tester), 'Gira las perillas para orientar la vista');
    expect(find.byKey(LookoutScreen.xKnobKey), findsOneWidget);
    expect(find.byKey(LookoutScreen.yKnobKey), findsOneWidget);

    // Frotar ya no hace nada.
    await wipeLens(tester, untilY: 0.2);
    expect(harness.count(HapticCue.capture), 1);
  });

  testWidgets('cada perilla mueve solo su eje, con límites', (tester) async {
    usePhoneScreen(tester);
    final harness = LookoutHarness();
    await tester.pumpWidget(harness.app());
    await openLookout(tester);
    await cleanLens(tester);
    final view = gameOf(tester).view;

    await rotateKnob(
      tester,
      turnFor(30, config.xRange),
      knob: find.byKey(LookoutScreen.xKnobKey),
    );
    expect(view.x, closeTo(30, 1e-6));
    expect(view.y, 0);
    expect(debugText(tester), 'X: 30.0    Y: 0.0');
    expect(harness.count(HapticCue.tick), greaterThan(0));

    await rotateKnob(
      tester,
      turnFor(-45, config.yRange),
      knob: find.byKey(LookoutScreen.yKnobKey),
    );
    expect(view.y, closeTo(-45, 1e-6));
    expect(view.x, closeTo(30, 1e-6));
    expect(debugText(tester), 'X: 30.0    Y: -45.0');

    // Más allá del tope, el eje se queda en su límite.
    await rotateKnob(
      tester,
      turnFor(300, config.xRange),
      knob: find.byKey(LookoutScreen.xKnobKey),
    );
    expect(view.x, config.xRange.max);
    expect(debugText(tester), 'X: 100.0    Y: -45.0');
    expect(harness.count(HapticCue.limit), greaterThan(0));
  });

  testWidgets('alinear ambos ejes confirma una sola vez', (tester) async {
    usePhoneScreen(tester);
    final harness = LookoutHarness();
    await tester.pumpWidget(harness.app());
    await openLookout(tester);
    await cleanLens(tester);
    final game = gameOf(tester);

    await rotateKnob(
      tester,
      turnFor(game.view.targetX, config.xRange),
      knob: find.byKey(LookoutScreen.xKnobKey),
    );
    expect(game.phase, LookoutPhase.orienting);
    await rotateKnob(
      tester,
      turnFor(game.view.targetY, config.yRange),
      knob: find.byKey(LookoutScreen.yKnobKey),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(game.phase, LookoutPhase.observing);
    expect(statusText(tester), 'Una luz entre las nubes…');
    expect(harness.count(HapticCue.signalFound), 1);
    await tester.pump(const Duration(milliseconds: 240));
    await captureScreen(
      tester,
      find.byKey(harness.boundary),
      'mirador-resplandor',
    );
    await tester.pump(const Duration(milliseconds: 1040));
    await captureScreen(
      tester,
      find.byKey(harness.boundary),
      'mirador-receptores',
    );

    // Las perillas quedan bloqueadas: girarlas no cambia nada ni repite.
    await rotateKnob(tester, 1.0, knob: find.byKey(LookoutScreen.xKnobKey));
    expect(game.view.isAligned, isTrue);
    expect(harness.count(HapticCue.signalFound), 1);
    await pumpFrames(tester, const Duration(seconds: 4));
    expect(game.phase, LookoutPhase.solved);
    expect(statusText(tester), 'El faro y el Observatorio responden');
  });

  testWidgets('evento se pausa en segundo plano y reinicio lo cancela', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final harness = LookoutHarness();
    await tester.pumpWidget(harness.app());
    await openLookout(tester);
    await cleanLens(tester);
    final game = gameOf(tester);
    await rotateKnob(
      tester,
      turnFor(game.view.targetX, config.xRange),
      knob: find.byKey(LookoutScreen.xKnobKey),
    );
    await rotateKnob(
      tester,
      turnFor(game.view.targetY, config.yRange),
      knob: find.byKey(LookoutScreen.yKnobKey),
    );
    await tester.pump(const Duration(milliseconds: 600));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await pumpFrames(tester, const Duration(seconds: 5));
    expect(game.phase, LookoutPhase.observing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpFrames(tester, const Duration(seconds: 4));
    expect(game.phase, LookoutPhase.solved);
    expect(harness.count(HapticCue.signalFound), 1);
    await tester.tap(find.byKey(LookoutScreen.restartKey));
    await tester.pump();
    await cleanLens(tester);
    await rotateKnob(
      tester,
      turnFor(game.view.targetX, config.xRange),
      knob: find.byKey(LookoutScreen.xKnobKey),
    );
    await rotateKnob(
      tester,
      turnFor(game.view.targetY, config.yRange),
      knob: find.byKey(LookoutScreen.yKnobKey),
    );
    expect(game.phase, LookoutPhase.observing);
    await tester.tap(find.byKey(LookoutScreen.restartKey));
    await pumpFrames(tester, const Duration(seconds: 5));
    expect(game.phase, LookoutPhase.cleaning);
  });

  testWidgets(
    'reiniciar vuelve a la suciedad, los ejes iniciales y la fase 1',
    (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(LookoutHarness().app());
      await openLookout(tester);
      await cleanLens(tester);
      await rotateKnob(
        tester,
        turnFor(20, config.xRange),
        knob: find.byKey(LookoutScreen.xKnobKey),
      );

      await tester.tap(find.byKey(LookoutScreen.restartKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final game = gameOf(tester);
      expect(game.phase, LookoutPhase.cleaning);
      expect(game.lens.progress, 0);
      expect(debugText(tester), 'X: 0.0    Y: 0.0');
      expect(find.byKey(LookoutScreen.xKnobKey), findsNothing);
      expect(
        statusText(tester),
        'Desliza los dedos sobre el lente para limpiarlo',
      );
    },
  );

  testWidgets('volver al menú y Atrás de Android; cada entrada es nueva', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(LookoutHarness().app());
    await openLookout(tester);
    await wipeLens(tester, untilY: 0.4);
    expect(gameOf(tester).lens.progress, greaterThan(0));

    await tester.tap(find.byTooltip('Volver al menú'));
    await tester.pumpAndSettle();
    expect(find.text('VESTIGIA'), findsOneWidget);

    await openLookout(tester);
    expect(gameOf(tester).lens.progress, 0);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('VESTIGIA'), findsOneWidget);
  });

  testWidgets('los valores X e Y se pueden ocultar', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: LookoutScreen(
          config: const LookoutConfig(showDebugValues: false),
          hapticsFactory: () => FakeHaptics(),
        ),
      ),
    );
    expect(find.byKey(LookoutScreen.debugKey), findsNothing);
  });
}
