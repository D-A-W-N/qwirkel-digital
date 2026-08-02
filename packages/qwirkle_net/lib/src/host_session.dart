import 'dart:async';
import 'dart:io';

import 'package:qwirkle_core/qwirkle_core.dart';

import 'messages.dart';
import 'serialization.dart';
import 'transport.dart';

class _ConnectedClient {
  final MessageTransport transport;
  final String playerId;
  String name;
  int? playerIndex;
  StreamSubscription<String>? subscription;

  _ConnectedClient(this.transport, this.playerId, this.name);

  void send(NetMessage message) => transport.send(message.encode());
}

/// Host-autoritative Netzwerksitzung.
///
/// Transportunabhängig über [MessageTransport]: [start] nimmt TCP-Verbindungen
/// für LAN-Spiele entgegen, [acceptTransport] erlaubt es, beliebige andere
/// Transporte (z. B. künftige WebRTC-DataChannels in Phase 5) anzuschließen,
/// ohne die Sitzungslogik zu ändern. Verwaltet die Warteliste vor Spielstart
/// und validiert/übernimmt eingehende Züge ausschließlich über die reguläre
/// `qwirkle_core`-Engine, bevor der neue (pro Empfänger zugeschnittene)
/// Zustand an alle Clients verteilt wird. Der Host selbst ist immer Spieler
/// mit Index 0.
class HostSession {
  final String hostPlayerName;
  ServerSocket? _serverSocket;
  final List<_ConnectedClient> _clients = [];
  QwirkleGame? _game;
  int _nextClientNumber = 1;

  final _lobbyController = StreamController<LobbyMessage>.broadcast();
  final _stateController = StreamController<void>.broadcast();
  final _gameStartedController = StreamController<bool>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  HostSession({required this.hostPlayerName});

  bool get isGameStarted => _game != null;
  QwirkleGame? get game => _game;
  int get port => _serverSocket?.port ?? 0;

  /// Feuert, wenn sich der autoritative Spielstand ändert (eigener Zug oder
  /// Zug eines Clients) - für die Host-seitige UI.
  Stream<void> get onStateChanged => _stateController.stream;

  /// Feuert, sobald die Partie gestartet wurde.
  Stream<bool> get onGameStarted => _gameStartedController.stream;

  /// Verfügbare Statusmeldungen für die UI.
  Stream<String> get statusUpdates => _statusController.stream;

  /// Fehler aus der Sitzungsschicht.
  Stream<String> get errors => _errorController.stream;

  /// Aktuelle Warteliste (Host + beigetretene Clients) vor Spielstart.
  List<({String id, String name})> get lobbyPlayers => [
    (id: 'host', name: hostPlayerName),
    for (final c in _clients) (id: c.playerId, name: c.name),
  ];

  /// Startet den TCP-Listener. `port: 0` lässt das Betriebssystem einen
  /// freien Port wählen (u. a. praktisch für Tests).
  Future<void> start({String address = '0.0.0.0', int port = 0}) async {
    try {
      _serverSocket = await ServerSocket.bind(address, port);
      _serverSocket!.listen((socket) => acceptTransport(TcpTransport(socket)));
      _statusController.add('Host lauscht auf Port ${_serverSocket!.port}');
    } on SocketException catch (error) {
      _errorController.add('Host konnte nicht gestartet werden: ${error.message}');
      _statusController.add('Host konnte nicht gestartet werden');
      rethrow;
    }
  }

  /// Schließt einen beliebigen [MessageTransport] als neuen Peer an (z. B.
  /// einen TCP-Socket oder künftig einen WebRTC-DataChannel).
  void acceptTransport(MessageTransport transport) {
    final client = _ConnectedClient(
      transport,
      'p${_nextClientNumber++}',
      'Spieler',
    );
    _statusController.add('Neuer Spieler verbunden');
    _clients.add(client);
    client.subscription = transport.lines.listen(
      (line) => _handleLine(client, line),
      onDone: () => _handleDisconnect(client),
      onError: (_) => _handleDisconnect(client),
    );
  }

  void _handleDisconnect(_ConnectedClient client) {
    _clients.remove(client);
    _statusController.add('${client.name} hat die Sitzung verlassen');
    if (_game == null) {
      _broadcastLobby();
    } else {
      _broadcastState();
    }
  }

