import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/net/network_connection_config.dart';
import 'package:qwirkle_digital/src/net/network_game_screen.dart';

void main() {
  group('NetworkGameScreen (LAN)', () {
    testWidgets(
      'Hosten startet einen HostSession und zeigt den zugewiesenen Port an',
      (tester) async {
        final config = NetworkConnectionConfig(
          mode: 'lan',
          isHosting: true,
          host: '',
          // Ein unüblicher fester Port statt 0: `NetworkConnectionConfig`
          // lehnt "0" als ungültig ab (dort für Nutzereingaben gedacht,
          // nicht für "beliebigen freien Port"), anders als ein roher
          // Socket-Bind.
          port: '19283',
          name: 'Anna',
          serverUrl: '',
          inviteCode: '',
        );

        // `HostSession.start` (ausgelöst bereits in `initState`, noch
        // während `pumpWidget`) bindet einen echten TCP-Socket - das braucht
        // den echten Event-Loop, nicht die FakeAsync-Zone von `testWidgets`,
        // sonst löst der Aufruf nie auf.
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(home: NetworkGameScreen(config: config)),
          );
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();

        // Nicht auf den exakten Wortlaut prüfen: `HostSession.start()`s
        // eigenes "Host lauscht auf Port ..."-Status-Event und
        // `_startHosting()`s abschließendes "Host läuft auf Port ..."
        // können je nach Microtask-Reihenfolge das jeweils letzte sein -
        // beide bestätigen denselben Erfolg.
        expect(find.textContaining('auf Port 19283'), findsOneWidget);
        expect(find.text('Anna'), findsOneWidget);
        expect(find.text('Spiel starten'), findsOneWidget);
      },
    );

    testWidgets(
      'Ein leerer Name wird als verständliche Fehlermeldung angezeigt',
      (tester) async {
        final config = NetworkConnectionConfig(
          mode: 'lan',
          isHosting: true,
          host: '',
          port: '19283',
          name: '',
          serverUrl: '',
          inviteCode: '',
        );

        await tester.pumpWidget(
          MaterialApp(home: NetworkGameScreen(config: config)),
        );
        await tester.pump();

        expect(
          find.textContaining('Bitte gib einen Namen ein.'),
          findsOneWidget,
        );
      },
    );
  });
}
