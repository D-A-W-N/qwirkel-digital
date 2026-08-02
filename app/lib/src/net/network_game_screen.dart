import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_net/qwirkle_net.dart';

import 'network_connection_config.dart';
import 'network_game_view.dart';
import 'webrtc_transport.dart';

class NetworkGameScreen extends StatefulWidget {
  const NetworkGameScreen({super.key, required this.config});

  final NetworkConnectionConfig config;

  @override
  State<NetworkGameScreen> createState() => _NetworkGameScreenState();
}

class _NetworkGameScreenState extends State<NetworkGameScreen> {
  HostSession? _hostSession;
  ClientSession? _clientSession;
  SignalingServer? _signalingServer;
  SignalingClient? _signalingClient;
  StreamSubscription<PeerJoinedMessage>? _peerJoinedSubscription;
  final List<WebRtcConnection> _webrtcConnections = [];
  String? _inviteCode;
  String? _status;
  List<({String id, String name})> _lobbyPlayers = const [];
  bool _isInitializing = true;
  bool _gameStarted = false;
  GameStateSnapshot? _snapshot;
  List<Tile> _ownHand = const [];

  bool get _isLan => widget.config.mode == 'lan';

  @override
  void initState() {
    super.initState();
    unawaited(_initializeSession());
  }