  void _handleLine(_ConnectedClient client, String line) {
    final message = decodeMessage(line);
    if (message is JoinMessage) {
      client.name = message.name;
      _statusController.add('${client.name} ist der Lobby beigetreten');
      if (_game != null) {
        client.playerIndex = _clients.length;
        client.send(
          GameStateMessage(
            GameStateSnapshot.forRecipient(_game!, client.playerIndex!),
          ),
        );
      }
      client.send(WelcomeMessage(client.playerId));
      _broadcastLobby();
      return;
    }

    final game = _game;
    if (game == null || client.playerIndex == null) return;

    try {
      if (message is MoveMessage) {
        _requireCurrentPlayer(client);
        game.playTiles(message.placements);
        _statusController.add('${client.name} hat einen Zug gespielt');
      } else if (message is ExchangeMessage) {
        _requireCurrentPlayer(client);
        game.exchangeTiles(message.tiles);
        _statusController.add('${client.name} hat Steine getauscht');
      } else if (message is PassMessage) {
        _requireCurrentPlayer(client);
        game.passTurn();
        _statusController.add('${client.name} hat den Zug übergangen');
      } else {
        return;
      }
      _broadcastState();
      _stateController.add(null);
    } on InvalidMoveException catch (e) {
      _errorController.add(e.message);
      client.send(ErrorMessage(e.message));
    } on StateError catch (e) {
      _errorController.add(e.message);
      client.send(ErrorMessage(e.message));
    } on ArgumentError catch (e) {
      final messageText = e.message.toString();
      _errorController.add(messageText);
      client.send(ErrorMessage(messageText));
    }
  }

  void _requireCurrentPlayer(_ConnectedClient client) {
    if (_game!.currentPlayerIndex != client.playerIndex) {
      throw StateError('Du bist gerade nicht am Zug.');
    }
  }

  void _broadcastLobby() {
    final message = LobbyMessage(lobbyPlayers, canStart: _clients.isNotEmpty);
    for (final c in _clients) {
      c.send(message);
    }
    _lobbyController.add(message);
  }

  /// Erstellt die Partie mit dem Host (Index 0) und allen aktuell
  /// verbundenen Clients (in Beitrittsreihenfolge), optional ergänzt um
  /// KI-Spieler:innen, und verteilt den Startzustand.
  QwirkleGame startGame({List<Player> extraBotPlayers = const []}) {
    if (_game != null) {
      throw StateError('Die Partie wurde bereits gestartet.');
    }
    final players = [
      Player(id: 'host', name: hostPlayerName),
      for (final c in _clients) Player(id: c.playerId, name: c.name),
      ...extraBotPlayers,
    ];
    final game = QwirkleGame(players: players);
    _game = game;
    for (var i = 0; i < _clients.length; i++) {
      _clients[i].playerIndex = i + 1;
    }
    _broadcastState();
    _stateController.add(null);
    _gameStartedController.add(true);
    _statusController.add('Die Partie hat begonnen');
    return game;
  }

  void _broadcastState() {
    final game = _game;
    if (game == null) return;
    for (final c in _clients) {
      final index = c.playerIndex;
      if (index == null) continue;
      c.send(GameStateMessage(GameStateSnapshot.forRecipient(game, index)));
    }
  }

  /// Führt einen Zug des Hosts (immer Index 0) aus und verteilt den neuen
  /// Zustand an alle Clients.
  int playHostMove(List<TilePlacement> placements) {
    final score = _game!.playTiles(placements);
    _broadcastState();
    _stateController.add(null);
    return score;
  }

  /// Startet eine neue Partie neu mit denselben Teilnehmern und verteilt den
  /// frischen Zustand an alle Clients.
  void restartGame() {
    if (_game == null) {
      startGame();
      return;
    }

    final players = [
      Player(id: 'host', name: hostPlayerName),
      for (final c in _clients) Player(id: c.playerId, name: c.name),
    ];
    _game = QwirkleGame(players: players);
    for (var i = 0; i < _clients.length; i++) {
      _clients[i].playerIndex = i + 1;
    }
    _broadcastState();
    _stateController.add(null);
    _gameStartedController.add(true);
    _statusController.add('Neue Partie gestartet');
  }

  void exchangeHostTiles(List<Tile> tiles) {
    _game!.exchangeTiles(tiles);
    _broadcastState();
    _stateController.add(null);
  }

  void passHostTurn() {
    _game!.passTurn();
    _broadcastState();
    _stateController.add(null);
  }

  /// Spielstand aus Sicht des Hosts (Index 0) - für die Host-eigene UI.
  GameStateSnapshot? snapshotForHost() {
    final game = _game;
    if (game == null) return null;
    return GameStateSnapshot.forRecipient(game, 0);
  }

  Future<void> close() async {
    for (final c in List.of(_clients)) {
      await c.subscription?.cancel();
      await c.transport.close();
    }
    _clients.clear();
    await _serverSocket?.close();
    await _lobbyController.close();
    await _stateController.close();
    await _gameStartedController.close();
    await _statusController.close();
    await _errorController.close();
  }
}
