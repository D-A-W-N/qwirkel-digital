import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_digital/src/game/game_controller.dart';
import 'package:qwirkle_digital/src/game/game_providers.dart';
import 'package:qwirkle_digital/src/game/game_screen.dart';

void main() {
  testWidgets(
    'Die untere Leiste im lokalen Spiel zeigt Hand und Buttons immer '
    'sofort an, ohne dass man sie erst ausklappen müsste',
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

      // Keine Ein-/Ausklapp-Steuerung mehr vorhanden - die Hand ist einfach
      // immer da.
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsNothing);
      expect(find.byType(Draggable<int>), findsWidgets);
      expect(find.text('Zug bestätigen'), findsOneWidget);
    },
  );
}
