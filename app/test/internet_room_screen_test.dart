import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/net/internet_room_screen.dart';
import 'package:qwirkle_digital/src/net/room_connection_manager.dart';
import 'package:qwirkle_server/qwirkle_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('InternetRoomScreen', () {
    late GameServer server;
    late RoomConnectionManager manager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      server = GameServer(
        dataDir: Directory.systemTemp.createTempSync('internet_room_screen_test_'),
      );
      await server.start(address: '127.0.0.1', port: 0);
      manager = RoomConnectionManager();
    });

    tearDown(() async {
      // `manager` wird NICHT hier disposed: die Provider-Override im Test
      // übergibt die Instanz an den ProviderContainer, der sie beim
      // Widget-Teardown bereits selbst disposed (ChangeNotifierProvider mit
      // `disposeNotifier: true`, Standard) - ein zweiter Aufruf hier würde
      // gegen ein bereits disposed ChangeNotifier laufen.
      await server.close();
    });

    testWidgets(
      'Der Kopieren-Button legt den Einladungscode in die Zwischenablage und '
      'bestätigt das mit einer Meldung',
      (tester) async {
        // Ohne expliziten Mock-Handler löst `Clipboard.setData` in dieser
        // Testumgebung nie auf (kein Standard-Handler für
        // `SystemChannels.platform` aktiv) - der Aufruf bliebe sonst für
        // immer hängen, ohne Fehler oder Timeout.
        String? copiedText;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        // `testWidgets` läuft in einer FakeAsync-Zone mit kontrollierter
        // Zeit - eine echte Netzwerkverbindung (WebSocket zum lokalen
        // Test-Server) braucht dagegen den echten Event-Loop, sonst hängt
        // der `await` hier für immer.
        final roomCode = (await tester.runAsync(() async {
          final entry = await manager.createInternetRoom(
            serverUrl: 'ws://127.0.0.1:${server.port}',
            playerName: 'Anna',
          );
          return entry.roomCode!;
        }))!;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              roomConnectionManagerProvider.overrideWith((ref) => manager),
            ],
            child: MaterialApp(
              home: InternetRoomScreen.existingRoom(roomCode: roomCode),
            ),
          ),
        );
        await tester.pump();

        expect(find.text(roomCode), findsOneWidget);

        await tester.tap(find.byIcon(Icons.copy));
        await tester.pump();

        expect(copiedText, roomCode);
        expect(find.text('Einladungscode kopiert'), findsOneWidget);
      },
    );
  });
}
