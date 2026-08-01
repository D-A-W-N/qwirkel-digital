import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'signaling_messages.dart';

class _Peer {
  final String id;
  final WebSocket socket;
  String? roomCode;

  _Peer(this.id, this.socket);
}

class _Room {
  final String code;
  final List<_Peer> peers = [];

  _Room(this.code);
}

/// Minimaler, selbst hostbarer Signaling-Server für den WebRTC-
/// Verbindungsaufbau: erstellt/verwaltet Räume (per Einladungscode) und
/// leitet SDP-/ICE-Nachrichten zwischen den Peers eines Raums weiter.
///
/// Der Server sieht dabei NIEMALS Spieldaten - nach erfolgreichem WebRTC-
/// Verbindungsaufbau laufen Züge direkt P2P über einen DataChannel
/// (`WebRtcTransport`). Läuft rein auf `dart:io` (`HttpServer` +
/// `WebSocketTransformer`), keine externen Abhängigkeiten.
class SignalingServer {
  HttpServer? _httpServer;
  final Map<String, _Room> _rooms = {};
  int _nextPeerNumber = 1;
  final Random _random = Random.secure();

  int get port => _httpServer?.port ?? 0;

  /// Startet den Server. `port: 0` lässt das Betriebssystem einen freien
  /// Port wählen (praktisch für Tests).
  Future<void> start({String address = '0.0.0.0', int port = 0}) async {
    final server = await HttpServer.bind(address, port);
    _httpServer = server;
    server.listen((request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        _handlePeer(socket);
      } else {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('Nur WebSocket-Verbindungen werden unterstützt.')
          ..close();
      }
    });
  }

  void _handlePeer(WebSocket socket) {
    final peer = _Peer('peer${_nextPeerNumber++}', socket);
    socket.listen(
      (data) => _handleMessage(peer, data as String),
      onDone: () => _handleDisconnect(peer),
      onError: (_) => _handleDisconnect(peer),
    );
  }

  void _handleMessage(_Peer peer, String raw) {
    final message = decodeSignalingMessage(raw);
    if (message is CreateRoomMessage) {
      final room = _Room(_generateRoomCode());
      _rooms[room.code] = room;
      room.peers.add(peer);
      peer.roomCode = room.code;
      peer.socket.add(RoomCreatedMessage(room.code, peer.id).encode());
      return;
    }
    if (message is JoinRoomMessage) {
      final room = _rooms[message.roomCode];
      if (room == null) {
        peer.socket.add(RoomErrorMessage('Unbekannter Raum-Code.').encode());
        return;
      }
      final existingIds = room.peers.map((p) => p.id).toList();
      room.peers.add(peer);
      peer.roomCode = room.code;
      peer.socket.add(RoomJoinedMessage(peer.id, existingIds).encode());
      for (final other in room.peers) {
        if (other.id != peer.id) {
          other.socket.add(PeerJoinedMessage(peer.id).encode());
        }
      }
      return;
    }

    final targetId = _targetPeerIdOf(message);
    if (targetId == null) return;
    final room = _rooms[peer.roomCode];
    if (room == null) return;
    for (final target in room.peers) {
      if (target.id == targetId) {
        target.socket.add(raw);
        return;
      }
    }
  }

  String? _targetPeerIdOf(SignalingMessage message) {
    if (message is SdpOfferMessage) return message.targetPeerId;
    if (message is SdpAnswerMessage) return message.targetPeerId;
    if (message is IceCandidateMessage) return message.targetPeerId;
    return null;
  }

  void _handleDisconnect(_Peer peer) {
    final room = _rooms[peer.roomCode];
    if (room == null) return;
    room.peers.removeWhere((p) => p.id == peer.id);
    for (final other in room.peers) {
      other.socket.add(PeerLeftMessage(peer.id).encode());
    }
    if (room.peers.isEmpty) {
      _rooms.remove(room.code);
    }
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

  Future<void> close() async {
    for (final room in List.of(_rooms.values)) {
      for (final peer in List.of(room.peers)) {
        await peer.socket.close();
      }
    }
    _rooms.clear();
    await _httpServer?.close(force: true);
  }
}
