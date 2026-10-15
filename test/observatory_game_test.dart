import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:radio_coordenadas/core/celestial_target.dart';
import 'package:radio_coordenadas/puzzles/lookout/widgets/observation_view.dart';
import 'package:radio_coordenadas/puzzles/observatory/observatory_game.dart';
import 'package:radio_coordenadas/puzzles/observatory/orientation_source.dart';
import 'package:radio_coordenadas/puzzles/observatory/widgets/sky_view.dart';

const ms100 = Duration(milliseconds: 100);

ObservatoryGame calibrated({double heading = 200}) {
  final game = ObservatoryGame();
  expect(game.submitCodes('137', '+042'), isTrue);
  game.receive(PointingSample(heading, 0), Duration.zero);
  expect(game.calibrate(Duration.zero), isTrue);
  return game;
}

bool hold(
  ObservatoryGame game,
  int frames, {
  int start = 0,
  double azimuth = 200,
  double altitude = 68,
}) {
  var solved = false;
  for (var i = start + 1; i <= start + frames; i++) {
    final now = ms100 * i;
    game.receive(PointingSample(azimuth, altitude), now);
    solved = game.advance(now) || solved;
  }
  return solved;
}

void main() {
  test('registros compartidos: radio 137 y fotografía +042', () {
    expect(PrototypeSky.radioDigits.join(), '137');
    expect(PrototypeSky.photoCode, '+042');
    final game = ObservatoryGame();
    for (final pair in [
      ('472', '+042'),
      ('137', '916'),
      ('137', '042'),
      ('137', '-042'),
      ('+042', '137'),
    ]) {
      expect(game.submitCodes(pair.$1, pair.$2), isFalse);
      expect(game.phase, ObservatoryPhase.coordinates);
    }
    expect(game.submitCodes(' 137 ', '+042 '), isTrue);
    expect(game.phase, ObservatoryPhase.calibrating);
  });

  test('calibración requiere lectura fresca y una dirección no vertical', () {
    final game = ObservatoryGame()..submitCodes('137', '+042');
    expect(game.calibrate(Duration.zero), isFalse);
    game.receive(const PointingSample(90, 90), Duration.zero);
    expect(game.calibrate(Duration.zero), isFalse);
    game.receive(const PointingSample(90, 20), Duration.zero);
    expect(game.calibrate(const Duration(seconds: 1)), isFalse);
    expect(game.calibrate(ms100), isTrue);
    expect(game.pointing.azimuth, 0);
    expect(game.pointing.altitude, 20);
  });

  test('norte del juego no depende del norte real y cruza 360 sin salto', () {
    final game = calibrated(heading: 355);
    game.receive(const PointingSample(5, 68), ms100);
    expect(game.pointing.azimuth, 10);
    expect(
      angularDistance(const PointingSample(359, 0), const PointingSample(1, 0)),
      closeTo(2, 1e-8),
    );
    expect(
      angularDistance(const PointingSample(180, 0), const PointingSample(0, 0)),
      closeTo(180, 1e-8),
    );
  });

  test('dos segundos estables resuelven una vez, no antes', () {
    final game = calibrated();
    expect(hold(game, 19), isFalse);
    expect(game.holdProgress, closeTo(0.95, 1e-9));
    expect(hold(game, 1, start: 19), isTrue);
    expect(game.phase, ObservatoryPhase.solved);
    expect(game.advance(const Duration(seconds: 3)), isFalse);
  });

  test('salir del objetivo descarta el tiempo parcial', () {
    final game = calibrated();
    hold(game, 15);
    game.receive(
      const PointingSample(250, 25),
      const Duration(milliseconds: 1510),
    );
    expect(game.holdProgress, 0);
    expect(hold(game, 15, start: 15), isFalse);
    expect(hold(game, 5, start: 30), isTrue);
  });

  test('un sensor detenido o una interrupción larga no resuelven', () {
    final game = calibrated();
    hold(game, 10);
    expect(game.advance(const Duration(seconds: 2)), isFalse);
    expect(game.holdProgress, 0);
    game.receive(const PointingSample(200, 68), const Duration(seconds: 4));
    expect(game.advance(const Duration(seconds: 4)), isFalse);
    expect(game.holdProgress, 0);
  });

  test('pausar requiere recalibrar y conserva los registros', () {
    final game = calibrated();
    hold(game, 10);
    game.suspend();
    expect(game.phase, ObservatoryPhase.calibrating);
    expect(game.holdProgress, 0);
    expect(game.hasFreshSample(const Duration(seconds: 2)), isFalse);
    game.receive(const PointingSample(17, 10), const Duration(seconds: 2));
    expect(game.calibrate(const Duration(seconds: 2)), isTrue);
    expect(game.pointing.azimuth, 0);
  });

  test('recalibrar conserva códigos; reiniciar también los borra', () {
    final game = calibrated();
    hold(game, 10);
    game.requestCalibration();
    expect(game.phase, ObservatoryPhase.calibrating);
    expect(game.holdProgress, 0);
    game.reset();
    expect(game.phase, ObservatoryPhase.coordinates);
    expect(game.calibrate(ms100), isFalse);
  });

  test('lecturas inválidas no se aceptan y el éxito sobrevive una pausa', () {
    final game = calibrated();
    game.receive(const PointingSample(double.nan, 68), ms100);
    expect(game.pointing.altitude, 0);
    game.receive(const PointingSample(200, 91), ms100);
    expect(game.pointing.altitude, 0);
    hold(game, 20);
    final pointing = game.pointing;
    game.suspend();
    expect(game.phase, ObservatoryPhase.solved);
    expect(game.pointing.azimuth, pointing.azimuth);
    expect(game.pointing.altitude, pointing.altitude);
    game.reset();
    expect(game.pointing.altitude, 0);
  });

  test('resplandor precede los pulsos de ambos receptores', () {
    expect(const ObservationTimeline(0.16).skyFlash, closeTo(1, 1e-9));
    expect(const ObservationTimeline(0.16).receiverPulse, 0);
    expect(const ObservationTimeline(0.42).skyFlash, 0);
    expect(const ObservationTimeline(0.42).receiverPulse, closeTo(1, 1e-9));
    expect(const ObservationTimeline(1).receiverPulse, 0);
  });

  test('proyección coloca la fuente en el centro al apuntar a ella', () {
    const size = Size(300, 300);
    expect(
      (projectSkyDirection(
                ObservatoryGame.target,
                ObservatoryGame.target,
                size,
              )! -
              size.center(Offset.zero))
          .distance,
      closeTo(0, 1e-8),
    );
    final flash = projectSkyDirection(
      ObservatoryGame.target,
      const PointingSample(0, 35),
      size,
      fieldOfView: 110,
    )!;
    expect(flash.dx, closeTo(150, 1e-8));
    expect(flash.dy, lessThan(150));
    expect((Offset.zero & size).contains(flash), isTrue);
    expect(
      projectSkyDirection(
        const PointingSample(180, -68),
        ObservatoryGame.target,
        size,
      ),
      isNull,
    );
  });
}
