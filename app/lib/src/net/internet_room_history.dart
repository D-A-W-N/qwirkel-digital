import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'internetRoomHistory';

/// Ein zuvor besuchter Internet-Raum: hält das Reconnect-Token lokal fest,
/// damit ein Wiederverbinden (App-Neustart, Verbindungsabbruch, Rückkehr
/// nach Tagen) automatisch denselben Sitzplatz zurückfordert statt einen
/// neuen Namen/Code eintippen zu müssen.
class InternetRoomEntry {
  final String roomCode;
  final String playerName;
  final String reconnectToken;
  final DateTime lastSeen;

  /// Ob die Partie in diesem Raum beendet ist (letzter bekannter Stand) -
  /// steuert die "Beendet"-Kennzeichnung in der Raum-Historie, siehe
  /// Nutzer-Feedback "Spiele die beendet sind sollten als diese in der
  /// Historie gekennzeichnet sein".
  final bool isOver;

  const InternetRoomEntry({
    required this.roomCode,
    required this.playerName,
    required this.reconnectToken,
    required this.lastSeen,
    this.isOver = false,
  });

  Map<String, dynamic> toJson() => {
    'roomCode': roomCode,
    'playerName': playerName,
    'reconnectToken': reconnectToken,
    'lastSeen': lastSeen.toIso8601String(),
    'isOver': isOver,
  };

  factory InternetRoomEntry.fromJson(Map<String, dynamic> json) =>
      InternetRoomEntry(
        roomCode: json['roomCode'] as String,
        playerName: json['playerName'] as String,
        reconnectToken: json['reconnectToken'] as String,
        lastSeen: DateTime.parse(json['lastSeen'] as String),
        // Bereits gespeicherte Einträge aus früheren Versionen kennen das
        // Feld noch nicht - dann galt implizit "nicht beendet".
        isOver: json['isOver'] as bool? ?? false,
      );
}

/// Lädt die lokal gespeicherte Liste zuletzt besuchter Internet-Räume,
/// neueste zuerst.
Future<List<InternetRoomEntry>> loadInternetRoomHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw == null) return [];
  final list = jsonDecode(raw) as List<dynamic>;
  final entries = [
    for (final e in list) InternetRoomEntry.fromJson(e as Map<String, dynamic>),
  ];
  entries.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
  return entries;
}

/// Merkt sich [entry] (überschreibt einen evtl. vorhandenen Eintrag mit
/// demselben [InternetRoomEntry.roomCode]) - nach jedem erfolgreichen
/// Beitritt/Reconnect aufrufen, damit [InternetRoomEntry.reconnectToken] und
/// [InternetRoomEntry.lastSeen] aktuell bleiben.
Future<void> rememberInternetRoom(InternetRoomEntry entry) async {
  final prefs = await SharedPreferences.getInstance();
  final entries = await loadInternetRoomHistory();
  entries.removeWhere((e) => e.roomCode == entry.roomCode);
  entries.add(entry);
  await prefs.setString(
    _prefsKey,
    jsonEncode([for (final e in entries) e.toJson()]),
  );
}

Future<void> forgetInternetRoom(String roomCode) async {
  final prefs = await SharedPreferences.getInstance();
  final entries = await loadInternetRoomHistory();
  entries.removeWhere((e) => e.roomCode == roomCode);
  await prefs.setString(
    _prefsKey,
    jsonEncode([for (final e in entries) e.toJson()]),
  );
}
