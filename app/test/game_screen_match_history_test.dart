import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_digital/src/game/game_controller.dart';
import 'package:qwirkle_digital/src/game/game_providers.dart';
import 'package:qwirkle_digital/src/game/game_screen.dart';
import 'package:qwirkle_digital/src/history/match_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Ein beendetes lokales Spiel erzeugt genau einen Partie-Historie-Eintrag',
    (tester) async {
      final anna = Player(id: 'a', name: 'Anna');
      final ben = Player(id: 'b', name: 'Ben');
      final game = QwirkleGame(players: [anna, ben]);
      anna.score = 25;
      ben.score = 10;
      game.isOver = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameControllerProvider.overrideWith((ref) => GameController(game)),
          ],
          child: const MaterialApp(home: GameScreen()),
        ),
      );
      // `recordMatch` läuft `unawaited` (fire-and-forget), `pumpAndSettle`
      // lässt sowohl es als auch den per `addPostFrameCallback`
      // ausgelösten Spielende-Dialog fertig laufen.
      await tester.pumpAndSettle();

      final history = await loadMatchHistory();
      expect(history, hasLength(1));
      expect(history.single.mode, MatchMode.local);
      expect(history.single.standings.map((s) => s.name), ['Anna', 'Ben']);
      expect(history.single.standings.map((s) => s.score), [25, 10]);

      // Ein weiterer Rebuild (z. B. durch den offenen Dialog) darf keinen
      // zweiten Eintrag erzeugen - `_gameOverShown` schützt davor.
      await tester.pump();
      expect(await loadMatchHistory(), hasLength(1));
    },
  );
}
