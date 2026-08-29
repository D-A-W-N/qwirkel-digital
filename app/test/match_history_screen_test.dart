import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/history/match_history.dart';
import 'package:qwirkle_digital/src/history/match_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Zeigt einen Hinweis an, wenn noch keine Partie gespeichert ist',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MatchHistoryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Noch keine abgeschlossene Partie.'), findsOneWidget);
    },
  );

  testWidgets('Zeigt gespeicherte Partien mit Platzierung und Punkten an', (
    tester,
  ) async {
    await recordMatch(
      MatchRecord(
        playedAt: DateTime(2026, 3, 5, 14, 30),
        mode: MatchMode.local,
        standings: const [
          MatchPlayerResult(name: 'Anna', score: 30),
          MatchPlayerResult(name: 'Ben', score: 20),
        ],
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: MatchHistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Lokal'), findsOneWidget);
    expect(find.text('1. Anna: 30 Punkte'), findsOneWidget);
    expect(find.text('2. Ben: 20 Punkte'), findsOneWidget);
  });
}
