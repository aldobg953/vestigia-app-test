import 'package:flutter/widgets.dart';

/// Entrada del menú principal. Para añadir un puzzle basta con crear su
/// pantalla y registrar una entrada en `puzzle_catalog.dart`.
class PuzzleEntry {
  const PuzzleEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;

  /// Construye una pantalla nueva cada vez que se abre, de modo que cada
  /// entrada empieza una partida limpia.
  final WidgetBuilder builder;
}
