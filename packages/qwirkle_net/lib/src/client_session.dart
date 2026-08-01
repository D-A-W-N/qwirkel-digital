import 'dart:async';
import 'dart:io';

import 'package:qwirkle_core/qwirkle_core.dart';

import 'messages.dart';
import 'serialization.dart';
import 'transport.dart';

/// Client-seitige Netzwerksitzung: verbindet sich zu einem [HostSession],
/// tritt der Lobby bei und sendet Zug-Wünsche. Der Client hält keine
/// eigene autoritative [QwirkleGame]-Instanz - der jeweils aktuelle Stand
/// kommt ausschließlich per [stateUpdates] vom Host.
///
/// Transportunabhängig über [MessageTransport]: [connect] verbindet sich per
/// TCP (LAN), [connectVia] akzeptiert einen beliebigen anderen Transport
/// (z. B. einen künftigen WebRTC-DataChannel in Phase 5).
class ClientSession {
  MessageTransport? _transport;
  StreamSubscription<String>? _subscription;

  final _lobbyController = StreamController<LobbyMessage>.broadcast();
  final _stateController = StreamController<GameStateSnapshot>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _welcomeController = StreamController<String>.broadcast();

  Stream<LobbyMessage> get lobbyUpdates => _lobbyController.stream;
  Stream<GameStateSnapshot> get stateUpdates => _stateController.stream;
  Stream<String> get errors => _errorController.stream;

  /// Verbindet sich per TCP mit dem Host unter [host]:[port] und tritt mit
  /// [name] der Lobby bei.
  Future<void> connect(String host, int port, {required String name}) async {
    final socket = await Socket.connect(host, port);
    await connectVia(TcpTransport(socket), name: name);
  }

  /// Tritt über einen beliebigen bereits verbundenen [transport] der Lobby
  /// bei.
  Future<void> connectVia(
    MessageTransport transport, {
    required String name,
  }) async {
    _transport = transport;
    _subscription = transport.lines.listen(_handleLine);
    transport.send(JoinMessage(name).encode());
    await _welcomeController.stream.first;
  }

  void _handleLine(String line) {
    final message = decodeMessage(line);
    if (message is WelcomeMessage) {
      _welcomeController.add(message.playerId);
    } else if (message is LobbyMessage) {
      _lobbyController.add(message);
    } else if (message is GameStateMessage) {
      _stateController.add(message.snapshot);
    } else if (message is ErrorMessage) {
      _errorController.add(message.message);
    }
  }

  void sendMove(List<TilePlacement> placements) {
    _transport!.send(MoveMessage(placements).encode());
  }

  void sendExchange(List<Tile> tiles) {
    _transport!.send(ExchangeMessage(tiles).encode());
  }

  void sendPass() {
    _transport!.send(PassMessage().encode());
  }

  Future<void> close() async {
    await _subscription?.cancel();
    await _transport?.close();
    await _lobbyController.close();
    await _stateController.close();
    await _errorController.close();
    await _welcomeController.close();
  }
}
