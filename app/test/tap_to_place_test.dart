import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_digital/src/game/game_controller.dart';
import 'package:qwirkle_digital/src/game/game_providers.dart';
import 'package:qwirkle_digital/src/game/game_screen.dart';

void main() {
  testWidgets(
    'Ein Handstein lässt sich ohne jede Drag-Geste antippen und dann auf '
    'ein leeres Feld tippen, um ihn zu platzieren',
    (tester) async {
      final anna = Player(id: 'a', name: 'Anna');
      final ben = Player(id: 'b', name: 'Ben');
      final game = QwirkleGame(players: [anna, ben]);
      final controller = GameController(game);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [gameControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(home: GameScreen()),
        ),
      );
      // Der "Du bist am Zug"-Hinweis (siehe `turn_dialog.dart`) erscheint
      // beim allerersten Zug ebenfalls und muss erst weggeklickt werden,
      // bevor das Brett darunter überhaupt antippbar ist.
      await tester.pump();
      await tester.tap(find.text('Los geht’s'));
      await tester.pump();

      expect(controller.selectedHandIndex, isNull);
      expect(controller.pendingPlacements, isEmpty);

      // Wer beginnt, entscheidet die Hausregel (längste mögliche Reihe aus
      // der Starthand, siehe `starting_player.dart`) - nicht notwendigerweise
      // Anna.
      final firstTile = game.currentPlayer.hand[0];

      await tester.tap(find.byKey(const ValueKey('hand-0')));
      await tester.pump();
      expect(controller.selectedHandIndex, 0);

      await tester.tap(find.byKey(const ValueKey('board-0-0')));
      await tester.pump();

      // Platziert, und die Auswahl ist danach wieder leer (siehe
      // `GameController.stageTile`).
      expect(controller.pendingPlacements, hasLength(1));
      expect(controller.pendingPlacements[const Position(0, 0)], firstTile);
      expect(controller.selectedHandIndex, isNull);
    },
  );

  testWidgets(
    'Erneutes Antippen desselben Handsteins hebt die Auswahl wieder auf',
    (tester) async {
      final anna = Player(id: 'a', name: 'Anna');
      final ben = Player(id: 'b', name: 'Ben');
      final game = QwirkleGame(players: [anna, ben]);
      final controller = GameController(game);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [gameControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(home: GameScreen()),
        ),
      );
      // Der "Du bist am Zug"-Hinweis (siehe `turn_dialog.dart`) erscheint
      // beim allerersten Zug ebenfalls und muss erst weggeklickt werden,
      // bevor das Brett darunter überhaupt antippbar ist.
      await tester.pump();
      await tester.tap(find.text('Los geht’s'));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('hand-0')));
      await tester.pump();
      expect(controller.selectedHandIndex, 0);

      await tester.tap(find.byKey(const ValueKey('hand-0')));
      await tester.pump();
      expect(controller.selectedHandIndex, isNull);
    },
  );
}
