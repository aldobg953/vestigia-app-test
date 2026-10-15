import 'package:flutter_test/flutter_test.dart';
import 'package:radio_coordenadas/puzzles/lookout/lens_cleaning.dart';
import 'package:radio_coordenadas/puzzles/lookout/lookout_config.dart';
import 'package:radio_coordenadas/puzzles/lookout/lookout_game.dart';
import 'package:radio_coordenadas/puzzles/lookout/view_orientation.dart';

const config = LookoutConfig();

LensCleaning newLens() => LensCleaning(
  resolution: config.gridResolution,
  brushRadius: config.brushRadius,
);

/// Recorre el lente en zigzag con un solo trazo hasta la fila [untilY].
void zigzag(
  void Function(Offset) begin,
  void Function(Offset) extend, {
  double untilY = 0.97,
}) {
  var y = 0.03;
  begin(Offset(0, y));
  var leftToRight = true;
  while (y <= untilY) {
    extend(Offset(leftToRight ? 1 : 0, y));
    y += 0.08;
    if (y <= untilY) extend(Offset(leftToRight ? 1 : 0, y));
    leftToRight = !leftToRight;
  }
}

/// Limpia todo el lente con un trazo; devuelve los sucesos producidos.
List<LookoutEvent> cleanAll(LookoutGame game, {double untilY = 0.97}) {
  final events = <LookoutEvent>[];
  late int stroke;
  zigzag(
    (p) {
      final result = game.beginWipe(p);
      stroke = result.stroke!;
      if (result.event != null) events.add(result.event!);
    },
    (p) {
      final event = game.extendWipe(stroke, p);
      if (event != null) events.add(event);
    },
    untilY: untilY,
  );
  return events;
}

