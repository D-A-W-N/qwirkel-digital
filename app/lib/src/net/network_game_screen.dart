import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_net/qwirkle_net.dart';

import 'network_connection_config.dart';
import 'network_game_view.dart';

class NetworkGameScreen extends StatefulWidget {
  const NetworkGameScreen({super.key, required this.config});

  final NetworkConnectionConfig config;

  @override
  State<NetworkGameScreen> createState() => _NetworkGameScreenState();
}

class _NetworkGameScreenState extends State<NetworkGameScreen> {
  HostSession? _hostSession;
  ClientSession? _clientSession;
  String? _status;
  List<({String id, String name})> _lobbyPlayers = const [];
  bool _isInitializing = true;
  bool _gameStarted = false;
  GameStateSnapshot? _snapshot;
  List<Tile> _ownHand = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_initializeSession());
  }

  Future<void> _initializeSession() async {
    try {
      if (widget.config.mode == 'internet') {
        setState(() {
          _status = 'Internet-Setup wird vorbereitet...';
        });
      } else {
        setState(() {
          _status = 'Verbinde mit dem Host...';
        });
      }

      if (widget.config.mode == 'lan' && widget.config.effectiveName.isEmpty) {
        throw ArgumentError('Bitte gib einen Namen ein.');
      }

      if (widget.config.mode == 'lan') {
        final session = ClientSession();
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
        await session.connect(
          widget.config.effectiveHost,
          widget.config.effectivePort,
          name: widget.config.effectiveName,
        );
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
      } else {
        final host = HostSession(hostPlayerName: widget.config.effectiveName);
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
        await host.start(
          address: '0.0.0.0',
          port: widget.config.effectivePort,
        );
        _hostSession = host;
        final initialSnapshot = host.snapshotForHost();
        if (mounted && initialSnapshot != null) {
          setState(() {
            _snapshot = initialSnapshot;
            _ownHand = initialSnapshot.players[initialSnapshot.yourPlayerIndex].hand ?? const <Tile>[];
            _status = 'Host-Zustand aktualisiert';
          });
        }
        setState(() {
          _status = 'Host läuft auf Port ${host.port}';
          _lobbyPlayers = host.lobbyPlayers;
          _gameStarted = false;
        });
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

  @override
  void dispose() {
    unawaited(_hostSession?.close());
    unawaited(_clientSession?.close());
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
    if (widget.config.mode == 'lan' && _clientSession != null) {
      setState(() => _status = 'Zug wird an den Host gesendet...');
      _clientSession!.sendMove(placements);
      return;
    }
    if (widget.config.mode != 'lan' && _hostSession != null) {
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

    return Scaffold(
      appBar: AppBar(title: const Text('Netzwerk-Spiel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.config.mode == 'lan' ? 'LAN-Verbindung' : 'Internet-Verbindung',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_status ?? 'Initialisiere Session...'),
            const SizedBox(height: 16),
            if (_isInitializing)
              const Center(child: CircularProgressIndicator())
            else ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.wifi_tethering),
                  title: const Text('Session-Status'),
                  subtitle: Text(
                    widget.config.mode == 'lan'
                        ? (_gameStarted || _snapshot != null
                            ? 'Spiel läuft bereits – der aktuelle Stand wird angezeigt.'
                            : 'ClientSession ist verbunden und wartet auf Updates.')
                        : (_gameStarted || _snapshot != null
                            ? 'HostSession läuft und das Spiel ist aktiv.'
                            : 'HostSession ist gestartet und erwartet Mitspieler.'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.config.mode == 'lan' ? 'Mehrspieler-Lobby' : 'Internet-Lobby',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_lobbyPlayers.isEmpty)
                const Text('Noch keine Teilnehmer')
              else ...[
                Text(
                  widget.config.mode == 'lan'
                      ? (_gameStarted || _snapshot != null
                            ? 'Spiel gestartet – der Host hat die Partie begonnen.'
                            : 'Warte auf den Host – die Partie hat noch nicht begonnen.')
                      : (_gameStarted || _snapshot != null
                            ? 'Spiel läuft bereits'
                            : 'Warte auf den Spielstart...'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                ..._lobbyPlayers.map(
                  (player) => ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(player.name),
                    trailing: _snapshot != null || _gameStarted
                        ? const Icon(Icons.play_circle_fill, color: Colors.green)
                        : const Icon(Icons.pending, color: Colors.orange),
                  ),
                ),
              ],
            ],
            const Spacer(),
            if (widget.config.mode != 'lan' && _hostSession != null && !_gameStarted) ...[
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
            if (widget.config.mode != 'lan' && _hostSession != null && _gameStarted && _snapshot != null && _snapshot!.isOver) ...[
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
