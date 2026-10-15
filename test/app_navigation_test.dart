import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_coordenadas/app/vestigia_app.dart';
import 'package:radio_coordenadas/core/haptics.dart';
import 'package:radio_coordenadas/menu/puzzle_entry.dart';
import 'package:radio_coordenadas/puzzles/radio/radio_audio.dart';
import 'package:radio_coordenadas/puzzles/radio/radio_puzzle_screen.dart';

import 'support/fakes.dart';

/// App con el puzzle de radio conectado a audios falsos; guarda uno por
/// cada vez que se abre la pantalla.
class RadioHarness {
  final audios = <FakeRadioAudio>[];
  final haptics = FakeHaptics();

  Widget app() => VestigiaApp(
    puzzles: [
      PuzzleEntry(
        id: 'radio',
        title: 'Radio',
        description: 'Prueba',
        icon: Icons.radio,
        builder: (_) => RadioPuzzleScreen(
          audioFactory: () {
            final audio = FakeRadioAudio();
            audios.add(audio);
            return audio;
          },
          hapticsFactory: () => haptics,
          planner: (_) => const [0.2, 0.8, 0.35],
        ),
      ),
    ],
  );
}

Future<void> openRadio(WidgetTester tester) async {
  await tester.tap(find.text('Radio'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byKey(RadioPuzzleScreen.knobKey), findsOneWidget);
}

void main() {
  testWidgets('el menú muestra Vestigia y el puzzle de radio', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const VestigiaApp());

    expect(find.text('VESTIGIA'), findsOneWidget);
    expect(find.text('Radio'), findsOneWidget);
    expect(find.byIcon(Icons.radio), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
    await tester.scrollUntilVisible(find.text('Observatorio'), 100);
    expect(find.text('Observatorio'), findsOneWidget);
  });

  testWidgets('abre el puzzle desde el menú y empieza el ruido', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final harness = RadioHarness();
    await tester.pumpWidget(harness.app());
    await openRadio(tester);

    expect(harness.audios, hasLength(1));
    expect(harness.audios.single.playing, isTrue);
    expect(harness.audios.single.strength, lessThan(1));
    expect(find.text('VESTIGIA'), findsNothing);
  });

  testWidgets('el botón de regreso vuelve al menú y detiene el sonido', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final harness = RadioHarness();
    await tester.pumpWidget(harness.app());
    await openRadio(tester);

    await tester.tap(find.byTooltip('Volver al menú'));
    await tester.pump();
    // Se detiene al salir, sin esperar a que termine la transición.
    expect(harness.audios.single.disposed, isTrue);

    await tester.pumpAndSettle();
    expect(find.text('VESTIGIA'), findsOneWidget);
    expect(find.byKey(RadioPuzzleScreen.knobKey), findsNothing);
  });

  testWidgets('el botón Atrás de Android vuelve al menú y detiene el sonido', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final harness = RadioHarness();
    await tester.pumpWidget(harness.app());
    await openRadio(tester);

    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await tester.pump();
    expect(harness.audios.single.disposed, isTrue);

    await tester.pumpAndSettle();
    expect(find.text('VESTIGIA'), findsOneWidget);
  });

  testWidgets('volver a entrar empieza una partida nueva', (tester) async {
    usePhoneScreen(tester);
    final harness = RadioHarness();
    await tester.pumpWidget(harness.app());
    await openRadio(tester);

    // Capta el primer dígito.
    await rotateKnob(tester, -0.3 * 3 * 3.141592653589793);
    await pumpFrames(tester, const Duration(milliseconds: 2100));
    expect(
      find.descendant(
        of: find.byKey(const Key('digit-slot-0')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await openRadio(tester);

    expect(harness.audios, hasLength(2));
    expect(harness.audios.first.disposed, isTrue);
    expect(harness.audios.last.playing, isTrue);
    expect(
      find.descendant(
        of: find.byKey(const Key('digit-slot-0')),
        matching: find.text('–'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('el catálogo real usa los canales nativos y los detiene', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final audioCalls = <String>[];
    final hapticCalls = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(PlatformRadioAudio.defaultChannel, (
      call,
    ) async {
      audioCalls.add(call.method);
      return null;
    });
    messenger.setMockMethodCallHandler(PlatformHaptics.defaultChannel, (
      MethodCall call,
    ) async {
      hapticCalls.add(call.arguments['cue'] as String);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(
        PlatformRadioAudio.defaultChannel,
        null,
      );
      messenger.setMockMethodCallHandler(PlatformHaptics.defaultChannel, null);
    });

    await tester.pumpWidget(const VestigiaApp());
    await openRadio(tester);
    expect(audioCalls.first, 'start');

    await rotateKnob(tester, 0.5);
    expect(hapticCalls, contains('tick'));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(audioCalls.last, 'stop');
    expect(audioCalls.where((m) => m == 'stop'), hasLength(1));
  });
}
