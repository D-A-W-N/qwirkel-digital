import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'matchHistory';

/// Begrenzt die gespeicherte Liste, damit sie nicht unbegrenzt wächst -
/// analog zur `ROOM_RETENTION_DAYS`-Idee auf Serverseite, nur clientseitig
/// über die Anzahl statt über ein Alter gesteuert.
const _maxEntries = 50;

/// In welcher Betriebsart eine Partie gespielt wurde - steuert nur die
/// Anzeige (Icon/Label) in der Historie.
enum MatchMode { local, lan, internet }

/// Endstand einer einzelnen Person in einer abgeschlossenen Partie.
class MatchPlayerResult {
  const MatchPlayerResult({required this.name, required this.score});

  final String name;
  final int score;

  Map<String, dynamic> toJson() => {'name': name, 'score': score};

  factory MatchPlayerResult.fromJson(Map<String, dynamic> json) =>
      MatchPlayerResult(
        name: json['name'] as String,
        score: json['score'] as int,
      );
}

/// Eine einzelne abgeschlossene Partie - reine Ergebnisliste ohne
/// aggregierte Statistiken (Gewinnquote o. ä.), siehe Punkt 19 der
/// App-Review: die Aggregation wäre ein eigener, größerer Schritt.
class MatchRecord {
  const MatchRecord({
    required this.playedAt,
    required this.mode,
    required this.standings,
    this.roomCode,
  });

  final DateTime playedAt;
  final MatchMode mode;

  /// Nach Punktzahl absteigend sortiert - `standings.first` ist der/die
  /// Sieger:in (bzw. eine/r von mehreren bei Gleichstand).
  final List<MatchPlayerResult> standings;

  /// Nur für `lan`/`internet` gesetzt.
  final String? roomCode;

  Map<String, dynamic> toJson() => {
    'playedAt': playedAt.toIso8601String(),
    'mode': mode.name,
    'standings': [for (final s in standings) s.toJson()],
    if (roomCode != null) 'roomCode': roomCode,
  };

  factory MatchRecord.fromJson(Map<String, dynamic> json) => MatchRecord(
    playedAt: DateTime.parse(json['playedAt'] as String),
    mode: MatchMode.values.firstWhere((m) => m.name == json['mode']),
    standings: [
      for (final s in json['standings'] as List<dynamic>)
        MatchPlayerResult.fromJson(s as Map<String, dynamic>),
    ],
    roomCode: json['roomCode'] as String?,
  );
}

/// Lädt die lokal gespeicherte Partie-Historie, neueste zuerst.
Future<List<MatchRecord>> loadMatchHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw == null) return [];
  final list = jsonDecode(raw) as List<dynamic>;
  final records = [
    for (final e in list) MatchRecord.fromJson(e as Map<String, dynamic>),
  ];
  records.sort((a, b) => b.playedAt.compareTo(a.playedAt));
  return records;
}

/// Hängt [record] vorne an die Historie an und kappt sie auf [_maxEntries]
/// Einträge. Nach jedem Spielende genau einmal aufrufen (siehe die
/// `_gameOverShown`/`isOver`-Übergangs-Guards an den Aufrufstellen).
Future<void> recordMatch(MatchRecord record) async {
  final prefs = await SharedPreferences.getInstance();
  final records = await loadMatchHistory();
  records.insert(0, record);
  final capped = records.take(_maxEntries).toList();
  await prefs.setString(
    _prefsKey,
    jsonEncode([for (final r in capped) r.toJson()]),
  );
}
