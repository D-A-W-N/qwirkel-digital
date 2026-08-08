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

  /// Verbindungsstatus pro Spieler:in (siehe `PlayerView.connected`) - nur
  /// für Netzwerkpartien relevant, `null` (Standard) blendet das Symbol
  /// komplett aus, damit das lokale Spiel unverändert bleibt. Nutzer-
  /// Feedback: es sollte sichtbar sein, wenn jemand nicht (mehr) im Raum
  /// ist, statt dass die Partie kommentarlos zu warten scheint.
  final List<bool>? connected;

  const ScorePanel({
    super.key,
    required this.players,
    required this.currentIndex,
    this.scores,
    this.connected,
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
          final isDisconnected = connected != null && !connected![index];
          return Chip(
            avatar: active ? const Icon(Icons.play_arrow, size: 18) : null,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDisconnected) ...[
                  Icon(
                    Icons.wifi_off,
                    size: 14,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  '${player.name}: $score ${score == 1 ? 'Punkt' : 'Punkte'}',
                ),
              ],
            ),
            backgroundColor: active
                ? Theme.of(context).colorScheme.tertiaryContainer
                : null,
          );
        },
      ),
    );
  }
}
