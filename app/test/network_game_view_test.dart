import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_digital/src/net/network_game_view.dart';
import 'package:qwirkle_net/qwirkle_net.dart';

void main() {
  testWidgets(
    'NetworkGameView zeigt einen übergebenen Status-Text als Toast an, der '
    'von selbst wieder verschwindet',
    (tester) async {
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
            onSendPass: () {},
            onSendExchange: (tiles) {},
            isRoomOwner: false,
            onRestartGame: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Spiel wird synchronisiert'), findsOneWidget);
      // Anders als das vormalige dauerhaft stehende Banner ist das jetzt
      // eine echte SnackBar - die blendet sich, anders als der alte Banner,
      // von selbst wieder aus (eingebaute Dismiss-Logik) - Nutzer-Feedback:
      // "Benachrichtigungen verschwinden nicht während des Spiels".
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  testWidgets(
    'Die Statuszeile nennt beim Warten den Namen der Person, die am Zug ist, '
    'statt einer separaten "Aktueller Zug"-Zeile',
    (tester) async {
      final game = QwirkleGame(players: [
        Player(id: 'p1', name: 'Alice'),
        Player(id: 'p2', name: 'Bob'),
      ]);
      game.currentPlayerIndex = 1;
      final snapshot = GameStateSnapshot.forRecipient(game, 0);
      final hand = snapshot.players[0].hand ?? <Tile>[];

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkGameView(
            snapshot: snapshot,
            ownHand: hand,
            canInteract: false,
            onSendMove: (placements) async => true,
            onSendPass: () {},
            onSendExchange: (tiles) {},
            isRoomOwner: false,
            onRestartGame: () {},
          ),
        ),
      );

      expect(find.text('Warte auf Bob.'), findsOneWidget);
      // Die vormals separate, jetzt redundante Zeile gibt es nicht mehr.
      expect(find.textContaining('Aktueller Zug'), findsNothing);
    },
  );

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
          onSendPass: () {},
          onSendExchange: (tiles) {},
          isRoomOwner: true,
          onRestartGame: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partie beendet'), findsWidgets);
    expect(find.text('Alice gewinnt!'), findsOneWidget);
    expect(find.text('11 Punkte'), findsOneWidget);
    expect(find.text('Neues Spiel'), findsOneWidget);
    // Die Zug-/Tausch-/Aussetzen-Buttons dürfen nach Partie-Ende nicht mehr
    // bedienbar sein - genau der Fehler, den das Overlay beheben sollte.
    expect(find.text('Zug senden'), findsNothing);
    expect(find.text('Steine tauschen…'), findsNothing);
    expect(find.text('Aussetzen'), findsNothing);
  });

  testWidgets(
    'Nur die Person mit Owner-Rechten sieht den Neustart-Button im Partie-Ende-Overlay, '
    'ein Tippen darauf löst onRestartGame aus',
    (tester) async {
      final game = QwirkleGame(players: [
        Player(id: 'p1', name: 'Alice'),
        Player(id: 'p2', name: 'Bob'),
      ]);
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
            onSendPass: () {},
            onSendExchange: (tiles) {},
            isRoomOwner: false,
            onRestartGame: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Neues Spiel'), findsNothing);
      expect(
        find.text('Warte, bis der/die Raumersteller:in eine neue Partie startet.'),
        findsOneWidget,
      );

      var restarted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: NetworkGameView(
            snapshot: snapshot,
            ownHand: hand,
            canInteract: false,
            onSendMove: (placements) async => true,
            onSendPass: () {},
            onSendExchange: (tiles) {},
            isRoomOwner: true,
            onRestartGame: () => restarted = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Neues Spiel'), findsOneWidget);
      // Die Karte kann höher sein als der im Test verfügbare Platz (jetzt
      // per SingleChildScrollView scrollbar statt zu überlaufen) - den
      // Button erst in den sichtbaren Bereich scrollen, bevor er angetippt
      // werden kann.
      await tester.ensureVisible(find.text('Neues Spiel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neues Spiel'));
      expect(restarted, isTrue);
    },
  );

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
          onSendPass: () {},
          onSendExchange: (tiles) {},
          isRoomOwner: false,
          onRestartGame: () {},
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
          onSendPass: () {},
          onSendExchange: (tiles) {},
          isRoomOwner: false,
          onRestartGame: () {},
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
            onSendPass: () {},
            onSendExchange: (tiles) {},
            isRoomOwner: false,
            onRestartGame: () {},
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
      // Nur EIN Stein wurde tatsächlich platziert - das Punktevorschau-Badge
      // würde bei zwei erfolgreich platzierten Steinen anders aussehen.
      expect(find.text('+1 Punkt'), findsOneWidget);
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
          onSendPass: () {},
          onSendExchange: (tiles) {},
          isRoomOwner: false,
          onRestartGame: () {},
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

  testWidgets(
    'Aussetzen ist nur möglich, wenn der Beutel leer ist',
    (tester) async {
      final gameWithFullBag = QwirkleGame(players: [
        Player(id: 'p1', name: 'Alice'),
        Player(id: 'p2', name: 'Bob'),
      ]);
      gameWithFullBag.currentPlayerIndex = 0;
      final snapshotWithFullBag = GameStateSnapshot.forRecipient(gameWithFullBag, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkGameView(
            snapshot: snapshotWithFullBag,
            ownHand: snapshotWithFullBag.players[0].hand ?? <Tile>[],
            canInteract: true,
            onSendMove: (placements) async => true,
            onSendPass: () {},
            onSendExchange: (tiles) {},
            isRoomOwner: false,
            onRestartGame: () {},
          ),
        ),
      );
      expect(find.text('Aussetzen'), findsNothing);

      final gameWithEmptyBag = QwirkleGame(
        players: [Player(id: 'p1', name: 'Alice'), Player(id: 'p2', name: 'Bob')],
        bag: TileBag.fromTiles(const []),
      );
      gameWithEmptyBag.currentPlayerIndex = 0;
      final snapshotWithEmptyBag = GameStateSnapshot.forRecipient(gameWithEmptyBag, 0);

      var passed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: NetworkGameView(
            snapshot: snapshotWithEmptyBag,
            ownHand: snapshotWithEmptyBag.players[0].hand ?? <Tile>[],
            canInteract: true,
            onSendMove: (placements) async => true,
            onSendPass: () => passed = true,
            onSendExchange: (tiles) {},
            isRoomOwner: false,
            onRestartGame: () {},
          ),
        ),
      );

      expect(find.text('Aussetzen'), findsOneWidget);
      await tester.tap(find.text('Aussetzen'));
      expect(passed, isTrue);
    },
  );

  testWidgets(
    'Im Tausch-Modus ausgewählte Steine werden getauscht',
    (tester) async {
      final game = QwirkleGame(players: [
        Player(id: 'p1', name: 'Alice'),
        Player(id: 'p2', name: 'Bob'),
      ]);
      game.currentPlayerIndex = 0;
      final snapshot = GameStateSnapshot.forRecipient(game, 0);
      final hand = snapshot.players[0].hand ?? <Tile>[];

      List<Tile>? exchangedTiles;
      await tester.pumpWidget(
        MaterialApp(
          home: NetworkGameView(
            snapshot: snapshot,
            ownHand: hand,
            canInteract: true,
            onSendMove: (placements) async => true,
            onSendPass: () {},
            onSendExchange: (tiles) => exchangedTiles = tiles,
            isRoomOwner: false,
            onRestartGame: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.text('Los geht’s'));
      await tester.pump();

      await tester.tap(find.text('Steine tauschen…'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('hand-0')));
      await tester.pump();
      await tester.tap(find.text('Steine tauschen'));
      await tester.pump();

      expect(exchangedTiles, [hand[0]]);
      // Der Tausch-Modus wird nach dem Bestätigen wieder verlassen.
      expect(find.text('Steine tauschen…'), findsOneWidget);
    },
  );

  testWidgets(
    'Zeigt eine Zusammenfassung des letzten fremden Zugs als Toast an, aber '
    'nicht für den eigenen',
    (tester) async {
      final game = QwirkleGame(players: [
        Player(id: 'p1', name: 'Alice'),
        Player(id: 'p2', name: 'Bob'),
      ]);
      game.currentPlayerIndex = 0;
      final baseSnapshot = GameStateSnapshot.forRecipient(game, 0);

      Widget buildView(GameStateSnapshot snapshot) => MaterialApp(
        home: NetworkGameView(
          snapshot: snapshot,
          ownHand: baseSnapshot.players[0].hand ?? <Tile>[],
          canInteract: true,
          onSendMove: (placements) async => true,
          onSendPass: () {},
          onSendExchange: (tiles) {},
          isRoomOwner: false,
          onRestartGame: () {},
        ),
      );

      // Erst ohne fremden Zug mounten - der Toast wird über eine ÄNDERUNG
      // ausgelöst (siehe didUpdateWidget), nicht über den Anfangszustand
      // (sonst würde beim Verbinden/Neuladen jedes Mal ein Toast über einen
      // womöglich längst veralteten Zug aus der Vergangenheit erscheinen).
      await tester.pumpWidget(buildView(baseSnapshot));
      await tester.pump();

      final snapshotWithOthersMove = GameStateSnapshot(
        players: baseSnapshot.players,
        currentPlayerIndex: baseSnapshot.currentPlayerIndex,
        bagRemaining: baseSnapshot.bagRemaining,
        isOver: baseSnapshot.isOver,
        board: baseSnapshot.board,
        yourPlayerIndex: baseSnapshot.yourPlayerIndex,
        lastMove: const LastMoveInfo(playerIndex: 1, kind: LastMoveKind.exchanged),
      );
      await tester.pumpWidget(buildView(snapshotWithOthersMove));
      await tester.pump();

      expect(find.text('Bob hat Steine getauscht.'), findsOneWidget);

      final snapshotWithOwnMove = GameStateSnapshot(
        players: baseSnapshot.players,
        currentPlayerIndex: baseSnapshot.currentPlayerIndex,
        bagRemaining: baseSnapshot.bagRemaining,
        isOver: baseSnapshot.isOver,
        board: baseSnapshot.board,
        yourPlayerIndex: baseSnapshot.yourPlayerIndex,
        lastMove: const LastMoveInfo(playerIndex: 0, kind: LastMoveKind.passed),
      );
      await tester.pumpWidget(buildView(snapshotWithOwnMove));
      await tester.pump();

      expect(find.textContaining('hat den Zug übergangen'), findsNothing);
    },
  );

  testWidgets(
    'Ein Neustart der Partie räumt eine noch nicht gesendete Platzierung auf, '
    'statt sie als Geister-Stein auf dem neuen Brett stehen zu lassen',
    (tester) async {
      // Regression: nach "Neues Spiel" landete eine am Ende der vorigen
      // Partie noch nicht gesendete Platzierung als scheinbar schon
      // gesetzter Stein auf dem eigentlich leeren neuen Brett - und beim
      // Zurücknehmen wurde der zugehörige (veraltete) Hand-Index auf die
      // komplett neue Hand angewendet, was einen falschen Stein aus-/wieder
      // einblendete.
      final gameA = QwirkleGame(players: [
        Player(id: 'p1', name: 'Alice'),
        Player(id: 'p2', name: 'Bob'),
      ]);
      gameA.currentPlayerIndex = 0;
      final inProgressSnapshot = GameStateSnapshot.forRecipient(gameA, 0);
      final handA = inProgressSnapshot.players[0].hand ?? <Tile>[];

      Widget buildView(GameStateSnapshot snapshot, List<Tile> hand) =>
          MaterialApp(
            home: NetworkGameView(
              snapshot: snapshot,
              ownHand: hand,
              canInteract: !snapshot.isOver,
              onSendMove: (placements) async => true,
              onSendPass: () {},
              onSendExchange: (tiles) {},
              isRoomOwner: true,
              onRestartGame: () {},
            ),
          );

      await tester.pumpWidget(buildView(inProgressSnapshot, handA));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.text('Los geht’s'));
      await tester.pump();

      // Einen Stein platzieren, aber NICHT senden.
      final handTile = find.byKey(const ValueKey('hand-0'));
      final boardCell = find.byKey(const ValueKey('board-0-0'));
      final gesture = await tester.startGesture(tester.getCenter(handTile));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(boardCell));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump();
      expect(find.text('Zug senden'), findsOneWidget);

      // Die Partie endet, ohne dass der vorbereitete Zug je gesendet wurde.
      final overSnapshot = GameStateSnapshot(
        players: inProgressSnapshot.players,
        currentPlayerIndex: inProgressSnapshot.currentPlayerIndex,
        bagRemaining: inProgressSnapshot.bagRemaining,
        isOver: true,
        board: inProgressSnapshot.board,
        yourPlayerIndex: inProgressSnapshot.yourPlayerIndex,
      );
      await tester.pumpWidget(buildView(overSnapshot, handA));
      await tester.pump();

      // Neustart: komplett frisches Spiel mit unabhängig ausgeteilter Hand.
      final gameB = QwirkleGame(players: [
        Player(id: 'p1', name: 'Alice'),
        Player(id: 'p2', name: 'Bob'),
      ]);
      gameB.currentPlayerIndex = 0;
      final restartedSnapshot = GameStateSnapshot.forRecipient(gameB, 0);
      final handB = restartedSnapshot.players[0].hand ?? <Tile>[];

      await tester.pumpWidget(buildView(restartedSnapshot, handB));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Kein Geister-Stein auf dem neuen, eigentlich leeren Brett - die
      // Zelle ist wieder ein normales Drop-Ziel.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('board-0-0')),
          matching: find.byType(DragTarget<int>),
        ),
        findsOneWidget,
      );
      // Die komplette neue Hand ist sichtbar - keine Lücke durch einen
      // fälschlich als "platziert" markierten (veralteten) Hand-Index.
      for (var i = 0; i < handB.length; i++) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('hand-$i')),
            matching: find.byType(Draggable<int>),
          ),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'Die untere Leiste zeigt die Hand immer sofort an, ohne dass man sie '
    'erst ausklappen müsste',
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
            onSendPass: () {},
            onSendExchange: (tiles) {},
            isRoomOwner: false,
            onRestartGame: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.text('Los geht’s'));
      await tester.pump();

      // Keine Ein-/Ausklapp-Steuerung mehr vorhanden - die Hand ist einfach
      // immer da.
      expect(find.byKey(const ValueKey('hand-0')), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsNothing);
    },
  );

  testWidgets(
    'Ein wegklickbarer Dialog macht es unübersehbar, wenn man selbst am Zug ist',
    (tester) async {
      final game = QwirkleGame(players: [
        Player(id: 'p1', name: 'Alice'),
        Player(id: 'p2', name: 'Bob'),
      ]);
      game.currentPlayerIndex = 1;
      final waitingSnapshot = GameStateSnapshot.forRecipient(game, 0);
      final hand = waitingSnapshot.players[0].hand ?? <Tile>[];

      Widget buildView(GameStateSnapshot snapshot) => MaterialApp(
        home: NetworkGameView(
          snapshot: snapshot,
          ownHand: hand,
          canInteract: true,
          onSendMove: (placements) async => true,
          onSendPass: () {},
          onSendExchange: (tiles) {},
          isRoomOwner: false,
          onRestartGame: () {},
        ),
      );

      await tester.pumpWidget(buildView(waitingSnapshot));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      // Tutorial-Overlay hat selbst einen "Los geht's"-Button - erst
      // wegtippen, damit er später nicht mit dem des Dialogs verwechselt
      // wird (bzw. der Finder nicht mehrdeutig wird).
      await tester.tap(find.text('Los geht’s'));
      await tester.pump();

      // Beim ersten Aufbau (nicht mein Zug) erscheint noch kein Dialog.
      expect(find.text('Du bist am Zug'), findsNothing);

      final myTurnSnapshot = GameStateSnapshot(
        players: waitingSnapshot.players,
        currentPlayerIndex: 0,
        bagRemaining: waitingSnapshot.bagRemaining,
        isOver: waitingSnapshot.isOver,
        board: waitingSnapshot.board,
        yourPlayerIndex: waitingSnapshot.yourPlayerIndex,
      );
      await tester.pumpWidget(buildView(myTurnSnapshot));
      await tester.pump();

      expect(find.text('Du bist am Zug'), findsOneWidget);
      expect(find.text('Du bist jetzt am Zug.'), findsOneWidget);

      await tester.tap(find.text('Los geht’s'));
      await tester.pumpAndSettle();

      expect(find.text('Du bist am Zug'), findsNothing);
    },
  );
}
