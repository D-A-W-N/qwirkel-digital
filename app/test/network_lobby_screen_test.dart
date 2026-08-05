import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/net/network_lobby_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'internetRoomHistory':
          '['
          '{"roomCode":"AAAAA","playerName":"Anna","reconnectToken":"t1",'
          '"lastSeen":"${DateTime.now().toIso8601String()}","isOver":false},'
          '{"roomCode":"BBBBB","playerName":"Anna","reconnectToken":"t2",'
          '"lastSeen":"${DateTime.now().toIso8601String()}","isOver":true}'
          ']',
    });
  });

  testWidgets(
    'Beendete Räume sind in der Historie gekennzeichnet und lassen sich entfernen',
    (tester) async {
      // Die Räume stehen weit unten in einer langen ListView - im
      // Standard-Testviewport (800x600) würden die zugehörigen Sliver-
      // Kinder ohne Scrollen gar nicht erst gebaut. Ein großer Viewport
      // vermeidet das Scrollen und hält den Test einfach.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: NetworkLobbyScreen()),
        ),
      );
      // Das Laden der Historie (SharedPreferences) läuft asynchron im
      // initState - erst danach steht sie im Widget-Baum.
      await tester.pumpAndSettle();
      // Der Umschalter auf "Internet" blendet die Raum-Historie erst ein.
      await tester.tap(find.text('Internet'));
      await tester.pumpAndSettle();

      expect(find.text('AAAAA'), findsOneWidget);
      expect(find.text('BBBBB'), findsOneWidget);
      // Nur der beendete Raum (BBBBB) bekommt die "Beendet"-Kennzeichnung.
      expect(find.text('Beendet'), findsOneWidget);

      // Den beendeten Raum aus der Historie entfernen ("ausblendbar").
      final dismissButtons = find.byIcon(Icons.close);
      expect(dismissButtons, findsNWidgets(2));
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('BBBBB'),
            matching: find.byType(Card),
          ),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BBBBB'), findsNothing);
      expect(find.text('AAAAA'), findsOneWidget);
    },
  );
}
