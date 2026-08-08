import 'dart:async';
import 'dart:math';

import 'messages.dart';
import 'room_session.dart';
import 'transport.dart';

/// Verwaltet mehrere [RoomSession]s auf einem gemeinsamen Server-Prozess
/// (`qwirkle_server`): nimmt Transporte entgegen, liest deren erste
/// Nachricht (muss ein [JoinMessage] sein) und routet anhand von
/// [JoinMessage.roomCode] entweder in einen neu erstellten oder einen
/// bestehenden Raum.
///
/// Kennt bewusst nur [MessageTransport], keine WebSocket-/HTTP-Details -
/// der eigentliche Verbindungsaufbau (`HttpServer`/`WebSocketTransformer`)
/// bleibt Sache des Aufrufers, analog zu `SignalingServer`s Trennung von
/// Verbindungsaufbau und Raum-Logik.
class RoomManager {
  final Map<String, RoomSession> _rooms = {};
  final Random _random = Random.secure();

  /// Aufgerufen, wenn sich der Zustand eines Raums ändert (neu erstellt,
  /// Beitritt, Zug, ...) - für Persistenz auf Platte (`qwirkle_server`).
  final void Function(RoomSession room)? onRoomChanged;

  RoomManager({this.onRoomChanged});

  Iterable<RoomSession> get rooms => _rooms.values;

  RoomSession? room(String roomCode) => _rooms[roomCode];

  /// Fügt einen zuvor persistierten Raum wieder ein (z. B. beim Start von
  /// `qwirkle_server`, aus auf Platte gespeicherten Räumen).
  void addRestoredRoom(RoomSession room) {
    room.onChanged = () => onRoomChanged?.call(room);
    _rooms[room.roomCode] = room;
  }

  void removeRoom(String roomCode) => _rooms.remove(roomCode);

  /// Nimmt einen neu verbundenen [transport] entgegen und wartet auf dessen
  /// erste Nachricht, um ihn an den richtigen Raum weiterzureichen.
  void acceptTransport(MessageTransport transport) {
    StreamSubscription<String>? subscription;
    subscription = transport.lines.listen((line) {
      unawaited(subscription?.cancel());
      _handleFirstLine(transport, line);
    }, onError: (_) => transport.close());
  }

  void _handleFirstLine(MessageTransport transport, String line) {
    final NetMessage message;
    try {
      message = decodeMessage(line);
    } on FormatException {
      unawaited(transport.close());
      return;
    }
    if (message is! JoinMessage) {
      transport.send(ErrorMessage('Erwarte eine Beitrittsanfrage.').encode());
      unawaited(transport.close());
      return;
    }
    _route(transport, message);
  }

  void _route(MessageTransport transport, JoinMessage message) {
    final requestedCode = message.roomCode;
    RoomSession room;
    if (requestedCode == null) {
      final code = _generateRoomCode();
      room = RoomSession(roomCode: code, roomName: message.roomName);
      room.onChanged = () => onRoomChanged?.call(room);
      _rooms[code] = room;
    } else {
      final existing = _rooms[requestedCode];
      if (existing == null) {
        transport.send(
          ErrorMessage('Unbekannter oder abgelaufener Raum-Code.').encode(),
        );
        unawaited(transport.close());
        return;
      }
      room = existing;
    }
    room.handleJoin(transport, message);
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String code;
    do {
      code = List.generate(
        5,
        (_) => chars[_random.nextInt(chars.length)],
      ).join();
    } while (_rooms.containsKey(code));
    return code;
  }
}
