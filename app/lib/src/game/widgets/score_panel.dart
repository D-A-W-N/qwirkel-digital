import 'package:flutter/material.dart';
import 'package:qwirkle_core/qwirkle_core.dart';

/// Zeigt Namen und Punktestand aller Spieler; hebt den aktuellen Spieler hervor.
class ScorePanel extends StatelessWidget {
  final List<Player> players;
  final int currentIndex;

  /// Punktestand pro Spieler:in, getrennt von [Player.score] - Netzwerkpartien
  /// rekonstruieren `Player`-Objekte ohne Score (der kommt separat aus dem
  /// `GameStateSnapshot`), das lokale Spiel nutzt stattdessen `Player.score`
  /// direkt (Standard, wenn [scores] weggelassen wird).
  final List<int>? scores;

  const ScorePanel({
    super.key,
    required this.players,
    required this.currentIndex,
    this.scores,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: players.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final active = index == currentIndex;
          final player = players[index];
          final score = scores != null ? scores![index] : player.score;
          return Chip(
            avatar: active ? const Icon(Icons.play_arrow, size: 18) : null,
            label: Text('${player.name}: $score ${score == 1 ? 'Punkt' : 'Punkte'}'),
            backgroundColor: active
                ? Theme.of(context).colorScheme.tertiaryContainer
                : null,
          );
        },
      ),
    );
  }
}
