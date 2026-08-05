import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_net/qwirkle_net.dart';

import 'internet_room_history.dart';
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
  String? _inviteCode;
  List<String> _localAddresses = const [];
  String? _status;
  List<({String id, String name})> _lobbyPlayers = const [];
  bool _isInitializing = true;
  bool _gameStarted = false;
  GameStateSnapshot? _snapshot;
  List<Tile> _ownHand = const [];

  /// Getrennt von [_status]: Fehler bekommen eine auffällige, rote Anzeige
  /// statt in der neutralen Statuszeile unterzugehen (z. B. wenn direkt
  /// danach ein routinemäßiges Status-Update denselben Text überschreiben
  /// würde) - siehe Nutzer-Feedback "Fehler besser visualisieren".
  String? _errorText;

  bool get _isLan => widget.config.mode == 'lan';

  /// Ob diese Seite die Steuerung zum Starten/Neustarten der Partie zeigen
  /// soll: im LAN-Modus der eingebettete Host, im Internet-Modus die
  /// Person, die den Raum erstellt hat (`ClientSession.isRoomOwner`, vom
  /// Server bestätigt).
  bool get _hasOwnerControls =>
      _hostSession != null || (_clientSession?.isRoomOwner ?? false);

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
              : 'Internet-Raum wird erstellt...';
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
    if (_isLan) {
      final host = HostSession(hostPlayerName: widget.config.effectiveName);
      _wireHostListeners(host);
      final addresses = await _detectLocalAddresses();
      if (mounted) {
        setState(() => _localAddresses = addresses);
      }
      await host.start(address: '0.0.0.0', port: widget.config.effectivePort);
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
        _status = 'Host läuft auf Port ${host.port}';
        _lobbyPlayers = host.lobbyPlayers;
        _gameStarted = false;
      });
      return;
    }

    // Internet: kein eigener lokaler Server mehr - der Ersteller ist genau
    // wie jede:r Mitspieler:in ein Client des dedizierten `qwirkle_server`-
    // Backends, bekommt vom Server aber die Owner-Rechte (siehe
    // `ClientSession.isRoomOwner`) für Start/Neustart der Partie.
    final session = ClientSession();
    _wireClientListeners(session);
    final socket = await WebSocket.connect(widget.config.effectiveServerUrl);
    await session.connectVia(
      WebSocketTransport(socket),
      name: widget.config.effectiveName,
    );
    await _rememberSession(session);
    _afterClientConnected(session);
    if (!mounted) return;
    setState(() {
      _inviteCode = session.roomCode;
      _status = 'Raum erstellt – Einladungscode: ${session.roomCode}';
    });
  }

  void _wireHostListeners(HostSession host) {
    host.statusUpdates.listen((message) {
      if (!mounted) return;
      setState(() => _status = message);
    });
    host.lobbyUpdates.listen((message) {
      if (!mounted) return;
      setState(() => _lobbyPlayers = message.players);
    });
    host.errors.listen((message) {
      if (!mounted) return;
      setState(() => _errorText = message);
    });
    host.onStateChanged.listen((_) {
      if (!mounted) return;
      final snapshot = host.snapshotForHost();
      if (snapshot == null) return;
      setState(() {
        _snapshot = snapshot;
        _ownHand = snapshot.players[snapshot.yourPlayerIndex].hand ?? const <Tile>[];
        _status = 'Host-Zustand aktualisiert';
        _errorText = null;
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

  /// Ermittelt die eigenen LAN-IPv4-Adressen, damit der Host sie anzeigen
  /// und mit Mitspieler:innen teilen kann — vorher war nirgends zu sehen,
  /// unter welcher Adresse man selbst erreichbar ist, nur der Port.
  Future<List<String>> _detectLocalAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      return [
        for (final interface in interfaces)
          for (final address in interface.addresses) address.address,
      ];
    } on SocketException {
      return const [];
    }
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
    final session = ClientSession();
    _wireClientListeners(session);
    if (mounted) {
      setState(() => _status = 'Verbinde mit dem Raum...');
    }
    final socket = await WebSocket.connect(widget.config.effectiveServerUrl);
    // Ein zuvor gespeichertes Reconnect-Token (falls für diesen Raum
    // vorhanden) fordert denselben Sitzplatz zurück, statt einen neuen zu
    // beziehen - wichtig, wenn die Partie schon läuft.
    final history = await loadInternetRoomHistory();
    final saved = history.where((e) => e.roomCode == widget.config.inviteCode);
    await session.connectVia(
      WebSocketTransport(socket),
      name: widget.config.effectiveName,
      roomCode: widget.config.inviteCode,
      reconnectToken: saved.isEmpty ? null : saved.first.reconnectToken,
    );
    await _rememberSession(session);
    _afterClientConnected(session);
    if (!mounted) return;
    setState(() => _inviteCode = session.roomCode);
  }

  Future<void> _rememberSession(ClientSession session) async {
    final roomCode = session.roomCode;
    final token = session.reconnectToken;
    if (roomCode == null || token == null) return;
    await rememberInternetRoom(
      InternetRoomEntry(
        roomCode: roomCode,
        playerName: widget.config.effectiveName,
        reconnectToken: token,
        lastSeen: DateTime.now(),
      ),
    );
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
        _errorText = null;
      });
    });
    session.errors.listen((message) {
      if (!mounted) return;
      setState(() => _errorText = message);
    });
  }

  void _afterClientConnected(ClientSession session) {
    if (session.latestSnapshot != null) {
      final snapshot = session.latestSnapshot!;
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _ownHand = snapshot.players[snapshot.yourPlayerIndex].hand ?? const <Tile>[];
          _gameStarted = true;
        });
      }
    }
    _clientSession = session;
  }

  @override
  void dispose() {
    unawaited(_hostSession?.close());
    unawaited(_clientSession?.close());
    super.dispose();
  }

  Future<void> _startGame() async {
    if (_gameStarted) return;
    if (_hostSession != null) {
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
    } else if (_hasOwnerControls) {
      setState(() => _status = 'Spiel wird gestartet...');
      _clientSession!.sendStartGame();
      // Der Zustand kommt asynchron über `stateUpdates` zurück (der Server
      // verteilt ihn an alle Sitzplätze, auch den eigenen).
    }
  }

  Future<void> _restartGame() async {
    if (_hostSession != null) {
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
    } else if (_hasOwnerControls) {
      setState(() => _status = 'Neue Partie wird vorbereitet...');
      _clientSession!.sendRestartGame();
    }
  }

  /// Sendet [placements] und meldet zurück, ob der Zug angenommen wurde.
  ///
  /// Für den Client ist das nur "erfolgreich gesendet", nicht "vom Host
  /// bestätigt" (das kommt asynchron über [_clientSession]'s stateUpdates/
  /// errors zurück) - für den Host dagegen ist das Ergebnis sofort bekannt,
  /// da [HostSession.playHostMove] synchron validiert.
  Future<bool> _sendMove(List<TilePlacement> placements) async {
    if (placements.isEmpty) return false;
    if (_clientSession != null) {
      setState(() {
        _status = 'Zug wird an den Host gesendet...';
        _errorText = null;
      });
      _clientSession!.sendMove(placements);
      return true;
    }
    if (_hostSession != null) {
      setState(() {
        _status = 'Host führt den Zug aus...';
        _errorText = null;
      });
      final score = _hostSession!.playHostMove(placements);
      return score != null;
    }
    return false;
  }

  void _sendPass() {
    if (_clientSession != null) {
      setState(() {
        _status = 'Aussetzen wird gesendet...';
        _errorText = null;
      });
      _clientSession!.sendPass();
    } else if (_hostSession != null) {
      setState(() {
        _status = 'Host setzt aus...';
        _errorText = null;
      });
      _hostSession!.passHostTurn();
    }
  }

  void _sendExchange(List<Tile> tiles) {
    if (tiles.isEmpty) return;
    if (_clientSession != null) {
      setState(() {
        _status = 'Tausch wird gesendet...';
        _errorText = null;
      });
      _clientSession!.sendExchange(tiles);
    } else if (_hostSession != null) {
      setState(() {
        _status = 'Host tauscht Steine...';
        _errorText = null;
      });
      _hostSession!.exchangeHostTiles(tiles);
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
        onSendPass: _sendPass,
        onSendExchange: _sendExchange,
        statusText: _status,
        errorText: _errorText,
      );
    }

    final isHosting = _hostSession != null || widget.config.isHosting;

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
              if (_isLan && isHosting && _localAddresses.isNotEmpty) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.router),
                    title: const Text('Erreichbar unter'),
                    subtitle: SelectableText(
                      _localAddresses
                          .map((address) => '$address:${_hostSession?.port ?? widget.config.effectivePort}')
                          .join(' oder '),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
                            ? 'Die Partie ist aktiv.'
                            : 'Wartet auf Mitspieler:innen.')
                        : (_gameStarted || _snapshot != null
                            ? 'Spiel läuft bereits – der aktuelle Stand wird angezeigt.'
                            : 'Verbunden und wartet auf Updates.'),
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
                            ? 'Spiel gestartet – die Partie hat begonnen.'
                            : 'Warte auf den Spielstart...'),
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
            if (_hasOwnerControls && !_gameStarted) ...[
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
            if (_hasOwnerControls && _gameStarted && _snapshot != null && _snapshot!.isOver) ...[
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
