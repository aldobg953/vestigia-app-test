import 'package:flutter/material.dart';

import 'vestigia_theme.dart';

/// Barra común de los puzzles: volver al menú, título y nueva partida.
class PuzzleTopBar extends StatelessWidget {
  const PuzzleTopBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onRestart,
    this.restartKey,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onRestart;
  final Key? restartKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver al menú',
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                letterSpacing: 1,
                color: VestigiaColors.cream,
              ),
            ),
          ),
          IconButton(
            key: restartKey,
            icon: const Icon(Icons.refresh),
            tooltip: 'Nueva partida',
            onPressed: onRestart,
          ),
        ],
      ),
    );
  }
}
