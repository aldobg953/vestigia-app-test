import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_coordenadas/core/haptics.dart';
import 'package:radio_coordenadas/puzzles/radio/radio_audio.dart';
import 'package:radio_coordenadas/puzzles/radio/radio_puzzle_screen.dart';

class FakeRadioAudio implements RadioAudio {
  final calls = <String>[];
  double? strength;
  bool started = false;
  bool paused = false;
  bool disposed = false;

  bool get playing => started && !paused && !disposed;

  @override
  void start(double signalStrength) {
    calls.add('start');
    started = true;
    strength = signalStrength;
  }

  @override
  void setSignalStrength(double value) {
    expect(disposed, isFalse, reason: 'audio usado después de liberarse');
    strength = value;
  }

  @override
  void pause() {
    calls.add('pause');
    paused = true;
  }

  @override
  void resume() {
    calls.add('resume');
    paused = false;
  }

  @override
  void dispose() {
    calls.add('dispose');
    disposed = true;
  }
}

class FakeHaptics implements Haptics {
  final cues = <HapticCue>[];

  @override
  void play(HapticCue cue) => cues.add(cue);
}

/// Pantalla de teléfono vertical (360 × 800 lógicos).
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Avanza el reloj en fotogramas cortos, como en un dispositivo.
Future<void> pumpFrames(
  WidgetTester tester,
  Duration total, {
  Duration step = const Duration(milliseconds: 50),
}) async {
  var remaining = total;
  while (remaining > Duration.zero) {
    final dt = remaining < step ? remaining : step;
    remaining -= dt;
    await tester.pump(dt);
  }
}

/// Gira la perilla con un arrastre circular desde la parte superior.
/// Un ángulo positivo gira en sentido horario (sube la frecuencia).
Future<void> rotateKnob(
  WidgetTester tester,
  double radians, {
  Finder? knob,
}) async {
  knob ??= find.byKey(RadioPuzzleScreen.knobKey);
  final center = tester.getCenter(knob);
  final radius = tester.getSize(knob).shortestSide * 0.35;
  Offset at(double angle) => center + Offset(cos(angle), sin(angle)) * radius;

  const start = -pi / 2;
  final gesture = await tester.startGesture(at(start));
  const step = 0.05;
  final steps = (radians.abs() / step).ceil();
  for (var i = 1; i <= steps; i++) {
    final angle = start + radians * i / steps;
    await gesture.moveTo(at(angle));
  }
  await gesture.up();
  await tester.pump();
}
