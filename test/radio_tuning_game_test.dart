import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:radio_coordenadas/puzzles/radio/radio_config.dart';
import 'package:radio_coordenadas/puzzles/radio/radio_tuning_game.dart';

const config = RadioPuzzleConfig();
const fixedSignals = [0.2, 0.8, 0.35];

RadioTuningGame fixedGame() =>
    RadioTuningGame(config: config, planner: (_) => fixedSignals);

/// Avanza [total] en pasos de [step] (como lo haría el reloj de la pantalla)
/// y devuelve las capturas producidas.
List<DigitCapture> advanceFor(
  RadioTuningGame game,
  Duration total, {
  Duration step = const Duration(milliseconds: 16),
}) {
  final captures = <DigitCapture>[];
  var remaining = total;
  while (remaining > Duration.zero) {
    final dt = remaining < step ? remaining : step;
    remaining -= dt;
    final capture = game.advance(dt);
    if (capture != null) captures.add(capture);
  }
  return captures;
}

void main() {
  group('generación de señales', () {
    test('respeta márgenes, separación y distancia al inicio', () {
      for (var seed = 0; seed < 200; seed++) {
        final positions = generateSignalPositions(config, Random(seed), 0.5);
        expect(positions, hasLength(3));
        for (final p in positions) {
          expect(p, inInclusiveRange(config.edgeMargin, 1 - config.edgeMargin));
          expect(
            (p - 0.5).abs(),
            greaterThanOrEqualTo(config.minDistanceFromStart),
          );
        }
        for (var i = 0; i < positions.length; i++) {
          for (var j = i + 1; j < positions.length; j++) {
            expect(
              (positions[i] - positions[j]).abs(),
              greaterThanOrEqualTo(config.minSignalSeparation),
            );
          }
        }
      }
    });

    test('la partida empieza fuera de la franja y con ruido', () {
      for (var seed = 0; seed < 50; seed++) {
        final game = RadioTuningGame(config: config, random: Random(seed));
        expect(game.isInBand, isFalse);
        expect(game.signalStrength, lessThan(1));
      }
    });

    test('las posiciones se generan una vez y se conservan', () {
      var calls = 0;
      final game = RadioTuningGame(
        config: config,
        planner: (_) {
          calls++;
          return fixedSignals;
        },
      );
      for (var i = 0; i < 100; i++) {
        game.setDial(i / 100);
        game.advance(const Duration(milliseconds: 16));
      }
      expect(calls, 1);
      expect(game.signalPositions, fixedSignals);
    });

    test('reiniciar genera posiciones nuevas', () {
      final game = RadioTuningGame(config: config, random: Random(7));
      final first = game.signalPositions;
      game.restart();
      expect(game.signalPositions, isNot(equals(first)));
    });
  });

  group('intensidad de la señal', () {
    test('tiene un pico solo en el centro y cae sin mesetas', () {
      expect(RadioTuningGame.strengthAt(0.2, 0.2, config), 1);
      expect(RadioTuningGame.strengthAt(0.8, 0.2, config), 0);

      // Cada paso hacia el centro sube la intensidad, también dentro de la
      // franja: no hay zona plana que “imante” la aguja.
      final reach = config.bandHalfWidth + config.audibleRange;
      var previous = -1.0;
      for (var i = 0; i <= 200; i++) {
        final d = reach * (1 - i / 200);
        final s = RadioTuningGame.strengthAt(0.2 + d, 0.2, config);
        if (d < reach) expect(s, greaterThan(previous));
        previous = s;
      }
      expect(RadioTuningGame.strengthAt(0.21, 0.2, config), lessThan(1));
    });

    test('no hay salto en el borde de la franja', () {
      final edge = 0.2 + config.bandHalfWidth;
      final inside = RadioTuningGame.strengthAt(edge - 1e-6, 0.2, config);
      final outside = RadioTuningGame.strengthAt(edge + 1e-6, 0.2, config);
      expect((inside - outside).abs(), lessThan(1e-4));
    });

    test('el dial queda limitado a la escala', () {
      final game = fixedGame();
      game.setDial(-0.3);
      expect(game.dial, 0);
      game.setDial(1.7);
      expect(game.dial, 1);
    });
  });

  group('captura', () {
    test('en el centro requiere dos segundos continuos', () {
      final game = fixedGame()..setDial(0.2);
      expect(game.isInBand, isTrue);

      expect(
        advanceFor(
          game,
          const Duration(milliseconds: 1999),
          step: const Duration(milliseconds: 1),
        ),
        isEmpty,
      );
      expect(game.capturedDigits, isEmpty);
      expect(game.holdProgress, closeTo(0.9995, 1e-6));

      final capture = game.advance(const Duration(milliseconds: 1));
      expect(capture, isNotNull);
      expect(capture!.index, 0);
      expect(capture.digit, config.digits[0]);
      expect(capture.completesPuzzle, isFalse);
      expect(game.capturedDigits, [config.digits[0]]);
    });

    test('fuera de la franja el tiempo no cuenta', () {
      final game = fixedGame()..setDial(0.5);
      expect(advanceFor(game, const Duration(seconds: 10)), isEmpty);
      expect(game.holdTime, Duration.zero);
    });

    test('salir de la franja reinicia la espera', () {
      final game = fixedGame()..setDial(0.2);
      advanceFor(game, const Duration(milliseconds: 1500));
      expect(game.holdTime, greaterThan(Duration.zero));

      game.setDial(0.3); // Fuera de la franja.
      expect(game.holdTime, Duration.zero);
      game.setDial(0.2);

      expect(advanceFor(game, const Duration(milliseconds: 1500)), isEmpty);
      expect(game.capturedDigits, isEmpty);
      expect(advanceFor(game, const Duration(milliseconds: 600)), hasLength(1));
    });

    test('moverse dentro de la franja no reinicia la espera', () {
      final game = fixedGame()..setDial(0.2);
      advanceFor(game, const Duration(seconds: 1));
      game.setDial(0.222); // Cerca del borde: sigue dentro.
      expect(game.isInBand, isTrue);
      expect(game.holdTime, const Duration(seconds: 1));
      game.setDial(0.203); // De vuelta a la zona central.
      expect(
        advanceFor(game, const Duration(milliseconds: 1010)),
        hasLength(1),
      );
    });

    test('la velocidad de captura baja al alejarse del centro', () {
      final half = config.bandHalfWidth;
      // Señal en 0 para que el desplazamiento no arrastre error de redondeo.
      double rate(double offset) =>
          RadioTuningGame.captureRateAt(offset, 0, config);

      expect(rate(0), 1);
      expect(rate(half * config.centerZone * 0.99), 1);
      expect(rate(-half * config.centerZone * 0.99), 1);
      expect(rate(half), closeTo(config.edgeCaptureRate, 1e-9));
      expect(rate(half * 1.01), 0);

      var previous = 2.0;
      for (var i = 0; i <= 20; i++) {
        final r = rate(
          half * (config.centerZone + (1 - config.centerZone) * i / 20),
        );
        expect(r, lessThan(previous));
        previous = r;
      }
    });

    test('lejos del centro tarda más en captar', () {
      // A 80 % del borde: velocidad 1 - 0.75 × 0.75 = 0.4375 → ~4.57 s.
      final game = fixedGame()..setDial(0.2 + config.bandHalfWidth * 0.8);
      expect(game.captureRate, closeTo(0.4375, 1e-9));
      expect(advanceFor(game, const Duration(milliseconds: 4500)), isEmpty);
      expect(game.holdProgress, closeTo(4.5 * 0.4375 / 2, 0.01));
      expect(advanceFor(game, const Duration(milliseconds: 100)), hasLength(1));
    });

    test('junto al borde tarda unos ocho segundos', () {
      // Velocidad ≈ 0.251 → 2 s / 0.251 ≈ 7.97 s.
      final game = fixedGame()..setDial(0.2 - config.bandHalfWidth * 0.999);
      expect(advanceFor(game, const Duration(milliseconds: 7950)), isEmpty);
      expect(advanceFor(game, const Duration(milliseconds: 100)), hasLength(1));
    });

    test('cancelar la espera (app al fondo) descarta el progreso', () {
      final game = fixedGame()..setDial(0.2);
      advanceFor(game, const Duration(milliseconds: 1900));
      game.cancelHold();
      expect(game.holdProgress, 0);
      expect(advanceFor(game, const Duration(milliseconds: 1900)), isEmpty);
    });

    test('cada dígito se capta una sola vez', () {
      final game = fixedGame()..setDial(0.2);
      expect(advanceFor(game, const Duration(seconds: 2)), hasLength(1));
      // La siguiente señal está en otra posición: quedarse aquí no capta más.
      expect(game.activeSignal, fixedSignals[1]);
      expect(game.isInBand, isFalse);
      expect(advanceFor(game, const Duration(seconds: 10)), isEmpty);
      expect(game.capturedDigits, [config.digits[0]]);
    });

    test('termina tras tres capturas y conserva los dígitos', () {
      final game = fixedGame();
      final captures = <DigitCapture>[];
      for (final signal in fixedSignals) {
        game.setDial(signal);
        captures.addAll(advanceFor(game, const Duration(milliseconds: 2050)));
      }
      expect(captures.map((c) => c.index), [0, 1, 2]);
      expect(captures.map((c) => c.completesPuzzle), [false, false, true]);
      expect(game.isComplete, isTrue);
      expect(game.capturedDigits, config.digits);
      expect(game.activeSignal, isNull);
      expect(game.displayedSignal, fixedSignals.last);
      expect(game.signalStrength, 1);
      expect(game.captureRate, 0);

      // Nada más que captar.
      expect(advanceFor(game, const Duration(seconds: 5)), isEmpty);
      expect(game.capturedDigits, hasLength(3));
    });

    test('reiniciar borra los dígitos y la espera', () {
      final game = fixedGame()..setDial(0.2);
      advanceFor(game, const Duration(seconds: 2));
      game.setDial(0.8);
      advanceFor(game, const Duration(seconds: 1));
      game.restart();
      expect(game.capturedDigits, isEmpty);
      expect(game.round, 0);
      expect(game.holdTime, Duration.zero);
      expect(game.isComplete, isFalse);
    });

    test('los dígitos son configurables', () {
      final game = RadioTuningGame(
        config: const RadioPuzzleConfig(digits: [9, 0, 1]),
        planner: (_) => fixedSignals,
      );
      for (final signal in fixedSignals) {
        game.setDial(signal);
        advanceFor(game, const Duration(milliseconds: 2050));
      }
      expect(game.capturedDigits, [9, 0, 1]);
    });
  });
}
