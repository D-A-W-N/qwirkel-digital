import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qwirkle_core/qwirkle_core.dart';

import '../game/game_controller.dart';
import '../game/game_providers.dart';
import '../game/game_screen.dart';

/// Spiel-Setup für den lokalen Pass&Play-Modus: Spieleranzahl (2-6) und Namen.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const minPlayers = 2;
  static const maxPlayers = 6;

  int _playerCount = 2;
  late final List<TextEditingController> _nameControllers;

  @override
  void initState() {
    super.initState();
    _nameControllers = List.generate(
      maxPlayers,
      (i) => TextEditingController(text: 'Spieler ${i + 1}'),
    );
  }

  @override
  void dispose() {
    for (final controller in _nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startGame() {
    final players = [
      for (var i = 0; i < _playerCount; i++)
        Player(
          id: 'p$i',
          name: _nameControllers[i].text.trim().isEmpty
              ? 'Spieler ${i + 1}'
              : _nameControllers[i].text.trim(),
        ),
    ];
    final game = QwirkleGame(players: players);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProviderScope(
          overrides: [
            gameControllerProvider.overrideWith((ref) => GameController(game)),
          ],
          child: const GameScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Qwirkle · Lokales Spiel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anzahl Spieler (Pass & Play, $minPlayers-$maxPlayers)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Row(
              children: [
                IconButton(
                  onPressed: _playerCount > minPlayers
                      ? () => setState(() => _playerCount--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_playerCount',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton(
                  onPressed: _playerCount < maxPlayers
                      ? () => setState(() => _playerCount++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _playerCount,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TextField(
                    controller: _nameControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Name Spieler ${i + 1}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _startGame,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Spiel starten'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
