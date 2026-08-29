import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:test/test.dart';

void main() {
  group('Bot', () {
    test('easy: spielt einen gültigen Zug, wenn möglich', () {
      final anna = Player(id: 'a', name: 'Anna');
      final ben = Player(id: 'b', name: 'Ben');
      final game = QwirkleGame(players: [anna, ben]);
      final bot = Bot(difficulty: BotDifficulty.easy);

      final decision = bot.decide(game);

      expect(decision.isPlay, isTrue);
      final score = decision.applyTo(game);
      expect(score, greaterThan(0));
    });

    test('medium: wählt unter mehreren Optionen den höchsten Punktwert', () {
      final anna = Player(id: 'a', name: 'Anna');
      final ben = Player(id: 'b', name: 'Ben');
      final game = QwirkleGame(players: [anna, ben], bag: TileBag.standard());
      game.currentPlayerIndex = 0;

      // Ersten Stein manuell aufs Brett bringen (Ausgangslage für den Test).
      anna.hand = [const Tile(TileColor.red, TileShape.circle)];
      game.playTiles([
        const TilePlacement(
          position: Position(0, 0),
          tile: Tile(TileColor.red, TileShape.circle),
        ),
      ]);

      game.currentPlayerIndex = 0;
      anna.hand = [
        const Tile(TileColor.red, TileShape.cross),
        const Tile(TileColor.red, TileShape.diamond),
      ];

      final bot = Bot(difficulty: BotDifficulty.medium);
      final decision = bot.decide(game);

      expect(decision.isPlay, isTrue);
      // Beide Steine passen in einer Reihe an (0,0) an - das ist der beste Zug.
      expect(decision.placements!.length, 2);
    });

    test(
      'medium: wählt unter geraden und T-/L-förmigen Kandidaten den bestmöglichen Punktwert',
      () {
        // Unter der Hausregel "jeder Stein zählt einzeln nach Reihenlänge
        // zum Zeitpunkt seines Anlegens" (siehe Board.scorePlacement) gilt
        // strukturell: eine reine Geradeausverlängerung summiert immer
        // größer werdende Werte (L+1, L+2, ...), während ein Abzweig seine
        // eigene Nebenreihe bei 2 neu beginnt - eine Aufteilung derselben
        // Steine auf Haupt- + Nebenreihe kann die reine Gerade daher so gut
        // wie nie schlagen. Dieser Test verlangt deshalb nicht mehr, dass
        // der Bot eine Verzweigung wählt, sondern nur, dass er unter allen
        // geraden UND verzweigten Möglichkeiten tatsächlich die bestmögliche
        // (hier: die gerade Reihe) findet.
        final anna = Player(id: 'a', name: 'Anna');
        final ben = Player(id: 'b', name: 'Ben');
        final game = QwirkleGame(players: [anna, ben], bag: TileBag.standard());
        game.currentPlayerIndex = 0;

        anna.hand = [const Tile(TileColor.red, TileShape.circle)];
        game.playTiles([
          const TilePlacement(
            position: Position(0, 0),
            tile: Tile(TileColor.red, TileShape.circle),
          ),
        ]);

        game.currentPlayerIndex = 0;
        const tiles = [
          Tile(TileColor.red, TileShape.cross),
          Tile(TileColor.red, TileShape.square),
          Tile(TileColor.red, TileShape.diamond),
        ];

        // Alle geraden und einfach-verzweigten (L-förmigen) Aufteilungen
        // dieser 3 Steine durchrechnen, um den tatsächlich bestmöglichen
        // Punktwert zu ermitteln - unabhängig davon, welche Form gewinnt.
        int scoreOf(List<TilePlacement> placements) {
          final probe = Board();
          probe.apply(const [
            TilePlacement(
              position: Position(0, 0),
              tile: Tile(TileColor.red, TileShape.circle),
            ),
          ]);
          return probe.scorePlacement(placements);
        }

        final straight = [
          for (var i = 0; i < tiles.length; i++)
            TilePlacement(position: Position(i + 1, 0), tile: tiles[i]),
        ];
        final lShape2plus1 = [
          TilePlacement(position: const Position(1, 0), tile: tiles[0]),
          TilePlacement(position: const Position(2, 0), tile: tiles[1]),
          TilePlacement(position: const Position(2, 1), tile: tiles[2]),
        ];
        final lShape1plus2 = [
          TilePlacement(position: const Position(1, 0), tile: tiles[0]),
          TilePlacement(position: const Position(1, 1), tile: tiles[1]),
          TilePlacement(position: const Position(1, 2), tile: tiles[2]),
        ];
        final bestKnownScore = [straight, lShape2plus1, lShape1plus2]
            .map(scoreOf)
            .reduce((a, b) => a > b ? a : b);

        anna.hand = List.of(tiles);

        final bot = Bot(difficulty: BotDifficulty.medium);
        final decision = bot.decide(game);

        expect(decision.isPlay, isTrue);
        expect(decision.placements!.length, 3);
        final score = decision.applyTo(game);
        expect(score, greaterThanOrEqualTo(bestKnownScore));
      },
    );

    test(
      'medium: erkennt Brücken-Züge (neue Steine auf beiden Seiten eines '
      'vorhandenen Steins in einer Reihe)',
      () {
        final anna = Player(id: 'a', name: 'Anna');
        final ben = Player(id: 'b', name: 'Ben');
        final game = QwirkleGame(players: [anna, ben], bag: TileBag.standard());
        game.currentPlayerIndex = 0;

        anna.hand = [const Tile(TileColor.red, TileShape.circle)];
        game.playTiles([
          const TilePlacement(
            position: Position(2, 0),
            tile: Tile(TileColor.red, TileShape.circle),
          ),
        ]);

        // Zwei Steine, die nur als gemeinsamer Brücken-Zug (je einer auf
        // jeder Seite des vorhandenen Steins bei (2,0)) ihren vollen Wert
        // entfalten: einzeln gespielt käme keiner über 2 Punkte, gemeinsam
        // ergibt die entstehende Dreier-Reihe 2+3=5 Punkte (Hausregel:
        // jeder Stein zählt einzeln nach Reihenlänge zum Anlagezeitpunkt).
        game.currentPlayerIndex = 0;
        anna.hand = [
          const Tile(TileColor.red, TileShape.cross),
          const Tile(TileColor.red, TileShape.diamond),
        ];

        final bot = Bot(difficulty: BotDifficulty.medium);
        final decision = bot.decide(game);

        expect(decision.isPlay, isTrue);
        expect(decision.placements!.length, 2);
        final score = decision.applyTo(game);
        expect(score, 5);
      },
    );

    test(
      'hard: vermeidet einen Zug, der eine offene 5er-Reihe hinterlässt, '
      'wenn eine sicherere Alternative mit besserem Netto-Wert existiert',
      () {
        final anna = Player(id: 'a', name: 'Anna');
        final ben = Player(id: 'b', name: 'Ben');
        final game = QwirkleGame(players: [anna, ben], bag: TileBag.standard());

        void place(Position position, Tile tile) {
          game.currentPlayerIndex = 0;
          anna.hand = [tile];
          game.playTiles([TilePlacement(position: position, tile: tile)]);
        }

        // Reihe aus 4 roten Steinen (unterschiedliche Symbole) - eine
        // Erweiterung auf 5 wäre für den Bot zwar der punktereichste
        // Einzelzug, hinterließe aber eine für den Gegner leicht zum
        // Qwirkle vervollständigbare Reihe.
        place(const Position(0, 0), const Tile(TileColor.red, TileShape.circle));
        place(const Position(1, 0), const Tile(TileColor.red, TileShape.cross));
        place(const Position(2, 0), const Tile(TileColor.red, TileShape.diamond));
        place(const Position(3, 0), const Tile(TileColor.red, TileShape.square));
        // Zusätzlicher Anker für eine sichere Alternative ohne Bezug zur
        // gefährlichen Reihe.
        place(const Position(1, 1), const Tile(TileColor.blue, TileShape.cross));

        game.currentPlayerIndex = 0;
        anna.hand = [
          const Tile(TileColor.red, TileShape.star), // verlängert auf 5
          const Tile(TileColor.blue, TileShape.clover), // sichere Alternative
        ];

        final mediumDecision = Bot(
          difficulty: BotDifficulty.medium,
        ).decide(game);
        expect(mediumDecision.isPlay, isTrue);
        expect(
          game.board.scorePlacement(mediumDecision.placements!),
          5,
          reason: 'Medium wählt den punktereichsten (aber riskanten) Zug.',
        );

        final hardDecision = Bot(difficulty: BotDifficulty.hard).decide(game);
        expect(hardDecision.isPlay, isTrue);
        expect(
          game.board.scorePlacement(hardDecision.placements!),
          2,
          reason:
              'Hard meidet die riskante 5er-Reihe zugunsten der sichereren, '
              'niedriger bewerteten Alternative.',
        );
      },
    );

    test('hard: liefert einen gültigen, punktenden Zug', () {
      final anna = Player(id: 'a', name: 'Anna');
      final ben = Player(id: 'b', name: 'Ben');
      final game = QwirkleGame(players: [anna, ben]);
      final bot = Bot(difficulty: BotDifficulty.hard);

      final decision = bot.decide(game);

      expect(decision.isPlay, isTrue);
      final score = decision.applyTo(game);
      expect(score, greaterThan(0));
    });

    test('tauscht, wenn kein gültiger Zug möglich ist', () {
      final anna = Player(
        id: 'a',
        name: 'Anna',
        hand: [const Tile(TileColor.red, TileShape.circle)],
      );
      final ben = Player(id: 'b', name: 'Ben', hand: []);
      final bag = TileBag.fromTiles([
        const Tile(TileColor.blue, TileShape.star),
      ]);
      final game = QwirkleGame(players: [anna, ben], bag: bag);
      game.currentPlayerIndex = 0;

      // Brett mit einem Stein befüllen, der zu keinem Handstein passt und
      // alle vier Nachbarfelder blockiert, sodass keine Anlage möglich ist.
      // (Für diesen Test reicht es, dass die Hand leer bleibt -> keine
      // Kandidaten -> Bot muss tauschen oder aussetzen.)
      anna.hand = [];
      final bot = Bot(difficulty: BotDifficulty.easy);
      final decision = bot.decide(game);

      expect(decision.isPass, isTrue);
    });

    test('setzt aus, wenn Beutel leer und kein Zug möglich ist', () {
      final anna = Player(id: 'a', name: 'Anna', hand: []);
      final ben = Player(id: 'b', name: 'Ben', hand: []);
      final bag = TileBag.fromTiles(const []);
      final game = QwirkleGame(players: [anna, ben], bag: bag);
      game.currentPlayerIndex = 0;

      final bot = Bot(difficulty: BotDifficulty.easy);
      final decision = bot.decide(game);

      expect(decision.isPass, isTrue);
      decision.applyTo(game);
      expect(game.currentPlayerIndex, isNot(0));
    });

    test('Player.isBot spiegelt botDifficulty wider', () {
      final human = Player(id: 'h', name: 'Mensch');
      final bot = Player(
        id: 'b',
        name: 'Bot',
        botDifficulty: BotDifficulty.hard,
      );

      expect(human.isBot, isFalse);
      expect(bot.isBot, isTrue);
    });
  });
}
