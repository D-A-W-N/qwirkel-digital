import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_digital/src/history/match_history.dart';
import 'package:qwirkle_digital/src/net/network_game_view.dart';
import 'package:qwirkle_net/qwirkle_net.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Der Übergang zu isOver erzeugt genau einen Partie-Historie-Eintrag '
    'mit dem übergebenen Modus und Raum-Code',
    (tester) async {
      final game = QwirkleGame(
        players: [
          Player(id: 'p1', name: 'Alice'),
          Player(id: 'p2', name: 'Bob'),
        ],
      );
      final runningSnapshot = GameStateSnapshot.forRecipient(game, 0);
      final hand = runningSnapshot.players[0].hand ?? <Tile>[];

      Widget buildView(GameStateSnapshot snapshot) => MaterialApp(
        home: NetworkGameView(
          mode: MatchMode.internet,
          roomCode: 'WXYZ',
          snapshot: snapshot,
          ownHand: hand,
          canInteract: false,
          onSendMove: (placements) async => true,
          onSendPass: () {},
          onSendExchange: (tiles) {},
          isRoomOwner: false,
          onRestartGame: () {},
        ),
      );

      await tester.pumpWidget(buildView(runningSnapshot));
      expect(await loadMatchHistory(), isEmpty);

      game.players[0].score = 20;
      game.players[1].score = 9;
      game.isOver = true;
      final finishedSnapshot = GameStateSnapshot.forRecipient(game, 0);

      await tester.pumpWidget(buildView(finishedSnapshot));
      await tester.pumpAndSettle();

      final history = await loadMatchHistory();
      expect(history, hasLength(1));
      expect(history.single.mode, MatchMode.internet);
      expect(history.single.roomCode, 'WXYZ');
      expect(history.single.standings.map((s) => s.name), ['Alice', 'Bob']);

      // Ein weiterer Rebuild mit demselben (weiterhin beendeten) Snapshot
      // darf keinen zweiten Eintrag erzeugen - nur der ÜBERGANG zählt.
      await tester.pumpWidget(buildView(finishedSnapshot));
      await tester.pumpAndSettle();
      expect(await loadMatchHistory(), hasLength(1));
    },
  );
}
