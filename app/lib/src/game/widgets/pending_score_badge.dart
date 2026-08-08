import 'package:flutter/material.dart';

/// Schwebendes Badge oben rechts über dem Brett - zeigt den Punktwert des
/// gerade vorbereiteten (noch nicht gesendeten) Zugs. Ersetzt die vorher im
/// unteren Statustext eingebettete zweite Zeile ("Dieser Zug: X Punkte ...
/// Gesamt danach: Y"), die besonders auf dem Handy die untere Leiste
/// unnötig aufgebläht hat, genau während man sie am meisten braucht (siehe
/// Nutzer-Feedback).
class PendingScoreBadge extends StatelessWidget {
  const PendingScoreBadge({
    super.key,
    required this.score,
    required this.totalAfter,
  });

  final int score;
  final int totalAfter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '+$score ${score == 1 ? 'Punkt' : 'Punkte'}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            Text(
              'Gesamt: $totalAfter',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