void main() {
  group('limpieza del lente', () {
    test('limpiar zonas nuevas suma; repetir la misma zona no', () {
      final lens = newLens();
      final stroke = lens.beginStroke(const Offset(0.3, 0.5));
      final first = lens.extendStroke(stroke, const Offset(0.7, 0.5));
      expect(first, greaterThan(0));
      final progress = lens.progress;

      expect(lens.extendStroke(stroke, const Offset(0.3, 0.5)), 0);
      for (var i = 0; i < 10; i++) {
        lens.extendStroke(stroke, Offset(i.isEven ? 0.65 : 0.35, 0.5));
      }
      expect(lens.progress, progress);

      // Una zona distinta sí suma.
      expect(
        lens.extendStroke(stroke, const Offset(0.35, 0.7)),
        greaterThan(0),
      );
      expect(lens.progress, greaterThan(progress));
    });

    test('un trazo rápido (un solo salto largo) no deja huecos', () {
      final lens = newLens();
      final stroke = lens.beginStroke(const Offset(0.1, 0.5));
      lens.extendStroke(stroke, const Offset(0.9, 0.5));
      for (var x = 0.1; x <= 0.9; x += 0.01) {
        expect(lens.isCleanAt(Offset(x, 0.5)), isTrue, reason: 'x=$x');
        expect(lens.isCleanAt(Offset(x, 0.55)), isTrue, reason: 'x=$x');
      }
      // Fuera del ancho del trazo sigue sucio.
      expect(lens.isCleanAt(const Offset(0.5, 0.62)), isFalse);
      expect(lens.isCleanAt(const Offset(0.5, 0.38)), isFalse);
    });

    test('solo cuenta la superficie del lente', () {
      final lens = newLens();
      // Esquina del cuadrado, fuera del círculo del lente.
      final stroke = lens.beginStroke(const Offset(0.02, 0.02));
      expect(lens.extendStroke(stroke, const Offset(0.08, 0.02)), 0);
      expect(lens.progress, 0);
      // Un trazo que entra desde fuera limpia solo la parte de dentro.
      lens.extendStroke(stroke, const Offset(0.5, 0.5));
      expect(lens.progress, greaterThan(0));
      expect(lens.isCleanAt(const Offset(0.03, 0.03)), isFalse);
    });

    test('recorrer todo el lente lo deja limpio', () {
      final lens = newLens();
      late int stroke;
      zigzag(
        (p) => stroke = lens.beginStroke(p),
        (p) => lens.extendStroke(stroke, p),
      );
      expect(lens.progress, greaterThan(0.99));
      lens.reset();
      expect(lens.progress, 0);
      expect(lens.strokes, isEmpty);
    });
  });

  group('orientación', () {
    test('cada perilla mueve solo su eje', () {
      final view = ViewOrientation(config);
      final center = view.viewCenter;
      view.setX(50);
      expect(view.x, 50);
      expect(view.y, config.initialY);
      expect(view.viewCenter.dx, greaterThan(center.dx));
      expect(view.viewCenter.dy, center.dy);

      final afterX = view.viewCenter;
      view.setY(-30);
      expect(view.y, -30);
      expect(view.x, 50);
      expect(view.viewCenter.dx, afterX.dx);
      // Y negativo mira hacia abajo en el panorama.
      expect(view.viewCenter.dy, greaterThan(afterX.dy));
    });

    test('los ejes tienen límites y la vista no sale del panorama', () {
      final view = ViewOrientation(config);
      view.setX(500);
      view.setY(-500);
      expect(view.x, config.xRange.max);
      expect(view.y, config.yRange.min);
      final halfW = config.viewWidthFraction / 2;
      final halfH = config.viewWidthFraction / config.panoramaAspect / 2;
      expect(view.viewCenter.dx, closeTo(1 - halfW, 1e-12));
      expect(view.viewCenter.dy, closeTo(1 - halfH, 1e-12));
      view.setX(-500);
      view.setY(500);
      expect(view.x, config.xRange.min);
      expect(view.y, config.yRange.max);
      expect(view.viewCenter.dx, closeTo(halfW, 1e-12));
      expect(view.viewCenter.dy, closeTo(halfH, 1e-12));
    });

    test('los valores objetivo centran el objetivo en la retícula', () {
      final view = ViewOrientation(config);
      final center = view.viewCenterFor(view.targetX, view.targetY);
      expect((center - config.targetPosition).distance, lessThan(1e-9));
    });

    test('alinear exige ambos ejes dentro de la tolerancia', () {
      final view = ViewOrientation(config);
      final tol = config.alignTolerance;
      view.setX(view.targetX + tol * 0.9);
      view.setY(view.targetY - tol * 0.9);
      expect(view.isAligned, isTrue);

      view.setX(view.targetX - tol * 1.1);
      expect(view.isAligned, isFalse);
      view.setX(view.targetX);
      view.setY(view.targetY + tol * 1.1);
      expect(view.isAligned, isFalse);
    });

    test('el objetivo y la tolerancia son configurables', () {
      const custom = LookoutConfig(
        targetPosition: Offset(0.3, 0.6),
        alignTolerance: 10,
      );
      final view = ViewOrientation(custom);
      expect(
        (view.viewCenterFor(view.targetX, view.targetY) - custom.targetPosition)
            .distance,
        lessThan(1e-9),
      );
      view.setX(view.targetX + 9);
      view.setY(view.targetY - 9);
      expect(view.isAligned, isTrue);
    });
  });

  group('fases', () {
    test('las perillas no responden durante la limpieza', () {
      final game = LookoutGame(config);
      expect(game.setX(40), isNull);
      expect(game.setY(40), isNull);
      expect(game.view.x, config.initialX);
      expect(game.view.y, config.initialY);
    });

    test('pasa a la fase 2 al superar el umbral, una sola vez', () {
      final game = LookoutGame(config);
      expect(cleanAll(game, untilY: 0.5), isEmpty);
      expect(game.phase, LookoutPhase.cleaning);
      expect(game.lens.progress, lessThan(config.cleanThreshold));

      expect(cleanAll(game), [LookoutEvent.lensCleaned]);
      expect(game.phase, LookoutPhase.orienting);
      expect(game.lens.progress, greaterThanOrEqualTo(config.cleanThreshold));
      // Ya no se limpia: los trazos se ignoran.
      expect(game.beginWipe(const Offset(0.5, 0.5)).stroke, isNull);
      expect(game.extendWipe(0, const Offset(0.2, 0.2)), isNull);
    });

    test('el umbral de limpieza es configurable', () {
      final game = LookoutGame(const LookoutConfig(cleanThreshold: 0.3));
      expect(cleanAll(game, untilY: 0.5), [LookoutEvent.lensCleaned]);
      expect(game.phase, LookoutPhase.orienting);
    });

    test('alinear resuelve una sola vez y bloquea las perillas', () {
      final game = LookoutGame(config);
      cleanAll(game);
      expect(game.setX(game.view.targetX), isNull);
      expect(game.setY(game.view.targetY), LookoutEvent.aligned);
      expect(game.phase, LookoutPhase.observing);
      expect(game.setX(0), isNull);
      expect(game.view.x, closeTo(game.view.targetX, 1e-9));
      game.finishObservation();
      expect(game.phase, LookoutPhase.solved);
      expect(game.setY(0), isNull);
      game.finishObservation();
      expect(game.phase, LookoutPhase.solved);
    });

    test('reiniciar restaura la suciedad, los ejes y la fase 1', () {
      final game = LookoutGame(config);
      cleanAll(game);
      game.setX(70);
      game.setY(-20);
      game.reset();
      expect(game.phase, LookoutPhase.cleaning);
      expect(game.lens.progress, 0);
      expect(game.view.x, config.initialX);
      expect(game.view.y, config.initialY);
    });
  });
}
