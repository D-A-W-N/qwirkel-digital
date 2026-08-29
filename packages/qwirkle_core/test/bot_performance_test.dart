import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:test/test.dart';

void main() {
  group('Bot performance', () {
    test(
      '"hard" bleibt über eine ganze Bot-gegen-Bot-Partie hinweg schnell '
      'genug für einen einzelnen Zug',
      () {
        // Regression guard, kein Mikrobenchmark: ein komplettes
        // Selbstspiel (statt eines künstlich konstruierten Boards) lässt
        // das Brett organisch wachsen - realistischer für die Frage, ob
        // die neuen Brücken-/Verzweigungszüge auf einem "natürlichen",
        // typischerweise weit verzweigten Brett zu spürbar langsameren
        // Entscheidungen führen.
        //
        // Per manuellem Profiling (5 Durchläufe, siehe PR-Beschreibung):
        // einzelne "hard"-Entscheidungen lagen bei Brettgrößen von 60-100
        // Steinen zwischen ~190ms und ~620ms - spürbar, aber nicht
        // dramatisch, und meist innerhalb der ohnehin konfigurierten
        // Bot-Geschwindigkeits-Pause (100-1500ms). Bekannte, aber bewusst
        // zurückgestellte Optimierungsmöglichkeit: `_tryScore` fängt
        // `InvalidMoveException` in einer heißen, durch die neue
        // Verzweigungssuche vergrößerten Schleife ab - Exceptions als
        // Kontrollfluss sind in Dart nicht kostenlos. Der Schwellenwert
        // hier ist bewusst großzügig (deutlich über dem beobachteten
        // Maximum), um echte Regressionen zu fangen, ohne bei normaler
        // Varianz zwischen CI-Läufen flakey zu sein.
        final anna = Player(id: 'a', name: 'Anna', botDifficulty: BotDifficulty.hard);
        final ben = Player(id: 'b', name: 'Ben', botDifficulty: BotDifficulty.hard);
        final game = QwirkleGame(players: [anna, ben], bag: TileBag.standard());

        var maxMs = 0;
        var sawLargeBoard = false;

        while (!game.isOver) {
          if (game.board.cells.length > 40) sawLargeBoard = true;
          final bot = Bot(difficulty: BotDifficulty.hard);
          final stopwatch = Stopwatch()..start();
          final decision = bot.decide(game);
          stopwatch.stop();
          if (stopwatch.elapsedMilliseconds > maxMs) {
            maxMs = stopwatch.elapsedMilliseconds;
          }
          decision.applyTo(game);
        }

        expect(
          sawLargeBoard,
          isTrue,
          reason: 'Testaufbau lieferte kein hinreichend großes Brett.',
        );
        expect(
          maxMs,
          lessThan(5000),
          reason:
              'Die langsamste "hard"-Entscheidung dieser Partie brauchte '
              '${maxMs}ms - deutlich über dem beobachteten Normalbereich '
              '(~200-600ms), das deutet auf eine echte Regression hin.',
        );
      },
    );
  });
}
