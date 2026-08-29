import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/history/match_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadMatchHistory ist anfangs leer', () async {
    expect(await loadMatchHistory(), isEmpty);
  });

  test(
    'recordMatch/loadMatchHistory sind ein Roundtrip, neueste zuerst',
    () async {
      await recordMatch(
        MatchRecord(
          playedAt: DateTime(2026, 1, 1),
          mode: MatchMode.local,
          standings: const [
            MatchPlayerResult(name: 'Anna', score: 30),
            MatchPlayerResult(name: 'Ben', score: 20),
          ],
        ),
      );
      await recordMatch(
        MatchRecord(
          playedAt: DateTime(2026, 1, 2),
          mode: MatchMode.internet,
          roomCode: 'ABCD',
          standings: const [MatchPlayerResult(name: 'Carla', score: 45)],
        ),
      );

      final history = await loadMatchHistory();
      expect(history, hasLength(2));
      // Neueste zuerst.
      expect(history[0].mode, MatchMode.internet);
      expect(history[0].roomCode, 'ABCD');
      expect(history[0].standings.single.name, 'Carla');
      expect(history[1].mode, MatchMode.local);
      expect(history[1].standings.map((s) => s.name), ['Anna', 'Ben']);
    },
  );

  test('recordMatch kappt die Historie auf die letzten 50 Einträge', () async {
    for (var i = 0; i < 55; i++) {
      await recordMatch(
        MatchRecord(
          playedAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
          mode: MatchMode.local,
          standings: [MatchPlayerResult(name: 'Spieler $i', score: i)],
        ),
      );
    }

    final history = await loadMatchHistory();
    expect(history, hasLength(50));
    // Die neuesten 50 (i = 5..54) bleiben erhalten, die ältesten 5 fallen weg.
    expect(history.first.standings.single.name, 'Spieler 54');
    expect(history.last.standings.single.name, 'Spieler 5');
  });
}