  Future<void> _initializeSession() async {
    try {
      if (widget.config.effectiveName.isEmpty) {
        throw ArgumentError('Bitte gib einen Namen ein.');
      }

      if (widget.config.isHosting) {
        setState(() {
          _status = _isLan
              ? 'Host wird gestartet...'
              : 'Internet-Host wird vorbereitet...';
        });
        await _startHosting();
      } else {
        setState(() {
          _status = _isLan
              ? 'Verbinde mit dem Host...'
              : 'Verbinde über Internet...';
        });
        await _joinSession();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = 'Fehler: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _startHosting() async {
    final host = HostSession(hostPlayerName: widget.config.effectiveName);
    _wireHostListeners(host);

    if (_isLan) {
      await host.start(address: '0.0.0.0', port: widget.config.effectivePort);
    } else {
      await _startInternetSignaling(host);
    }

    _hostSession = host;
    final initialSnapshot = host.snapshotForHost();
    if (mounted && initialSnapshot != null) {
      setState(() {
        _snapshot = initialSnapshot;
        _ownHand = initialSnapshot.players[initialSnapshot.yourPlayerIndex].hand ?? const <Tile>[];
        _status = 'Host-Zustand aktualisiert';
      });
    }
    if (!mounted) return;
    setState(() {
      _status = _isLan
          ? 'Host läuft auf Port ${host.port}'
          : 'Host läuft – Einladungscode: $_inviteCode';
      _lobbyPlayers = host.lobbyPlayers;
      _gameStarted = false;
    });
  }

  void _wireHostListeners(HostSession host) {
    host.statusUpdates.listen((message) {
      if (!mounted) return;
      setState(() => _status = message);
    });
    host.errors.listen((message) {
      if (!mounted) return;
      setState(() => _status = 'Fehler: $message');
    });
    host.onStateChanged.listen((_) {
      if (!mounted) return;
      final snapshot = host.snapshotForHost();
      if (snapshot == null) return;
      setState(() {
        _snapshot = snapshot;
        _ownHand = snapshot.players[snapshot.yourPlayerIndex].hand ?? const <Tile>[];
        _status = 'Host-Zustand aktualisiert';
      });
    });
    host.onGameStarted.listen((started) {
      if (!mounted) return;
      setState(() {
        _gameStarted = started;
        if (started) {
          _status = 'Spiel gestartet';
        }
      });
    });
  }

  /// Startet einen eigenen [SignalingServer] und verbindet einen
  /// [SignalingClient] gegen die eigene Adresse, um einen Raum zu erstellen.
  /// Die erreichbare Signaling-URL muss der Host selbst mit den Mitspieler:
  /// innen teilen (z. B. per Chat) — für echte Verbindungen über getrennte
  /// Netzwerke hinweg muss diese Adresse von außen erreichbar sein
  /// (Portweiterleitung, oder ein selbst betriebener öffentlicher
  /// Signaling-Server statt `localhost`).
  Future<void> _startInternetSignaling(HostSession host) async {
    final server = SignalingServer();
    await server.start(address: '0.0.0.0', port: 0);
    _signalingServer = server;

    final client = SignalingClient();
    await client.connect('ws://127.0.0.1:${server.port}');
    _signalingClient = client;

    final code = await client.createRoom();
    if (mounted) {
      setState(() => _inviteCode = code);
    }

    _peerJoinedSubscription = client.peerJoined.listen((event) async {
      try {
        final connection = WebRtcConnection(
          signaling: client,
          remotePeerId: event.peerId,
        );
        _webrtcConnections.add(connection);
        final transport = await connection.connectAsOfferer();
        host.acceptTransport(transport);
      } catch (error) {
        if (!mounted) return;
        setState(() => _status = 'Verbindungsaufbau fehlgeschlagen: $error');
      }
    });
  }

  Future<void> _joinSession() async {
    if (_isLan) {
      await _joinLan();
    } else {
      await _joinInternet();
    }
  }

  Future<void> _joinLan() async {
    final session = ClientSession();
    _wireClientListeners(session);
    await session.connect(
      widget.config.effectiveHost,
      widget.config.effectivePort,
      name: widget.config.effectiveName,
    );
    _afterClientConnected(session);
  }

  Future<void> _joinInternet() async {
    final client = SignalingClient();
    await client.connect(widget.config.signalingUrl);
    _signalingClient = client;

    final existingPeerIds = await client.joinRoom(widget.config.inviteCode);
    if (existingPeerIds.isEmpty) {
      throw StateError('Kein Host im Raum gefunden.');
    }
    final hostPeerId = existingPeerIds.first;

    final connection = WebRtcConnection(
      signaling: client,
      remotePeerId: hostPeerId,
    );
    _webrtcConnections.add(connection);
    if (mounted) {
      setState(() => _status = 'Verbinde mit dem Host (WebRTC)...');
    }
    final transport = await connection.connectAsAnswerer();

    final session = ClientSession();
    _wireClientListeners(session);
    await session.connectVia(transport, name: widget.config.effectiveName);
    _afterClientConnected(session);
  }

  void _wireClientListeners(ClientSession session) {
    session.statusUpdates.listen((message) {
      if (!mounted) return;
      setState(() => _status = message);
    });
    session.lobbyUpdates.listen((message) {
      if (!mounted) return;
      setState(() {
        _lobbyPlayers = message.players;
        _status = 'Lobby aktualisiert';
      });
    });
    session.stateUpdates.listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _gameStarted = true;
        _ownHand = snapshot.players[snapshot.yourPlayerIndex].hand ?? const <Tile>[];
        _status = 'Spielzustand empfangen (${snapshot.players.length} Spieler)';
      });
    });
    session.errors.listen((message) {
      if (!mounted) return;
      setState(() {
        _status = 'Fehler: $message';
      });
    });
  }

  void _afterClientConnected(ClientSession session) {
    if (session.latestSnapshot != null) {
      final snapshot = session.latestSnapshot!;
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _ownHand = snapshot.players[snapshot.yourPlayerIndex].hand ?? const <Tile>[];
        });
      }
    }
    _clientSession = session;
  }

  @override
  void dispose() {
    unawaited(_hostSession?.close());
    unawaited(_clientSession?.close());
    unawaited(_peerJoinedSubscription?.cancel());
    for (final connection in _webrtcConnections) {
      unawaited(connection.close());
    }
    unawaited(_signalingClient?.close());
    unawaited(_signalingServer?.close());
    super.dispose();
  }

  Future<void> _startGame() async {
    if (_hostSession == null || _gameStarted) return;
    setState(() => _status = 'Spiel wird gestartet...');
    _hostSession!.startGame();
    final snapshot = _hostSession!.snapshotForHost();
    if (!mounted || snapshot == null) return;
    setState(() {
      _snapshot = snapshot;
      _gameStarted = true;
      _ownHand = snapshot.players[snapshot.yourPlayerIndex].hand ?? const <Tile>[];
      _status = 'Spiel gestartet';
    });
  }

  Future<void> _restartGame() async {
    if (_hostSession == null) return;
    setState(() {
      _gameStarted = false;
      _snapshot = null;
      _ownHand = const <Tile>[];
      _status = 'Neue Partie wird vorbereitet...';
    });
    _hostSession!.restartGame();
    final snapshot = _hostSession!.snapshotForHost();
    if (!mounted || snapshot == null) return;
    setState(() {
      _snapshot = snapshot;
      _gameStarted = true;
      _ownHand = snapshot.players[snapshot.yourPlayerIndex].hand ?? const <Tile>[];
      _status = 'Neue Partie gestartet';
    });
  }

  Future<void> _sendMove(List<TilePlacement> placements) async {
    if (placements.isEmpty) return;
    if (_clientSession != null) {
      setState(() => _status = 'Zug wird an den Host gesendet...');
      _clientSession!.sendMove(placements);
      return;
    }
    if (_hostSession != null) {
      setState(() => _status = 'Host führt den Zug aus...');
      _hostSession!.playHostMove(placements);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_snapshot != null) {
      return NetworkGameView(
        snapshot: _snapshot!,
        ownHand: _ownHand,
        canInteract: _snapshot!.currentPlayerIndex == _snapshot!.yourPlayerIndex,
        onSendMove: _sendMove,
        statusText: _status,
      );
    }

    final isHosting = _hostSession != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Netzwerk-Spiel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isLan ? 'LAN-Verbindung' : 'Internet-Verbindung',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_status ?? 'Initialisiere Session...'),
            const SizedBox(height: 16),
            if (_isInitializing)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (_inviteCode != null) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.vpn_key),
                    title: const Text('Einladungscode'),
                    subtitle: SelectableText(_inviteCode!),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: ListTile(
                  leading: const Icon(Icons.wifi_tethering),
                  title: const Text('Session-Status'),
                  subtitle: Text(
                    isHosting
                        ? (_gameStarted || _snapshot != null
                            ? 'HostSession läuft und das Spiel ist aktiv.'
                            : 'HostSession ist gestartet und erwartet Mitspieler.')
                        : (_gameStarted || _snapshot != null
                            ? 'Spiel läuft bereits – der aktuelle Stand wird angezeigt.'
                            : 'ClientSession ist verbunden und wartet auf Updates.'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isLan ? 'Mehrspieler-Lobby' : 'Internet-Lobby',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_lobbyPlayers.isEmpty)
                const Text('Noch keine Teilnehmer')
              else ...[
                Text(
                  isHosting
                      ? (_gameStarted || _snapshot != null
                            ? 'Spiel läuft bereits'
                            : 'Warte auf den Spielstart...')
                      : (_gameStarted || _snapshot != null
                            ? 'Spiel gestartet – der Host hat die Partie begonnen.'
                            : 'Warte auf den Host – die Partie hat noch nicht begonnen.'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                ..._lobbyPlayers.map(
                  (player) => ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(player.name),
                    trailing: _snapshot != null || _gameStarted
                        ? Icon(Icons.play_circle_fill, color: Colors.green.shade700)
                        : Icon(Icons.pending, color: Colors.orange.shade700),
                  ),
                ),
              ],
            ],
            const Spacer(),
            if (isHosting && !_gameStarted) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _startGame,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Spiel starten'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (isHosting && _gameStarted && _snapshot != null && _snapshot!.isOver) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _restartGame,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Neues Spiel'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Zurück zur Lobby'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
