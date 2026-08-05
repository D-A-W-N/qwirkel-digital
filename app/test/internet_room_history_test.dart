import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/net/internet_room_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('internet_room_history', () {
    test('rememberInternetRoom funktioniert auch ohne vorherige Historie', () async {
      // Regression: loadInternetRoomHistory() lieferte bei leerer Historie
      // `const []` zurück - rememberInternetRoom()s removeWhere() darauf
      // warf "Cannot remove from an unmodifiable list" und brach den
      // gesamten Hosting-/Beitritts-Flow ab, bevor der Einladungscode
      // gesetzt wurde.
      await rememberInternetRoom(
        InternetRoomEntry(
          roomCode: 'ABCDE',
          playerName: 'Anna',
          reconnectToken: 'token-1',
          lastSeen: DateTime.now(),
        ),
      );

      final entries = await loadInternetRoomHistory();
      expect(entries, hasLength(1));
      expect(entries.single.roomCode, 'ABCDE');
    });

    test('rememberInternetRoom überschreibt einen bestehenden Eintrag für denselben Raum-Code', () async {
      final first = DateTime.now().subtract(const Duration(days: 1));
      final second = DateTime.now();

      await rememberInternetRoom(
        InternetRoomEntry(
          roomCode: 'ABCDE',
          playerName: 'Anna',
          reconnectToken: 'token-1',
          lastSeen: first,
        ),
      );
      await rememberInternetRoom(
        InternetRoomEntry(
          roomCode: 'ABCDE',
          playerName: 'Anna (neuer Name)',
          reconnectToken: 'token-2',
          lastSeen: second,
        ),
      );

      final entries = await loadInternetRoomHistory();
      expect(entries, hasLength(1));
      expect(entries.single.playerName, 'Anna (neuer Name)');
      expect(entries.single.reconnectToken, 'token-2');
    });

    test('forgetInternetRoom entfernt einen Eintrag, auch als erste Operation', () async {
      // Auch forgetInternetRoom nutzt intern loadInternetRoomHistory() -
      // dieselbe Regression wäre hier ebenso aufgetreten.
      await forgetInternetRoom('irrelevant');
      expect(await loadInternetRoomHistory(), isEmpty);

      await rememberInternetRoom(
        InternetRoomEntry(
          roomCode: 'ABCDE',
          playerName: 'Anna',
          reconnectToken: 'token-1',
          lastSeen: DateTime.now(),
        ),
      );
      await forgetInternetRoom('ABCDE');

      expect(await loadInternetRoomHistory(), isEmpty);
    });

    test('loadInternetRoomHistory sortiert neueste zuerst', () async {
      final older = DateTime.now().subtract(const Duration(days: 2));
      final newer = DateTime.now();

      await rememberInternetRoom(
        InternetRoomEntry(
          roomCode: 'OLD01',
          playerName: 'Anna',
          reconnectToken: 't1',
          lastSeen: older,
        ),
      );
      await rememberInternetRoom(
        InternetRoomEntry(
          roomCode: 'NEW01',
          playerName: 'Anna',
          reconnectToken: 't2',
          lastSeen: newer,
        ),
      );

      final entries = await loadInternetRoomHistory();
      expect(entries.map((e) => e.roomCode), ['NEW01', 'OLD01']);
    });
  });
}
