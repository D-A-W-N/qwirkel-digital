import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
// `ChangeNotifierProvider` ist in Riverpod 3 "legacy" API und nicht mehr aus
// dem Haupt-Barrel exportiert.
import 'package:flutter_riverpod/legacy.dart';
import 'package:qwirkle_net/qwirkle_net.dart';

import 'internet_room_history.dart';

/// Live-Zustand einer einzelnen, aktuell vom [RoomConnectionManager]
/// gehaltenen Internet-Raum-Verbindung - fasst zusammen, was vorher als
/// einzelne `State`-Felder in `NetworkGameScreen` lag, jetzt aber die
/// zugehörige Screen-Instanz überleben muss.
class RoomConnectionEntry {
  RoomConnectionEntry({
    required this.session,
    required this.serverUrl,
    required this.playerName,
  });

  /// Nicht `final`: ein Reconnect ersetzt die Session (neuer Socket), ohne
  /// dass Aufrufer:innen ihre Referenz auf diesen [RoomConnectionEntry]
  /// verlieren - siehe [RoomConnectionManager._reconnect].
  ClientSession session;
  final String serverUrl;
  final String playerName;

  String? roomCode;
  String? roomName;
  String? status;

  /// Getrennt von [status]: siehe `NetworkGameScreen._errorText` für die
  /// ursprüngliche Begründung (auffällige, rote Anzeige statt Untergehen in
  /// der neutralen Statuszeile).
  String? errorText;
  bool reconnecting = false;
  List<({String id, String name})> lobbyPlayers = const [];
  GameStateSnapshot? snapshot;

  bool get isGameStarted => snapshot != null;
  bool get isRoomOwner => session.isRoomOwner;
}

/// App-weiter, app-root-verankerter Verbindungsmanager für Internet-Räume:
/// hält Sessions über Navigation hinweg am Leben, statt sie (wie vorher in
/// `NetworkGameScreen`) an den Lebenszyklus eines einzelnen Screens zu
/// binden. Das erlaubt echtes paralleles Verbundensein mit mehreren Räumen -
/// Nutzer-Feedback: Partien können sich über Tage ziehen, während man in der
/// Zwischenzeit auch in anderen Räumen mitspielen will.
///
/// LAN-Sitzungen (`HostSession`/`ClientSession` ohne Server) bleiben bewusst
/// außen vor und bei `NetworkGameScreen` (screen-gebunden) - Parallelbetrieb
/// ergibt für Vor-Ort-Partien in derselben Sitzung keinen Mehrwert.
class RoomConnectionManager extends ChangeNotifier {
  final Map<String, RoomConnectionEntry> _rooms = {};
  String? _foregroundRoomCode;
  bool _disposed = false;

  final _turnNotifications = StreamController<String>.broadcast();

