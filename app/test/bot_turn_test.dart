import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_digital/src/game/game_controller.dart';
import 'package:qwirkle_digital/src/game/game_providers.dart';
import 'package:qwirkle_digital/src/game/game_screen.dart';

void main() {
  testWidgets('Bot-Spieler zieht nach kurzer Verzögerung automatisch', (
    tester,
  ) async {
    final anna = Player(
      id: 'a',
      name: 'BotAnna',
      botDifficulty: BotDifficulty.easy,
    );
    final ben = Player(
      id: 'b',
      name: 'BotBen',
      botDifficulty: BotDifficulty.easy,
    );
    final game = QwirkleGame(players: [anna, ben]);
    final initialRemaining = game.bag.remaining;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameControllerProvider.overrideWith((ref) => GameController(game)),
        ],
        child: const MaterialApp(home: GameScreen()),
      ),
    );

    await tester.pump();
    expect(find.textContaining('Bot) denkt nach'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(game.bag.remaining, isNot(initialRemaining));

    // Widget abbauen und den daraufhin evtl. noch ausstehenden Bot-Timer
    // ablaufen lassen, damit der Test ohne offene Timer sauber endet.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });
}
