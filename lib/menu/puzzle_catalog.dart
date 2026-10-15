import 'package:flutter/material.dart';

import '../puzzles/lookout/lookout_screen.dart';
import '../puzzles/observatory/observatory_screen.dart';
import '../puzzles/photo/photo_puzzle_screen.dart';
import '../puzzles/radio/radio_puzzle_screen.dart';
import 'puzzle_entry.dart';

/// Puzzles disponibles en el menú, en el orden en que se muestran.
List<PuzzleEntry> defaultPuzzleCatalog() => [
  PuzzleEntry(
    id: 'radio',
    title: 'Radio',
    description: 'Sintoniza las señales y registra el mensaje.',
    icon: Icons.radio,
    builder: (_) => const RadioPuzzleScreen(),
  ),
  PuzzleEntry(
    id: 'photo',
    title: 'Fotografía',
    description: 'Une los tres pedazos de una fotografía rasgada.',
    icon: Icons.photo,
    builder: (_) => const PhotoPuzzleScreen(),
  ),
  PuzzleEntry(
    id: 'lookout',
    title: 'Mirador del faro',
    description: 'Limpia el lente y orienta la vista con dos perillas.',
    icon: Icons.visibility,
    builder: (_) => const LookoutScreen(),
  ),
  PuzzleEntry(
    id: 'observatory',
    title: 'Observatorio',
    description: 'Reúne los registros y observa el cielo.',
    icon: Icons.travel_explore,
    builder: (_) => const ObservatoryScreen(),
  ),
];
