import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/net/lobby_widgets.dart';

void main() {
  group('LobbyPlayerList', () {
    testWidgets('zeigt einen Platzhalter, wenn noch niemand da ist', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LobbyPlayerList(players: [])),
        ),
      );

      expect(find.text('Noch keine Teilnehmer'), findsOneWidget);
    });

    testWidgets(
      'zeigt jede Person mit Wartesymbol, solange allReady falsch ist',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LobbyPlayerList(
                players: [(id: 'a', name: 'Anna'), (id: 'b', name: 'Ben')],
              ),
            ),
          ),
        );

        expect(find.text('Anna'), findsOneWidget);
        expect(find.text('Ben'), findsOneWidget);
        expect(find.byIcon(Icons.pending), findsNWidgets(2));
        expect(find.byIcon(Icons.play_circle_fill), findsNothing);
      },
    );

    testWidgets('zeigt das Start-Symbol, sobald allReady wahr ist', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LobbyPlayerList(
              players: [(id: 'a', name: 'Anna')],
              allReady: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
      expect(find.byIcon(Icons.pending), findsNothing);
    });
  });

  group('LobbyActionButtons', () {
    testWidgets(
      'zeigt den Start-Button nur, wenn Owner-Rechte bestehen und die '
      'Partie noch nicht läuft',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LobbyActionButtons(
                hasOwnerControls: true,
                gameStarted: false,
                onStartGame: () {},
                onBack: () {},
              ),
            ),
          ),
        );

        expect(find.text('Spiel starten'), findsOneWidget);
        expect(find.text('Zurück zur Lobby'), findsOneWidget);
      },
    );

    testWidgets('versteckt den Start-Button, wenn die Partie schon läuft', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LobbyActionButtons(
              hasOwnerControls: true,
              gameStarted: true,
              onStartGame: () {},
              onBack: () {},
            ),
          ),
        ),
      );

      expect(find.text('Spiel starten'), findsNothing);
    });

    testWidgets('rendert eine optionale Zusatzaktion darunter', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LobbyActionButtons(
              hasOwnerControls: false,
              gameStarted: false,
              onStartGame: () {},
              onBack: () {},
              backLabel: 'Zurück (Verbindung bleibt bestehen)',
              additionalAction: const Text('Raum verlassen'),
            ),
          ),
        ),
      );

      expect(
        find.text('Zurück (Verbindung bleibt bestehen)'),
        findsOneWidget,
      );
      expect(find.text('Raum verlassen'), findsOneWidget);
    });
  });
}
