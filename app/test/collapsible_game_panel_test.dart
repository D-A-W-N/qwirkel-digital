import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_digital/src/game/game_controller.dart';
import 'package:qwirkle_digital/src/game/game_providers.dart';
import 'package:qwirkle_digital/src/game/game_screen.dart';

void main() {
  testWidgets(
    'Das untere Panel im lokalen Spiel lässt sich ein- und wieder ausklappen, '
    'ohne die Hand dauerhaft zu verlieren',
    (tester) async {
      final alice = Player(id: 'a', name: 'Alice');
      final bob = Player(id: 'b', name: 'Bob');
      final game = QwirkleGame(players: [alice, bob]);
      game.currentPlayerIndex = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameControllerProvider.overrideWith((ref) => GameController(game)),
          ],
          child: const MaterialApp(home: GameScreen()),
        ),
      );
      await tester.pump();
      // Die Start-Ansage (Snackbar) läge sonst über dem Ein-/Ausklapp-Icon
      // am unteren Bildschirmrand und würde den Tap abfangen.
      ScaffoldMessenger.of(
        tester.element(find.byType(GameScreen)),
      ).removeCurrentSnackBar();
      await tester.pump();

      // Standardmäßig ausgeklappt - Hand ist sofort sichtbar/ziehbar.
      expect(find.byType(Draggable<int>), findsWidgets);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.byType(Draggable<int>), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pumpAndSettle();

      expect(find.byType(Draggable<int>), findsWidgets);
    },
  );
}
