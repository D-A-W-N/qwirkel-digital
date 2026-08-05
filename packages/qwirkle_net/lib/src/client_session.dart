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
  final _statusController = StreamController<String>.broadcast();

  GameStateSnapshot? _latestSnapshot;

  /// Vom `qwirkle_server`-Backend zugewiesener Raum-Code (nur beim Verbinden
  /// über [WebSocketTransport] gesetzt) - `null` im LAN-Modus.
  String? roomCode;

  /// Reconnect-Token für diesen Sitzplatz (nur `qwirkle_server`-Backend) -
  /// muss lokal gespeichert und bei einer erneuten [connectVia] als
  /// [reconnectToken]-Argument mitgeschickt werden, um nach einer Trennung
  /// denselben Sitzplatz (inkl. Hand/Punktestand) zurückzufordern.
  String? reconnectToken;

  /// Nur `qwirkle_server`-Backend: ob dieser Sitzplatz die Owner-Rechte im
  /// Raum hat und daher [sendStartGame]/[sendRestartGame] aufrufen darf.
  bool isRoomOwner = false;

  Stream<LobbyMessage> get lobbyUpdates => _lobbyController.stream;
  Stream<GameStateSnapshot> get stateUpdates {
    if (_latestSnapshot == null) {
      return _stateController.stream;
    }
    final controller = StreamController<GameStateSnapshot>.broadcast();
    controller.add(_latestSnapshot!);
    controller.addStream(_stateController.stream);
    return controller.stream;
  }

  Stream<String> get errors => _errorController.stream;
  Stream<String> get statusUpdates => _statusController.stream;
  GameStateSnapshot? get latestSnapshot => _latestSnapshot;

  /// Verbindet sich per TCP mit dem Host unter [host]:[port] und tritt mit
  /// [name] der Lobby bei.
  Future<void> connect(String host, int port, {required String name}) async {
    _statusController.add('Verbinde mit $host:$port');
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      _statusController.add('Verbindung aufgebaut');
      await connectVia(TcpTransport(socket), name: name);
    } on SocketException catch (error) {
      _errorController.add('Verbindung fehlgeschlagen: ${error.message}');
      _statusController.add('Verbindung fehlgeschlagen');
      rethrow;
    } on TimeoutException catch (error) {
      _errorController.add('Verbindung abgebrochen: ${error.message}');
      _statusController.add('Verbindung abgebrochen');
      rethrow;
    }
  }

  /// Tritt über einen beliebigen bereits verbundenen [transport] der Lobby
  /// bei. [roomCode]/[reconnectToken] sind nur für das `qwirkle_server`-
  /// Backend relevant (`null` erstellt dort einen neuen Raum, ein
  /// vorhandenes [reconnectToken] fordert einen zuvor verlassenen
  /// Sitzplatz zurück) - `HostSession` (LAN) ignoriert beide.
  Future<void> connectVia(
    MessageTransport transport, {
    required String name,
    String? roomCode,
    String? reconnectToken,
  }) async {
    _transport = transport;
    _subscription = transport.lines.listen(
      _handleLine,
      onDone: _handleDisconnect,
      onError: (_) => _handleDisconnect(),
    );
    _statusController.add('Tritt der Lobby bei');
    transport.send(
      JoinMessage(
        name,
        roomCode: roomCode,
        reconnectToken: reconnectToken,
      ).encode(),
    );
    await _welcomeController.stream.first;
    _statusController.add('Lobby-Beitritt bestätigt');
  }

  /// Feuert, wenn der Transport ohne aktives [close] endet (z. B. der Host
  /// ist abgestürzt oder die Verbindung wurde unterbrochen) — ohne das würde
  /// die UI einfach auf dem letzten Stand einfrieren, ohne jede Rückmeldung.
  void _handleDisconnect() {
    _errorController.add('Verbindung zum Host verloren.');
    _statusController.add('Verbindung zum Host verloren');
  }

  void _handleLine(String line) {
    final message = decodeMessage(line);
    if (message is WelcomeMessage) {
      roomCode = message.roomCode;
      reconnectToken = message.reconnectToken;
      isRoomOwner = message.isOwner;
      _welcomeController.add(message.playerId);
    } else if (message is LobbyMessage) {
      _statusController.add('Lobby aktualisiert');
      _lobbyController.add(message);
    } else if (message is GameStateMessage) {
      _latestSnapshot = message.snapshot;
      _statusController.add('Spielstand aktualisiert');
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

  /// Nur `qwirkle_server`-Backend: fordert als Raumersteller:in den
  /// Spielstart an (`HostSession` startet im LAN-Modus stattdessen lokal
  /// über `HostSession.startGame()`).
  void sendStartGame() {
    _transport!.send(StartGameMessage().encode());
  }

  /// Nur `qwirkle_server`-Backend: fordert als Raumersteller:in einen
  /// Partie-Neustart an (`HostSession` startet im LAN-Modus stattdessen
  /// lokal über `HostSession.restartGame()`).
  void sendRestartGame() {
    _transport!.send(RestartGameMessage().encode());
  }

  Future<void> close() async {
    await _subscription?.cancel();
    await _transport?.close();
    await _lobbyController.close();
    await _stateController.close();
    await _errorController.close();
    await _welcomeController.close();
    await _statusController.close();
  }
}
