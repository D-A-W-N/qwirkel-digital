import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_digital/src/net/network_game_view.dart';
import 'package:qwirkle_net/qwirkle_net.dart';

void main() {
  testWidgets('NetworkGameView zeigt einen Status-Text an', (tester) async {
    final game = QwirkleGame(players: [
      Player(id: 'p1', name: 'Alice'),
      Player(id: 'p2', name: 'Bob'),
    ]);
    final snapshot = GameStateSnapshot.forRecipient(game, 0);
    final hand = snapshot.players[0].hand ?? <Tile>[];

    await tester.pumpWidget(
      MaterialApp(
        home: NetworkGameView(
          snapshot: snapshot,
          ownHand: hand,
          canInteract: true,
          statusText: 'Spiel wird synchronisiert',
          onSendMove: (placements) async => true,
        ),
      ),
    );

    expect(find.text('Spiel wird synchronisiert'), findsOneWidget);
  });

  testWidgets('NetworkGameView zeigt einen Spielende-Dialog mit Gewinnern an', (
    tester,
  ) async {
    final game = QwirkleGame(players: [
      Player(id: 'p1', name: 'Alice'),
      Player(id: 'p2', name: 'Bob'),
    ]);
    game.players[0].score = 11;
    game.players[1].score = 7;
    game.isOver = true;
    final snapshot = GameStateSnapshot.forRecipient(game, 0);
    final hand = snapshot.players[0].hand ?? <Tile>[];

    await tester.pumpWidget(
      MaterialApp(
        home: NetworkGameView(
          snapshot: snapshot,
          ownHand: hand,
          canInteract: false,
          onSendMove: (placements) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partie beendet'), findsWidgets);
    expect(find.text('Alice: 11 Punkte (Gewinner)'), findsOneWidget);
  });

  testWidgets('NetworkGameView zeigt eine kurze Spielhilfe an', (tester) async {
    final game = QwirkleGame(players: [
      Player(id: 'p1', name: 'Alice'),
      Player(id: 'p2', name: 'Bob'),
    ]);
    final snapshot = GameStateSnapshot.forRecipient(game, 0);
    final hand = snapshot.players[0].hand ?? <Tile>[];

    await tester.pumpWidget(
      MaterialApp(
        home: NetworkGameView(
          snapshot: snapshot,
          ownHand: hand,
          canInteract: true,
          onSendMove: (placements) async => true,
        ),
      ),
    );

    expect(find.text('So spielst du'), findsOneWidget);

    await tester.tap(find.text('Los geht’s'));
    await tester.pump();

    expect(find.text('So spielst du'), findsNothing);
  });

  testWidgets('NetworkGameView sendet einen lokalen Zug an den Host', (
    tester,
  ) async {
    final game = QwirkleGame(players: [
      Player(id: 'p1', name: 'Alice'),
      Player(id: 'p2', name: 'Bob'),
    ]);
    game.currentPlayerIndex = 0;
    final snapshot = GameStateSnapshot.forRecipient(game, 0);
    final hand = snapshot.players[0].hand ?? <Tile>[];

    var sentMoves = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: NetworkGameView(
          snapshot: snapshot,
          ownHand: hand,
          canInteract: true,
          onSendMove: (placements) async {
            sentMoves += 1;
            expect(placements, isNotEmpty);
            return true;
          },
        ),
      ),
    );

    final handTile = find.byKey(const ValueKey('hand-0'));
    final boardCell = find.byKey(const ValueKey('board-0-0'));
    await tester.drag(
      handTile,
      tester.getCenter(boardCell) - tester.getCenter(handTile),
    );
    await tester.pump();

    expect(find.text('Zug senden'), findsOneWidget);

    await tester.tap(find.text('Zug senden'));
    await tester.pump();

    expect(sentMoves, 1);
  });
}
