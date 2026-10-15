import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const captureVerification = bool.fromEnvironment('VESTIGIA_SCREENSHOTS');

Future<void> loadVerificationFonts() async {
  if (!captureVerification) return;
  if (Platform.isWindows) {
    final windows = Platform.environment['WINDIR'] ?? r'C:\Windows';
    for (final (family, filename) in [
      ('serif', 'times.ttf'),
      ('Roboto', 'times.ttf'),
      ('Ahem', 'times.ttf'),
      ('monospace', 'consola.ttf'),
    ]) {
      final font = File('$windows/Fonts/$filename');
      if (!await font.exists()) continue;
      final loader = FontLoader(family)
        ..addFont(font.readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

Future<void> captureScreen(
  WidgetTester tester,
  Finder boundary,
  String name,
) async {
  if (!captureVerification) return;
  await tester.pump();
  final render = tester.renderObject<RenderRepaintBoundary>(boundary);
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/verification/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
