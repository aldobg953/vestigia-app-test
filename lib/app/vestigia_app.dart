import 'package:flutter/material.dart';

import '../menu/main_menu_screen.dart';
import '../menu/puzzle_catalog.dart';
import '../menu/puzzle_entry.dart';
import 'vestigia_theme.dart';

class VestigiaApp extends StatelessWidget {
  const VestigiaApp({super.key, this.puzzles});

  /// Permite sustituir el catálogo (por ejemplo, en pruebas).
  final List<PuzzleEntry>? puzzles;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vestigia',
      debugShowCheckedModeBanner: false,
      theme: buildVestigiaTheme(),
      home: MainMenuScreen(puzzles: puzzles ?? defaultPuzzleCatalog()),
    );
  }
}
