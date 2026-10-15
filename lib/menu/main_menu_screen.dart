import 'package:flutter/material.dart';

import '../app/vestigia_theme.dart';
import 'puzzle_entry.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key, required this.puzzles});

  final List<PuzzleEntry> puzzles;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              const Text(
                'VESTIGIA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40,
                  letterSpacing: 10,
                  fontWeight: FontWeight.w600,
                  color: VestigiaColors.brass,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Puzzles',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  letterSpacing: 3,
                  color: VestigiaColors.creamMuted,
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView.separated(
                  itemCount: puzzles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) =>
                      _PuzzleCard(entry: puzzles[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PuzzleCard extends StatelessWidget {
  const _PuzzleCard({required this.entry});

  final PuzzleEntry entry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VestigiaColors.wood,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: VestigiaColors.brassDark, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: entry.builder)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: VestigiaColors.glass,
                    border: Border.all(color: VestigiaColors.brass, width: 1.5),
                  ),
                  child: Icon(entry.icon, color: VestigiaColors.glow, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: VestigiaColors.cream,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: VestigiaColors.creamMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: VestigiaColors.brass,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
