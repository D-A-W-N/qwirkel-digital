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

    // Ein zusätzlicher Pump: das erste Zentrieren setzt den
    // TransformationController erst im Post-Frame-Callback des ersten
    // Frames, `InteractiveViewer` übernimmt die neue Transformation dann
    // erst im darauffolgenden Frame - ohne diesen Pump läge `getCenter()`
    // noch auf der unzentrierten (Rohkoordinaten-)Position.
    await tester.pump();
    // Puls- und Tutorial-Overlay liegen über dem Brett und würden die
    // Drag-Geste sonst abfangen - wie eine echte Nutzerin erst wegtippen.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text('Los geht’s'));
    await tester.pump();

    final handTile = find.byKey(const ValueKey('hand-0'));
    final boardCell = find.byKey(const ValueKey('board-0-0'));
    final gesture = await tester.startGesture(tester.getCenter(handTile));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(boardCell));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump();

    expect(find.text('Zug senden'), findsOneWidget);

    await tester.tap(find.text('Zug senden'));
    await tester.pump();

    expect(sentMoves, 1);
  });

  testWidgets(
    'Eine ungültige Platzierung wird sofort live abgelehnt, ohne den Stein zu platzieren',
    (tester) async {
      final game = QwirkleGame(players: [
        Player(id: 'p1', name: 'Alice'),
        Player(id: 'p2', name: 'Bob'),
      ]);
      game.currentPlayerIndex = 0;
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.text('Los geht’s'));
      await tester.pump();

      Future<void> dragToBoard(String handKey, String boardKey) async {
        final source = find.byKey(ValueKey(handKey));
        final target = find.byKey(ValueKey(boardKey));
        final gesture = await tester.startGesture(tester.getCenter(source));
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.moveTo(tester.getCenter(target));
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pump();
      }

      // Erster Stein bei (0,0): immer gültig (isolierter erster Zug).
      await dragToBoard('hand-0', 'board-0-0');
      // Zweiter Stein bei (2,0): lässt (1,0) aus - Lücke in der Reihe.
      await dragToBoard('hand-1', 'board-2-0');

      expect(find.textContaining('lückenlos'), findsOneWidget);
      // Nur EIN Stein wurde tatsächlich platziert - der Punktevorschau-Text
      // würde bei zwei erfolgreich platzierten Steinen anders aussehen.
      expect(find.textContaining('Dieser Zug: 1 Punkt'), findsOneWidget);
    },
  );

  testWidgets(
    'Bei einem vom Server abgelehnten Zug bleibt die vorläufige Platzierung sichtbar und der Fehler wird angezeigt',
    (tester) async {
      final game = QwirkleGame(players: [
        Player(id: 'p1', name: 'Alice'),
        Player(id: 'p2', name: 'Bob'),
      ]);
      game.currentPlayerIndex = 0;
      final snapshot = GameStateSnapshot.forRecipient(game, 0);
      final hand = snapshot.players[0].hand ?? <Tile>[];

      Widget buildView({String? errorText}) => MaterialApp(
        home: NetworkGameView(
          snapshot: snapshot,
          ownHand: hand,
          canInteract: true,
          onSendMove: (placements) async => true,
          errorText: errorText,
        ),
      );

      await tester.pumpWidget(buildView());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.text('Los geht’s'));
      await tester.pump();

      final handTile = find.byKey(const ValueKey('hand-0'));
      final boardCell = find.byKey(const ValueKey('board-0-0'));
      final gesture = await tester.startGesture(tester.getCenter(handTile));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(boardCell));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump();

      await tester.tap(find.text('Zug senden'));
      await tester.pump();

      // Der Server lehnt den Zug ab (derselbe Snapshot, aber jetzt mit
      // Fehlertext) - da sich `currentPlayerIndex` NICHT geändert hat, darf
      // die vorläufige Platzierung nicht stillschweigend verschwinden.
      await tester.pumpWidget(buildView(errorText: 'Server lehnt den Zug ab'));
      await tester.pump();

      expect(find.text('Server lehnt den Zug ab'), findsOneWidget);
      expect(find.text('Zug senden'), findsOneWidget);
    },
  );
}
