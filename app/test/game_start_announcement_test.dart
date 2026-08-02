import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_digital/src/game/game_controller.dart';
import 'package:qwirkle_digital/src/game/game_providers.dart';
import 'package:qwirkle_digital/src/game/game_screen.dart';

void main() {
  testWidgets(
    'GameScreen kündigt beim Start an, wer beginnt (und warum)',
    (tester) async {
      // Bens Hand hat nur unterschiedliche Farbe/Form-Kombinationen (längste
      // mögliche Reihe: 1), Annas Hand ist komplett rot (längste mögliche
      // Reihe: 6) - Anna muss also laut Hausregel beginnen. TileBag.draw
      // zieht vom Ende der Liste, Spieler 1 (Anna) zieht zuerst.
      final bag = TileBag.fromTiles([
        const Tile(TileColor.orange, TileShape.cross),
        const Tile(TileColor.yellow, TileShape.diamond),
        const Tile(TileColor.green, TileShape.square),
        const Tile(TileColor.blue, TileShape.star),
        const Tile(TileColor.purple, TileShape.clover),
        const Tile(TileColor.red, TileShape.circle),
        const Tile(TileColor.red, TileShape.circle),
        const Tile(TileColor.red, TileShape.cross),
        const Tile(TileColor.red, TileShape.diamond),
        const Tile(TileColor.red, TileShape.square),
        const Tile(TileColor.red, TileShape.star),
        const Tile(TileColor.red, TileShape.clover),
      ]);
      final anna = Player(id: 'a', name: 'Anna');
      final ben = Player(id: 'b', name: 'Ben');
      final game = QwirkleGame(players: [anna, ben], bag: bag);

      expect(game.currentPlayerIndex, 0, reason: 'Anna sollte laut Hausregel beginnen.');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameControllerProvider.overrideWith((ref) => GameController(game)),
          ],
          child: const MaterialApp(home: GameScreen()),
        ),
      );

      await tester.pump();

      expect(find.textContaining('Anna beginnt'), findsOneWidget);
    },
  );
}
