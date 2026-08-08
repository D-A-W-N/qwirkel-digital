import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Abstrakter Nachrichten-Transport zu genau einem Peer: eine Zeile pro
/// Nachricht (siehe `NetMessage.encode()`).
///
/// TCP-Sockets (LAN, [TcpTransport]) und künftig WebRTC-DataChannels
/// (Phase 5, Internet-Mehrspieler) implementieren dieselbe Schnittstelle,
/// sodass die Host-/Client-Sitzungslogik in [HostSession]/[ClientSession]
/// vollständig transportunabhängig bleibt.
abstract class MessageTransport {
  Stream<String> get lines;

  void send(String line);

  Future<void> close();
}

/// TCP-Socket-basierter Transport für LAN-Spiele.
class TcpTransport implements MessageTransport {
  final Socket _socket;
  late final Stream<String> _lines;

  TcpTransport(this._socket) {
    _lines = _socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }

  @override
  Stream<String> get lines => _lines;

  @override
  void send(String line) {
    // Best-effort: der Peer kann die Verbindung genau zwischen unserem
    // letzten Zustands-Check und diesem Aufruf beendet haben (z. B. beim
    // Broadcast an alle Sitzplätze direkt nach einer Trennung). Der
    // Empfang der eigentlichen Trennung läuft ohnehin separat über
    // `onDone`/`onError` des Sockets - ein fehlgeschlagener Sendeversuch
    // darf den Aufrufer (`RoomSession._broadcastState` u. Ä.) nicht mit
    // einer unbehandelten Ausnahme abreißen lassen.
    try {
      _socket.write(line);
    } on SocketException {
      // Ignorieren - siehe oben.
    }
  }

  @override
  Future<void> close() => _socket.close();
}

/// WebSocket-basierter Transport für Internet-Spiele über den dedizierten
/// Server (`qwirkle_server`). Kein Zeilen-Framing nötig wie bei
/// [TcpTransport]: jede WebSocket-Textnachricht ist bereits eine
/// eigenständige Einheit, die genau einer [NetMessage] entspricht.
///
/// [lines] ist bewusst ein Broadcast-Stream (statt den Socket-Stream direkt
/// durchzureichen wie [TcpTransport]): `RoomManager` liest die allererste
/// Nachricht, um den richtigen Raum zu ermitteln, bevor `RoomSession` ab der
/// zweiten Nachricht selbst zuhört - ein reiner Socket-Stream erlaubt aber
/// nur genau ein `listen()` über seine gesamte Lebensdauer, selbst nach
/// `cancel()` eines vorherigen Listeners.
class WebSocketTransport implements MessageTransport {
  final WebSocket _socket;
  late final StreamSubscription<dynamic> _socketSubscription;
  final _linesController = StreamController<String>.broadcast();

  WebSocketTransport(this._socket) {
    _socketSubscription = _socket.listen(
      (data) => _linesController.add(data as String),
      onDone: _linesController.close,
      onError: _linesController.addError,
    );
  }

  @override
  Stream<String> get lines => _linesController.stream;

  @override
  void send(String line) {
    // Best-effort - siehe dieselbe Begründung bei TcpTransport.send: der
    // WebSocket kann zwischen Zustands-Check und Sendeversuch bereits
    // geschlossen worden sein (z. B. beim Broadcast direkt nach einer
    // Trennung), was `StreamSink`-intern als `StateError` auffliegt statt
    // als `SocketException`.
    try {
      _socket.add(line);
    } on StateError {
      // Ignorieren - siehe oben.
    }
  }

  @override
  Future<void> close() async {
    await _socketSubscription.cancel();
    await _socket.close();
    await _linesController.close();
  }
}
