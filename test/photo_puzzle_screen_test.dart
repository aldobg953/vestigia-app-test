import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_coordenadas/app/vestigia_app.dart';
import 'package:radio_coordenadas/core/haptics.dart';
import 'package:radio_coordenadas/menu/puzzle_entry.dart';
import 'package:radio_coordenadas/puzzles/photo/photo_config.dart';
import 'package:radio_coordenadas/puzzles/photo/photo_puzzle_screen.dart';
import 'package:radio_coordenadas/puzzles/photo/widgets/photo_back_view.dart';
import 'package:radio_coordenadas/puzzles/photo/widgets/photo_piece_view.dart';

import 'support/fakes.dart';

class PhotoHarness {
  final haptics = FakeHaptics();
  var seed = 3;

  Widget app() => VestigiaApp(
    puzzles: [
      PuzzleEntry(
        id: 'photo',
        title: 'Fotografía',
        description: 'Prueba',
        icon: Icons.photo,
        builder: (_) => PhotoPuzzleScreen(
          hapticsFactory: () => haptics,
          random: Random(seed++),
        ),
      ),
    ],
  );

  int get solvedCues =>
      haptics.cues.where((c) => c == HapticCue.photoSolved).length;
}

Future<void> openPhoto(WidgetTester tester) async {
  await tester.tap(find.text('Fotografía'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byType(PhotoPuzzleScreen), findsOneWidget);
}

PhotoPuzzleScreenState screenState(WidgetTester tester) =>
    tester.state<PhotoPuzzleScreenState>(find.byType(PhotoPuzzleScreen));

/// Arrastra con el dedo la pieza [id] hasta que su origen (esquina de la
/// foto armada) quede en [target], medido en anchos de foto.
Future<void> dragPiece(WidgetTester tester, int id, Offset target) async {
  final state = screenState(tester);
  final assembly = state.assembly!;
  final scale = state.layout!.scale;
  final piece = assembly.photo.piece(id);

  // Un punto visible de la pieza (no tapado por otra).
  Offset? grab;
  for (var gy = 1; gy < 20 && grab == null; gy++) {
    for (var gx = 1; gx < 20 && grab == null; gx++) {
      final local = Offset(
        piece.bounds.left + piece.bounds.width * gx / 20,
        piece.bounds.top + piece.bounds.height * gy / 20,
      );
      final point = assembly.originOf(id) + local;
      if (piece.contains(local) && assembly.pieceAt(point) == id) grab = point;
    }
  }
  expect(grab, isNotNull, reason: 'la pieza $id está tapada');

  final surfaceTopLeft = tester.getTopLeft(
    find.byKey(PhotoPuzzleScreen.surfaceKey),
  );
  final delta = (target - assembly.originOf(id)) * scale;
  final gesture = await tester.startGesture(surfaceTopLeft + grab! * scale);
  const steps = 12;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(delta / steps.toDouble());
  }
  await gesture.up();
  await tester.pump();
}

/// Origen centrado para armar la foto lejos de los bordes.
Offset centerOrigin(WidgetTester tester) {
  final assembly = screenState(tester).assembly!;
  return Offset(
    (assembly.surface.width - 1) / 2,
    (assembly.surface.height - assembly.photo.aspect) / 2,
  );
}

Future<void> solve(WidgetTester tester) async {
  final center = centerOrigin(tester);
  await dragPiece(tester, 0, center);
  await dragPiece(tester, 1, center + const Offset(0.03, -0.02));
  await dragPiece(tester, 2, center + const Offset(-0.02, 0.04));
}

