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
  void send(String line) => _socket.write(line);

  @override
  Future<void> close() => _socket.close();
}
