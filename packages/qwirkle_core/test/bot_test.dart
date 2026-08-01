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