  /// Wie [notifyListeners], aber verträglich mit spät eintreffenden
  /// Session-Ereignissen (Disconnect/Reconnect-Retry laufen asynchron
  /// weiter) NACH [dispose] - ohne diesen Schutz wirft `ChangeNotifier`
  /// dann eine `used after being disposed`-Exception.
  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final entry in _rooms.values) {
      entry.reconnecting = false;
      unawaited(entry.session.close());
    }
    unawaited(_turnNotifications.close());
    super.dispose();
  }

  /// Feuert mit dem jeweiligen Raum-Code, sobald diese Person dort am Zug
  /// ist, während ein ANDERER Raum (oder gar keiner) im Vordergrund ist -
  /// siehe [setForegroundRoom].
  Stream<String> get turnNotifications => _turnNotifications.stream;

  List<RoomConnectionEntry> get rooms => List.unmodifiable(_rooms.values);

  RoomConnectionEntry? entryFor(String? roomCode) =>
      roomCode == null ? null : _rooms[roomCode];

  /// Von der jeweils sichtbaren `NetworkGameScreen`/`InternetRoomScreen`
  /// aufgerufen (`initState`/`dispose`) - steuert, für welchen Raum KEINE
  /// Zug-Benachrichtigung nötig ist, weil er ohnehin gerade angezeigt wird.
  void setForegroundRoom(String? roomCode) {
    _foregroundRoomCode = roomCode;
  }

  /// Erstellt einen neuen Internet-Raum. Wirft weiter, wenn die Verbindung
  /// fehlschlägt (Aufrufer zeigt den Fehler an, siehe bisheriges Verhalten
  /// in `NetworkGameScreen._initializeSession`).
  Future<RoomConnectionEntry> createInternetRoom({
    required String serverUrl,
    required String playerName,
    String roomName = '',
  }) async {
    final session = ClientSession();
    final entry = RoomConnectionEntry(
      session: session,
      serverUrl: serverUrl,
      playerName: playerName,
    );
    _wireListeners(entry);
    final socket = await WebSocket.connect(serverUrl);
    await session.connectVia(
      WebSocketTransport(socket),
      name: playerName,
      roomName: roomName.isEmpty ? null : roomName,
    );
    entry.roomCode = session.roomCode;
    entry.roomName = session.roomName;
    entry.status =
        'Raum "${session.roomName}" erstellt – Einladungscode: '
        '${session.roomCode}';
    _rooms[entry.roomCode!] = entry;
    await _rememberSession(entry);
    _safeNotify();
    return entry;
  }

  /// Tritt einem bestehenden Internet-Raum bei - oder liefert, falls diese
  /// Person bereits (in dieser Sitzung) live mit ihm verbunden ist, direkt
  /// den bestehenden Eintrag zurück, statt einen zweiten Socket für
  /// denselben Sitzplatz zu öffnen (der Server erwartet pro Sitzplatz genau
  /// eine Verbindung).
  Future<RoomConnectionEntry> joinInternetRoom({
    required String serverUrl,
    required String playerName,
    required String roomCode,
    String? reconnectToken,
  }) async {
    final existing = _rooms[roomCode];
    if (existing != null) return existing;

    final session = ClientSession();
    final entry = RoomConnectionEntry(
      session: session,
      serverUrl: serverUrl,
      playerName: playerName,
    );
    _wireListeners(entry);
    entry.status = 'Verbinde mit dem Raum...';
    final socket = await WebSocket.connect(serverUrl);
    await session.connectVia(
      WebSocketTransport(socket),
      name: playerName,
      roomCode: roomCode,
      reconnectToken: reconnectToken,
    );
    entry.roomCode = session.roomCode ?? roomCode;
    entry.roomName = session.roomName;
    final latest = session.latestSnapshot;
    if (latest != null) {
      entry.snapshot = latest;
    }
    _rooms[entry.roomCode!] = entry;
    await _rememberSession(entry, isOver: latest?.isOver ?? false);
    _safeNotify();
    return entry;
  }

  /// Verlässt [roomCode] endgültig: schließt die Verbindung, entfernt sie
  /// aus diesem Manager UND aus der dauerhaften Raum-Historie - anders als
  /// bloßes Wegnavigieren (das die Session jetzt unangetastet lässt) die
  /// einzige Aktion, die den Sitzplatz wirklich aufgibt.
  Future<void> leaveRoom(String roomCode) async {
    final entry = _rooms.remove(roomCode);
    if (entry == null) return;
    entry.reconnecting = false;
    await entry.session.close();
    await forgetInternetRoom(roomCode);
    _safeNotify();
  }

  void _wireListeners(RoomConnectionEntry entry) {
    final session = entry.session;
    session.statusUpdates.listen((message) {
      entry.status = message;
      _safeNotify();
    });
    session.lobbyUpdates.listen((message) {
      entry.lobbyPlayers = message.players;
      entry.status = 'Lobby aktualisiert';
      _safeNotify();
    });
    session.stateUpdates.listen((snapshot) {
      final wasMyTurn =
          entry.snapshot != null &&
          entry.snapshot!.currentPlayerIndex == entry.snapshot!.yourPlayerIndex;
      entry.snapshot = snapshot;
      entry.errorText = null;
      entry.status = 'Spielzustand empfangen (${snapshot.players.length} Spieler)';

      final isMyTurnNow = snapshot.currentPlayerIndex == snapshot.yourPlayerIndex;
      if (!_disposed &&
          isMyTurnNow &&
          !wasMyTurn &&
          !snapshot.isOver &&
          entry.roomCode != null &&
          entry.roomCode != _foregroundRoomCode) {
        _turnNotifications.add(entry.roomCode!);
      }

      _safeNotify();
      unawaited(_rememberSession(entry, isOver: snapshot.isOver));
    });
    session.errors.listen((message) {
      entry.errorText = message;
      _safeNotify();
    });
    session.disconnected.listen((_) {
      if (!_disposed && entry.roomCode != null) {
        unawaited(_attemptReconnect(entry));
      }
    });
  }

  /// Wie das frühere `NetworkGameScreen._attemptReconnect`: versucht mit
  /// wachsendem Abstand, denselben Sitzplatz zurückzuerobern, und gibt nie
  /// endgültig auf - ein Deploy kann unterschiedlich lange dauern, und
  /// mehrtägige Verbindungsausfälle sind bei dieser App ohnehin normal.
  Future<void> _attemptReconnect(RoomConnectionEntry entry) async {
    if (entry.reconnecting) return;
    entry.reconnecting = true;
    entry.errorText = 'Verbindung verloren – versuche erneut zu verbinden…';
    _safeNotify();

    var attempt = 0;
    while (entry.reconnecting && entry.roomCode != null) {
      // Zwischenzeitlich per `leaveRoom` entfernt oder der Manager wurde
      // beendet - nicht weiterversuchen.
      if (_disposed || _rooms[entry.roomCode] != entry) return;
      attempt += 1;
      try {
        await _reconnect(entry);
        entry.reconnecting = false;
        entry.errorText = null;
        entry.status = 'Wieder verbunden';
        _safeNotify();
        return;
      } catch (_) {
        final delaySeconds = attempt * 2 > 15 ? 15 : attempt * 2;
        entry.errorText =
            'Verbindung verloren – nächster Versuch in ${delaySeconds}s…';
        _safeNotify();
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }

  Future<void> _reconnect(RoomConnectionEntry entry) async {
    final roomCode = entry.roomCode;
    if (roomCode == null) throw StateError('Kein Raum-Code bekannt.');
    final newSession = ClientSession();
    final socket = await WebSocket.connect(entry.serverUrl);
    final history = await loadInternetRoomHistory();
    final saved = history.where((e) => e.roomCode == roomCode);
    await newSession.connectVia(
      WebSocketTransport(socket),
      name: entry.playerName,
      roomCode: roomCode,
      reconnectToken: saved.isEmpty ? null : saved.first.reconnectToken,
    );
    final oldSession = entry.session;
    entry.session = newSession;
    _wireListeners(entry);
    final latest = newSession.latestSnapshot;
    if (latest != null) {
      entry.snapshot = latest;
    }
    unawaited(_rememberSession(entry, isOver: latest?.isOver ?? false));
    unawaited(oldSession.close());
  }

  /// Wie das frühere `NetworkGameScreen._rememberSession`: hält die lokale
  /// Raum-Historie mit dem tatsächlichen Partie-Zustand synchron.
  Future<void> _rememberSession(
    RoomConnectionEntry entry, {
    bool isOver = false,
  }) async {
    final roomCode = entry.session.roomCode;
    final token = entry.session.reconnectToken;
    if (roomCode == null || token == null) return;
    await rememberInternetRoom(
      InternetRoomEntry(
        roomCode: roomCode,
        playerName: entry.playerName,
        reconnectToken: token,
        lastSeen: DateTime.now(),
        isOver: isOver,
        roomName: entry.session.roomName,
        playerNames: [
          for (final name
              in entry.snapshot != null
                  ? [for (final p in entry.snapshot!.players) p.name]
                  : [for (final p in entry.lobbyPlayers) p.name])
            if (name != entry.playerName) name,
        ],
      ),
    );
  }
}

final roomConnectionManagerProvider = ChangeNotifierProvider<RoomConnectionManager>(
  (ref) => RoomConnectionManager(),
);
