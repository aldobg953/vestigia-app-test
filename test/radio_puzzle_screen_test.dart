import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_coordenadas/app/vestigia_app.dart';
import 'package:radio_coordenadas/core/haptics.dart';
import 'package:radio_coordenadas/menu/puzzle_entry.dart';
import 'package:radio_coordenadas/puzzles/radio/radio_config.dart';
import 'package:radio_coordenadas/puzzles/radio/radio_puzzle_screen.dart';

import 'support/fakes.dart';

const signals = [0.2, 0.8, 0.35];
const config = RadioPuzzleConfig();

/// Radianes que hay que girar la perilla para mover el dial [amount].
double turn(double amount) => amount * config.knobTurnsForFullScale * 2 * pi;

class Puzzle {
  final audio = FakeRadioAudio();
  final haptics = FakeHaptics();
  var plans = 0;

  Future<void> open(WidgetTester tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(
      VestigiaApp(
        puzzles: [
          PuzzleEntry(
            id: 'radio',
            title: 'Radio',
            description: 'Prueba',
            icon: Icons.radio,
            builder: (_) => RadioPuzzleScreen(
              audioFactory: () => audio,
              hapticsFactory: () => haptics,
              planner: (_) {
                plans++;
                return signals;
              },
            ),
          ),
        ],
      ),
    );
    await tester.tap(find.text('Radio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Finder digitSlot(int index, String text) => find.descendant(
  of: find.byKey(Key('digit-slot-$index')),
  matching: find.text(text),
);

String statusText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(RadioPuzzleScreen.statusKey)).data!;

void main() {
  testWidgets('empieza con ruido y sin dígitos', (tester) async {
    final puzzle = Puzzle();
    await puzzle.open(tester);

    expect(puzzle.audio.calls.first, 'start');
    expect(puzzle.audio.strength, 0);
    expect(statusText(tester), 'Gira la perilla y escucha');
    expect(find.text('Señal 1 de 3'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(digitSlot(i, '–'), findsOneWidget);
    }
  });

  testWidgets('girar la perilla vibra y acercarse limpia la señal', (
    tester,
  ) async {
    final puzzle = Puzzle();
    await puzzle.open(tester);

    await rotateKnob(tester, turn(-0.15)); // Dial en 0.35, cerca de 0.2.
    expect(puzzle.haptics.cues, contains(HapticCue.tick));
    expect(puzzle.haptics.cues, isNot(contains(HapticCue.signalFound)));
    final near = puzzle.audio.strength!;
    expect(near, greaterThan(0));
    expect(near, lessThan(1));

    await rotateKnob(tester, turn(-0.15)); // Dial en 0.2: dentro de la franja.
    await tester.pump(const Duration(milliseconds: 16));
    expect(puzzle.audio.strength, closeTo(1, 1e-6));
    expect(puzzle.haptics.cues, contains(HapticCue.signalFound));
    // El texto no delata la señal.
    expect(statusText(tester), 'Gira la perilla y escucha');
  });

  testWidgets('rozar el borde de la franja no repite la vibración', (
    tester,
  ) async {
    final puzzle = Puzzle();
    await puzzle.open(tester);
    int found() =>
        puzzle.haptics.cues.where((c) => c == HapticCue.signalFound).length;

    await rotateKnob(tester, turn(-0.3)); // Centro de la señal.
    expect(found(), 1);

    // Entrar y salir rozando el borde (fuera por 0.005) no vuelve a vibrar.
    for (var i = 0; i < 3; i++) {
      await rotateKnob(tester, turn(0.03));
      await rotateKnob(tester, turn(-0.03));
    }
    expect(found(), 1);

    // Alejarse claramente y volver sí la anuncia de nuevo.
    await rotateKnob(tester, turn(0.1));
    await rotateKnob(tester, turn(-0.1));
    expect(found(), 2);
  });

  testWidgets('capta el dígito tras dos segundos continuos', (tester) async {
    final puzzle = Puzzle();
    await puzzle.open(tester);

    await rotateKnob(tester, turn(-0.3));
    await pumpFrames(tester, const Duration(milliseconds: 1900));
    expect(digitSlot(0, '–'), findsOneWidget);
    expect(puzzle.haptics.cues, isNot(contains(HapticCue.capture)));

    await pumpFrames(tester, const Duration(milliseconds: 200));
    expect(digitSlot(0, '1'), findsOneWidget);
    expect(
      puzzle.haptics.cues.where((c) => c == HapticCue.capture),
      hasLength(1),
    );
    expect(find.text('Señal 2 de 3'), findsOneWidget);

    // Quedarse en la misma posición no vuelve a captar.
    await pumpFrames(tester, const Duration(seconds: 3));
    expect(digitSlot(1, '–'), findsOneWidget);
  });

  testWidgets('salir de la franja reinicia la espera', (tester) async {
    final puzzle = Puzzle();
    await puzzle.open(tester);

    await rotateKnob(tester, turn(-0.3));
    await pumpFrames(tester, const Duration(milliseconds: 1500));
    await rotateKnob(tester, turn(0.1)); // Fuera de la franja.
    await pumpFrames(tester, const Duration(milliseconds: 200));
    await rotateKnob(tester, turn(-0.1)); // De vuelta.

    await pumpFrames(tester, const Duration(milliseconds: 1500));
    expect(digitSlot(0, '–'), findsOneWidget);
    await pumpFrames(tester, const Duration(milliseconds: 600));
    expect(digitSlot(0, '1'), findsOneWidget);
  });

  testWidgets('pasar la app al fondo pausa el audio y la espera', (
    tester,
  ) async {
    final puzzle = Puzzle();
    await puzzle.open(tester);

    await rotateKnob(tester, turn(-0.3));
    await pumpFrames(tester, const Duration(milliseconds: 1500));

    final binding = tester.binding;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(puzzle.audio.paused, isTrue);
    expect(statusText(tester), 'En pausa');

    // El tiempo en segundo plano no cuenta.
    await pumpFrames(tester, const Duration(seconds: 3));
    expect(digitSlot(0, '–'), findsOneWidget);

    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(puzzle.audio.paused, isFalse);
    expect(puzzle.audio.calls, containsAllInOrder(['pause', 'resume']));

    // La espera incompleta se descartó: hacen falta dos segundos nuevos.
    await pumpFrames(tester, const Duration(milliseconds: 1500));
    expect(digitSlot(0, '–'), findsOneWidget);
    await pumpFrames(tester, const Duration(milliseconds: 600));
    expect(digitSlot(0, '1'), findsOneWidget);
  });

  testWidgets('tres capturas completan la coordenada y se puede repetir', (
    tester,
  ) async {
    final puzzle = Puzzle();
    await puzzle.open(tester);

    var dial = config.initialDial;
    for (final signal in signals) {
      await rotateKnob(tester, turn(signal - dial));
      dial = signal;
      await pumpFrames(tester, const Duration(milliseconds: 2100));
    }

    expect(find.text('137'), findsOneWidget);
    expect(statusText(tester), 'Mensaje completo');
    expect(find.byKey(RadioPuzzleScreen.knobKey), findsNothing);
    expect(puzzle.haptics.cues.last, HapticCue.complete);
    expect(
      puzzle.haptics.cues.where((c) => c == HapticCue.capture),
      hasLength(2),
    );
    expect(find.text('Repetir'), findsOneWidget);
    expect(find.text('Volver al menú'), findsOneWidget);

    await tester.tap(find.text('Repetir'));
    await pumpFrames(tester, const Duration(milliseconds: 400));
    expect(puzzle.plans, 2);
    expect(find.byKey(RadioPuzzleScreen.knobKey), findsOneWidget);
    expect(find.text('Señal 1 de 3'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(digitSlot(i, '–'), findsOneWidget);
    }
    expect(puzzle.audio.disposed, isFalse);
  });

  testWidgets('al completar se puede volver al menú', (tester) async {
    final puzzle = Puzzle();
    await puzzle.open(tester);

    var dial = config.initialDial;
    for (final signal in signals) {
      await rotateKnob(tester, turn(signal - dial));
      dial = signal;
      await pumpFrames(tester, const Duration(milliseconds: 2100));
    }

    await tester.tap(find.text('Volver al menú'));
    await tester.pump();
    expect(puzzle.audio.disposed, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('VESTIGIA'), findsOneWidget);
  });

  testWidgets('la perilla se detiene en los topes', (tester) async {
    final puzzle = Puzzle();
    await puzzle.open(tester);

    await rotateKnob(tester, turn(0.8)); // Más allá del final de la escala.
    expect(find.text('${config.maxFrequencyKhz.round()} kHz'), findsOneWidget);
    expect(puzzle.haptics.cues, contains(HapticCue.limit));

    // Al girar de vuelta responde de inmediato, sin zona muerta.
    await rotateKnob(tester, turn(-0.1));
    final expected = config.frequencyAt(0.9).round();
    expect(find.text('$expected kHz'), findsOneWidget);
  });
}
