import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_digital/src/game/game_controller.dart';

void main() {
  test('stageTile blockiert Zugpositionen, die eine Lücke in der Kette erzeugen', () {
    final game = QwirkleGame(players: [Player(id: 'p1', name: 'Anna')]);
    final controller = GameController(game);

    game.currentPlayer.hand = [
      const Tile(TileColor.red, TileShape.circle),
      const Tile(TileColor.red, TileShape.cross),
    ];
    game.board.apply([
      TilePlacement(
        position: const Position(0, 0),
        tile: const Tile(TileColor.red, TileShape.diamond),
      ),
    ]);

    controller.stageTile(0, const Position(1, 0));
    expect(controller.pendingPlacements, hasLength(1));

    controller.stageTile(1, const Position(3, 0));

    expect(controller.pendingPlacements, hasLength(1));
    expect(controller.lastError, isNotNull);
    expect(controller.lastError, contains('lückenlos'));
  });

  test('unstageTile löscht eine veraltete Fehlermeldung einer vorherigen fehlgeschlagenen Platzierung', () {
    final game = QwirkleGame(players: [Player(id: 'p1', name: 'Anna')]);
    final controller = GameController(game);

    game.currentPlayer.hand = [
      const Tile(TileColor.red, TileShape.circle),
      const Tile(TileColor.red, TileShape.cross),
    ];
    game.board.apply([
      TilePlacement(
        position: const Position(0, 0),
        tile: const Tile(TileColor.red, TileShape.diamond),
      ),
    ]);

    controller.stageTile(0, const Position(1, 0));
    controller.stageTile(1, const Position(3, 0)); // schlägt fehl (Lücke bei 2,0)
    expect(controller.lastError, isNotNull);

    // Der Zug wird abgebrochen: der einzige vorläufige Stein wird zurückgenommen.
    controller.unstageTile(const Position(1, 0));

    expect(controller.pendingPlacements, isEmpty);
    expect(
      controller.lastError,
      isNull,
      reason:
          'Nach dem Zurücknehmen darf keine Fehlermeldung mehr angezeigt werden, '
          'die sich auf den bereits verworfenen Versuch bezieht.',
    );
  });

  test('pendingScore zeigt den Punktwert des vorbereiteten Zugs live an', () {
    final game = QwirkleGame(players: [Player(id: 'p1', name: 'Anna')]);
    final controller = GameController(game);

    game.currentPlayer.hand = [
      const Tile(TileColor.red, TileShape.circle),
      const Tile(TileColor.red, TileShape.cross),
    ];
    game.board.apply([
      TilePlacement(
        position: const Position(0, 0),
        tile: const Tile(TileColor.red, TileShape.diamond),
      ),
    ]);

    expect(controller.pendingScore, isNull);

    controller.stageTile(0, const Position(1, 0));
    expect(controller.pendingScore, 2); // Reihe: diamond + circle

    controller.stageTile(1, const Position(2, 0));
    // Hausregel: jeder neue Stein zählt einzeln nach Reihenlänge zum
    // Zeitpunkt seines Anlegens - circle bei Länge 2, cross bei Länge 3.
    expect(controller.pendingScore, 5); // 2 (diamond+circle) + 3 (+cross)

    controller.unstageTile(const Position(2, 0));
    expect(controller.pendingScore, 2);

    controller.unstageTile(const Position(1, 0));
    expect(controller.pendingScore, isNull);
  });

  test(
    'stageTile benachrichtigt Listener auch bei einer fehlgeschlagenen Platzierung',
    () {
      // Regression: die UI hört per ChangeNotifier zu (ref.watch) - ohne
      // notifyListeners() im Fehlerfall bleibt lastError zwar gesetzt, aber
      // der Bildschirm baut nie neu, sodass der Fehler unsichtbar bleibt und
      // eine fehlgeschlagene Platzierung wie ein stillschweigend hängender
      // Bug wirkt (Nutzer-Feedback: "konnte keinen anderen Stein platzieren,
      // scheint mir ein Bug").
      final game = QwirkleGame(players: [Player(id: 'p1', name: 'Anna')]);
      final controller = GameController(game);

      game.currentPlayer.hand = [
        const Tile(TileColor.red, TileShape.circle),
        const Tile(TileColor.red, TileShape.cross),
      ];
      game.board.apply([
        TilePlacement(
          position: const Position(0, 0),
          tile: const Tile(TileColor.red, TileShape.diamond),
        ),
      ]);

      controller.stageTile(0, const Position(1, 0));

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      // Lücke bei (2,0) -> schlägt fehl.
      controller.stageTile(1, const Position(3, 0));

      expect(controller.lastError, isNotNull);
      expect(
        notifyCount,
        greaterThan(0),
        reason:
            'notifyListeners() muss auch bei InvalidMoveException aufgerufen '
            'werden, sonst erfährt die UI nie von der Fehlermeldung.',
      );
    },
  );

  test(
    'playBotTurn füllt lastBotSummary/lastBotPlacements, die eigene Reaktion löscht sie wieder',
    () {
      final bot = Player(
        id: 'b',
        name: 'BotAnna',
        botDifficulty: BotDifficulty.easy,
      );
      final human = Player(id: 'h', name: 'Ben');
      final game = QwirkleGame(players: [bot, human]);
      game.currentPlayerIndex = 0; // Bot ist dran (Starthand entscheidet sonst zufällig).
      final controller = GameController(game);

      expect(controller.lastBotSummary, isNull);
      expect(controller.lastBotPlacements, isEmpty);

      controller.playBotTurn();

      expect(controller.lastBotSummary, isNotNull);
      expect(controller.lastBotSummary, contains('BotAnna'));
      expect(controller.lastBotPlacements, isNotEmpty);

      // Sobald die Gegenseite reagiert (hier: aussetzt), ist die
      // Zusammenfassung des Bot-Zugs nicht mehr relevant und wird geleert.
      controller.passTurn();

      expect(controller.lastBotSummary, isNull);
      expect(controller.lastBotPlacements, isEmpty);
    },
  );
}
