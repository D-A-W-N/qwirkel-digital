import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/net/internet_room_history.dart';
import 'package:qwirkle_digital/src/net/my_rooms_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Zeigt einen Hinweis, wenn noch keine Räume bekannt sind', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MyRoomsScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Noch keine Internet-Räume'), findsOneWidget);
  });

  testWidgets(
    'Zeigt einen History-Raum mit Code und Status, öffnet ihn per Tap',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await rememberInternetRoom(
        InternetRoomEntry(
          roomCode: 'ABCDE',
          playerName: 'Anna',
          reconnectToken: 'token-1',
          lastSeen: DateTime.now(),
          roomName: 'Samstagsrunde',
        ),
      );

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: MyRoomsScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Samstagsrunde'), findsOneWidget);
      expect(
        find.textContaining('Nicht verbunden – tippen zum Verbinden'),
        findsOneWidget,
      );
      expect(find.textContaining('Code: ABCDE'), findsOneWidget);

      // Kein `pumpAndSettle`: der Tap löst einen echten (in diesem Test
      // nicht beantworteten) Verbindungsversuch aus, der nie von selbst zur
      // Ruhe kommt - ein einzelnes `pump` reicht, um die Navigation zu sehen.
      await tester.tap(find.text('Samstagsrunde'));
      await tester.pump(); // Tap verarbeiten, Navigation auslösen.
      await tester.pump(const Duration(milliseconds: 300)); // Push-Übergang.

      // Löst einen Verbindungsversuch aus - der InternetRoomScreen wurde
      // darüber gepusht (die alte Route bleibt im Baum, nur nicht mehr
      // oben).
      expect(find.text('Internet-Spiel'), findsOneWidget);
    },
  );

  testWidgets('Beendete History-Räume werden entsprechend beschriftet', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await rememberInternetRoom(
      InternetRoomEntry(
        roomCode: 'FGHIJ',
        playerName: 'Anna',
        reconnectToken: 'token-2',
        lastSeen: DateTime.now(),
        isOver: true,
      ),
    );

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MyRoomsScreen())),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Beendet – tippen zum erneuten Öffnen'),
      findsOneWidget,
    );
  });
}
