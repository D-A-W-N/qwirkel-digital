import 'package:flutter/material.dart';

/// Spielerliste vor Spielstart - identisch zwischen LAN- (`NetworkGameScreen`)
/// und Internet-Lobby (`InternetRoomScreen`), bis auf [allReady] (LAN kann
/// diese Ansicht theoretisch auch nach Spielstart noch kurz zeigen, Internet
/// rendert diesen Zustand konstruktionsbedingt nur vor Spielstart).
class LobbyPlayerList extends StatelessWidget {
  const LobbyPlayerList({
    super.key,
    required this.players,
    this.allReady = false,
  });

  final List<({String id, String name})> players;
  final bool allReady;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Text('Noch keine Teilnehmer');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final player in players)
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(player.name),
            trailing: allReady
                ? Icon(Icons.play_circle_fill, color: Colors.green.shade700)
                : Icon(Icons.pending, color: Colors.orange.shade700),
          ),
      ],
    );
  }
}

/// "Spiel starten" (nur für Owner, nur vor Spielstart) + "Zurück"-Button -
/// identisch zwischen LAN- und Internet-Lobby.
class LobbyActionButtons extends StatelessWidget {
  const LobbyActionButtons({
    super.key,
    required this.hasOwnerControls,
    required this.gameStarted,
    required this.onStartGame,
    required this.onBack,
    this.backLabel = 'Zurück zur Lobby',
    this.additionalAction,
  });

  final bool hasOwnerControls;
  final bool gameStarted;
  final VoidCallback onStartGame;
  final VoidCallback onBack;
  final String backLabel;

  /// Zusätzliche Aktion unterhalb des Zurück-Buttons - z. B. Internets
  /// "Raum verlassen" (LAN kennt diese Trennung von reiner Navigation
  /// nicht, lässt das Feld also weg).
  final Widget? additionalAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (hasOwnerControls && !gameStarted) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStartGame,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Spiel starten'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: onBack, child: Text(backLabel)),
        ),
        if (additionalAction != null) ...[
          const SizedBox(height: 8),
          additionalAction!,
        ],
      ],
    );
  }
}