Future<void> pumpFlip(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

String caption(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(PhotoPuzzleScreen.captionKey)).data!;

void main() {
  testWidgets('el menú incluye la fotografía y abre su pantalla', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const VestigiaApp());
    expect(find.text('Fotografía'), findsOneWidget);
    expect(find.byIcon(Icons.photo), findsOneWidget);

    await openPhoto(tester);
    expect(find.byType(PhotoPieceView), findsNWidgets(3));
    expect(screenState(tester).assembly!.groupCount, 3);
    expect(caption(tester), 'Arrastra los pedazos y une sus bordes');
  });

  testWidgets('arrastrar al lugar correcto une las piezas', (tester) async {
    usePhoneScreen(tester);
    final harness = PhotoHarness();
    await tester.pumpWidget(harness.app());
    await openPhoto(tester);

    final center = centerOrigin(tester);
    await dragPiece(tester, 0, center);
    await dragPiece(tester, 1, center + const Offset(0.04, 0.03));

    final assembly = screenState(tester).assembly!;
    expect(assembly.areJoined(0, 1), isTrue);
    expect(assembly.originOf(1), assembly.originOf(0));
    expect(caption(tester), 'Dos pedazos unidos · falta uno');
    expect(harness.solvedCues, 0);

    // El conjunto se arrastra como un solo objeto.
    final before = assembly.originOf(0);
    await dragPiece(tester, 1, before + const Offset(-0.05, 0.12));
    expect(assembly.originOf(0), assembly.originOf(1));
    expect(
      (assembly.originOf(0) - (before + const Offset(-0.05, 0.12))).distance,
      lessThan(0.01),
    );
  });

  testWidgets('soltar en una posición incorrecta no une', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(PhotoHarness().app());
    await openPhoto(tester);

    final center = centerOrigin(tester);
    await dragPiece(tester, 0, center);
    await dragPiece(tester, 1, center + const Offset(0.25, 0.1));
    expect(screenState(tester).assembly!.groupCount, 3);
  });

  testWidgets('al completar vibra una vez y voltea hasta el reverso', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final harness = PhotoHarness();
    await tester.pumpWidget(harness.app());
    await openPhoto(tester);

    await solve(tester);
    expect(harness.solvedCues, 1);
    expect(caption(tester), 'Fotografía completa');
    // Al inicio del giro se ve el frente: la foto armada.
    expect(find.byType(PhotoPieceView), findsNWidgets(3));
    expect(find.byKey(PhotoBackView.textKey), findsNothing);

    await pumpFlip(tester);
    expect(find.byType(PhotoPieceView), findsNothing);
    expect(find.byKey(PhotoBackView.textKey), findsOneWidget);
    expect(
      find.text(PhotoPuzzleConfig.provisionalCoordinatePart),
      findsOneWidget,
    );
    expect(
      caption(tester),
      'Inscripción en el reverso: '
      '${PhotoPuzzleConfig.provisionalCoordinatePart}',
    );

    // Más gestos sobre la foto resuelta no repiten nada.
    final surface = find.byKey(PhotoPuzzleScreen.surfaceKey);
    await tester.drag(surface, const Offset(40, 60));
    await pumpFlip(tester);
    expect(harness.solvedCues, 1);
    expect(find.byKey(PhotoBackView.textKey), findsOneWidget);
  });

  testWidgets('reiniciar separa las piezas y oculta el reverso', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final harness = PhotoHarness();
    await tester.pumpWidget(harness.app());
    await openPhoto(tester);

    await solve(tester);
    await pumpFlip(tester);
    await tester.tap(find.byKey(PhotoPuzzleScreen.restartKey));
    await tester.pump();

    final assembly = screenState(tester).assembly!;
    expect(assembly.groupCount, 3);
    expect(assembly.isSolved, isFalse);
    expect(find.byKey(PhotoBackView.textKey), findsNothing);
    expect(find.byType(PhotoPieceView), findsNWidgets(3));

    // Una vibración por partida.
    await solve(tester);
    await pumpFlip(tester);
    expect(harness.solvedCues, 2);
    expect(find.byKey(PhotoBackView.textKey), findsOneWidget);
  });

  testWidgets('volver al menú y Atrás de Android; cada entrada es nueva', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(PhotoHarness().app());
    await openPhoto(tester);

    final center = centerOrigin(tester);
    await dragPiece(tester, 0, center);
    await dragPiece(tester, 1, center);
    expect(screenState(tester).assembly!.groupCount, 2);

    await tester.tap(find.byTooltip('Volver al menú'));
    await tester.pumpAndSettle();
    expect(find.text('VESTIGIA'), findsOneWidget);

    await openPhoto(tester);
    expect(screenState(tester).assembly!.groupCount, 3);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('VESTIGIA'), findsOneWidget);
  });
}
