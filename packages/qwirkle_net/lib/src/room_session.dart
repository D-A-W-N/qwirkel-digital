import 'dart:async';
import 'dart:math';

import 'package:qwirkle_core/qwirkle_core.dart';

import 'messages.dart';
import 'serialization.dart';
import 'transport.dart';

/// Ein einzelner Sitzplatz in einem [RoomSession]-Raum.
///
/// Anders als bei `HostSession` (LAN) ist hier JEDER Sitzplatz - auch der
/// des Raumersteller:in ("Owner") - ein Netzwerk-Client, nie ein lokal
/// eingebetteter Spieler. [reconnectToken] überlebt eine Trennung
/// ([transport]/[subscription] werden dabei nur auf null gesetzt, der Sitz
/// selbst bleibt in [RoomSession.seats] erhalten, sobald die Partie
/// gestartet ist) und erlaubt es, denselben Sitzplatz (inkl. Hand/
/// Punktestand) später zurückzufordern.
class RoomSeat {
  final String playerId;
  final String reconnectToken;
  String name;
  bool isOwner;
  int? playerIndex;
  bool connected;
  MessageTransport? transport;
  StreamSubscription<String>? subscription;

  /// Seit wann dieser Sitzplatz ununterbrochen getrennt ist (`null`, solange
  /// verbunden) - Grundlage für [RoomSession.hostClaimGracePeriod]. Bewusst
  /// nicht einfach aus [connected] abgeleitet, damit auch über einen
  /// Server-Neustart hinweg (siehe `room_persistence.dart`) weitergezählt
  /// werden kann, statt die Frist bei jedem Redeploy neu zu starten.
  DateTime? disconnectedSince;

  RoomSeat({
    required this.playerId,
    required this.reconnectToken,
    required this.name,
    required this.isOwner,
    this.playerIndex,
    this.connected = true,
    this.disconnectedSince,
  });

  void send(NetMessage message) => transport?.send(message.encode());
}

/// Host-autoritative Netzwerksitzung für einen einzelnen Raum auf dem
/// dedizierten `qwirkle_server`-Backend (Internet-Mehrspieler).
///
/// Im Unterschied zu `HostSession` (LAN, ein Prozess = eine Partie, Host als
/// eingebetteter lokaler Spieler mit Index 0, synchrone `playHostMove` u. ä.)
/// ist hier jeder Sitzplatz ein Netzwerk-Client. Statt eines festen Hosts
/// gibt es einen "Owner"-Sitzplatz (der erste Beitretende), der die Partie
/// per [StartGameMessage]/[RestartGameMessage] starten darf.
///
/// Reconnect ist ein Kernfeature statt Sonderfall: Getrennte Sitzplätze
/// bleiben nach Spielstart reserviert - bewusst KEIN automatisches
/// Überspringen des Zugs wie bei `HostSession._skipDisconnectedPlayers`,
/// weil das Warten auf zurückkehrende Spieler:innen genau der Sinn einer
/// Partie ist, die sich über mehrere Tage ziehen kann.
class RoomSession {
  final String roomCode;

  /// Frei vergebener Name des Raums (z. B. "Samstagsrunde") - damit sich
  /// der Raum in der lokalen Historie wiederfinden lässt, statt nur über
  /// den kaum merkbaren Code (siehe `internet_room_history.dart`,
  /// Nutzer-Feedback "Räume sollten auch Namen bekommen"). Fällt auf
  /// "Raum $roomCode" zurück, falls beim Erstellen keiner angegeben wurde.
  final String roomName;
  final List<RoomSeat> seats = [];
  QwirkleGame? _game;
  DateTime lastActivity = DateTime.now();

  /// Was beim letzten Zug passiert ist - für ein Live-"was hat die andere
  /// Person gerade gemacht"-Feedback bei den Clients, siehe
  /// [GameStateSnapshot.lastMove]. Bewusst nicht persistiert (rein
  /// transiente Live-Anzeige, kein Teil des eigentlichen Spielzustands).
  LastMoveInfo? _lastMove;

  /// Wird nach jeder zustandsändernden Aktion aufgerufen (Beitritt, Zug,
  /// Spielstart, Trennung, ...), damit die aufrufende Schicht
  /// (`qwirkle_server`) den Raum bei Bedarf persistieren kann. Bewusst
  /// synchron und ohne Argument - der Aufrufer liest den Zustand über die
  /// public Getter/Felder selbst aus.
  void Function()? onChanged;

  final Random _random = Random.secure();
  int _nextPlayerNumber;

  /// Wie lange die Owner-Person ununterbrochen getrennt sein muss, bevor
  /// eine andere verbundene Person die Owner-Rolle per [ClaimHostMessage]
  /// übernehmen darf.
  ///
  /// Bewusst lang statt eines kurzen Timeouts: Partien können sich über
  /// mehrere Tage ziehen, in denen es völlig normal ist, dass Host wie
  /// Mitspieler:innen zwischenzeitlich offline sind (Nutzer-Feedback) - ein
  /// kurzer Timeout würde solche normalen Pausen fälschlich als
  /// Raum-Verlassen behandeln.
  static const hostClaimGracePeriod = Duration(hours: 48);

  /// [initialGame] erlaubt es `room_persistence.dart`, eine zuvor
  /// gespeicherte Partie direkt beim Wiederaufbau des Raums (z. B. nach
  /// einem Server-Neustart) einzusetzen, ohne einen separaten, jederzeit
  /// aufrufbaren Mutator dafür offenzulegen. [nextPlayerNumber] muss beim
  /// Wiederaufbau eines Raums über den höchsten bereits vergebenen
  /// `playerId`-Zähler hinaus gesetzt werden, sonst könnten neu
  /// beitretende Spieler:innen eine bereits vergebene Id bekommen.
  RoomSession({
    required this.roomCode,
    String? roomName,
    this.onChanged,
    QwirkleGame? initialGame,
    int nextPlayerNumber = 1,
  }) : roomName = (roomName == null || roomName.trim().isEmpty)
           ? 'Raum $roomCode'
           : roomName.trim(),
       _game = initialGame,
       _nextPlayerNumber = nextPlayerNumber;

  bool get isGameStarted => _game != null;
  QwirkleGame? get game => _game;
  bool get isEmpty => seats.isEmpty;

  List<({String id, String name})> get lobbyPlayers => [
    for (final s in seats) (id: s.playerId, name: s.name),
  ];

  /// Sitzplätze, deren Netzwerk-Client aktuell getrennt ist (Index-basiert,
  /// für [GameStateSnapshot.forRecipient]) - für die UI, damit sichtbar
  /// wird, wenn jemand die Verbindung verloren hat, statt dass die Partie
  /// (siehe Klassendoku: bewusst kein Auto-Skip) kommentarlos zu warten
  /// scheint.
  Set<int> get _disconnectedPlayerIndexes => {
    for (final s in seats)
      if (!s.connected && s.playerIndex != null) s.playerIndex!,
  };

  String _generateToken() {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  RoomSeat? _findByToken(String token) {
    for (final seat in seats) {
      if (seat.reconnectToken == token) return seat;
    }
    return null;
  }

  void _touch() => lastActivity = DateTime.now();

  /// Verarbeitet die allererste Nachricht eines neu verbundenen [transport]
  /// (vom `RoomManager` bereits als [JoinMessage] dekodiert - dessen
  /// [JoinMessage.roomCode] entscheidet dort, ob überhaupt dieser Raum
  /// zuständig ist). Übernimmt danach das Zuhören auf alle weiteren
  /// Nachrichten dieses Transports.
  void handleJoin(MessageTransport transport, JoinMessage message) {
    _touch();
    final existingSeat = message.reconnectToken == null
        ? null
        : _findByToken(message.reconnectToken!);

    final RoomSeat seat;
    if (existingSeat != null) {
      seat = existingSeat;
      seat.connected = true;
      seat.disconnectedSince = null;
      seat.name = message.name;
    } else {
      seat = RoomSeat(
        playerId: 'p${_nextPlayerNumber++}',
        reconnectToken: _generateToken(),
        name: message.name,
        isOwner: seats.isEmpty,
      );
      seats.add(seat);
    }

    seat.transport = transport;
    seat.subscription = transport.lines.listen(
      (line) => _handleLine(seat, line),
      onDone: () => _handleDisconnect(seat),
      onError: (_) => _handleDisconnect(seat),
    );

    seat.send(
      WelcomeMessage(
        seat.playerId,
        roomCode: roomCode,
        reconnectToken: seat.reconnectToken,
        isOwner: seat.isOwner,
        roomName: roomName,
      ),
    );

    if (_game != null && seat.playerIndex != null) {
      // Ein neu (wieder-)verbundener Sitzplatz mit bereits zugewiesenem
      // Index kann nur ein Reconnect sein (ein frischer Sitzplatz bekommt
      // seinen Index erst bei Spielstart) - betrifft daher alle, nicht nur
      // diesen Sitzplatz: sonst sehen die anderen nie, dass diese Person
      // wieder verbunden ist, was gerade dann wichtig ist, wenn sie selbst
      // am Zug ist.
      _broadcastState();
    } else {
      _broadcastLobby();
    }
    onChanged?.call();
  }

  void _handleLine(RoomSeat seat, String line) {
    _touch();
    final message = decodeMessage(line);
    try {
      if (message is StartGameMessage) {
        _requireOwner(seat);
        _startGame();
      } else if (message is RestartGameMessage) {
        _requireOwner(seat);
        _restartGame();
      } else if (message is ClaimHostMessage) {
        _claimHost(seat);
      } else {
        final game = _game;
        if (game == null || seat.playerIndex == null) return;
        if (message is MoveMessage) {
          _requireCurrentPlayer(seat);
          final score = game.playTiles(message.placements);
          _lastMove = LastMoveInfo(
            playerIndex: seat.playerIndex!,
            kind: LastMoveKind.placed,
            placements: message.placements,
            score: score,
          );
        } else if (message is ExchangeMessage) {
          _requireCurrentPlayer(seat);
          game.exchangeTiles(message.tiles);
          _lastMove = LastMoveInfo(
            playerIndex: seat.playerIndex!,
            kind: LastMoveKind.exchanged,
          );
        } else if (message is PassMessage) {
          _requireCurrentPlayer(seat);
          game.passTurn();
          _lastMove = LastMoveInfo(
            playerIndex: seat.playerIndex!,
            kind: LastMoveKind.passed,
          );
        } else {
          return;
        }
        _broadcastState();
      }
      onChanged?.call();
    } on InvalidMoveException catch (e) {
      seat.send(ErrorMessage(e.message));
    } on StateError catch (e) {
      seat.send(ErrorMessage(e.message));
    } on ArgumentError catch (e) {
      seat.send(ErrorMessage(e.message.toString()));
    } catch (e) {
      // Kein spezifischer, erwarteter Fehlertyp - trotzdem antworten statt
      // die Nachricht stillschweigend zu verschlucken. Ohne das bleibt der
      // Client ohne jede Rückmeldung hängen: seine vorläufige Platzierung
      // ist bereits lokal geräumt (der Client geht optimistisch von Erfolg
      // aus), aber ohne neuen Spielstand ODER Fehlermeldung sieht es aus,
      // als wären die Steine kommentarlos verschwunden.
      seat.send(ErrorMessage('Unerwarteter Fehler: $e'));
    }
  }

  void _requireOwner(RoomSeat seat) {
    if (!seat.isOwner) {
      throw StateError('Nur der/die Raumersteller:in kann die Partie starten.');
    }
  }

  RoomSeat? get _currentOwner {
    for (final s in seats) {
      if (s.isOwner) return s;
    }
    return null;
  }

  bool _isHostClaimable(RoomSeat owner) {
    final disconnectedSince = owner.disconnectedSince;
    return disconnectedSince != null &&
        DateTime.now().difference(disconnectedSince) >= hostClaimGracePeriod;
  }

  /// Übergibt die Owner-Rolle an [seat], sofern der/die aktuelle
  /// Raumersteller:in seit mindestens [hostClaimGracePeriod] ununterbrochen
  /// getrennt ist. Verwaist der Raum ganz ohne Owner (sollte praktisch nicht
  /// vorkommen), übernimmt [seat] sofort ohne Wartezeit.
  void _claimHost(RoomSeat seat) {
    if (seat.isOwner) return;
    final owner = _currentOwner;
    if (owner != null && !_isHostClaimable(owner)) {
      throw StateError(
        'Die Owner-Rolle kann erst übernommen werden, wenn die aktuelle '
        'Raumersteller-Person seit mindestens '
        '${hostClaimGracePeriod.inHours} Stunden ununterbrochen getrennt ist.',
      );
    }
    owner?.isOwner = false;
    seat.isOwner = true;
    _broadcastState();
  }

  void _requireCurrentPlayer(RoomSeat seat) {
    if (_game!.currentPlayerIndex != seat.playerIndex) {
      throw StateError('Du bist gerade nicht am Zug.');
    }
  }

  void _startGame() {
    if (_game != null) {
      throw StateError('Die Partie wurde bereits gestartet.');
    }
    if (seats.length < 2) {
      throw StateError('Es werden mindestens 2 Spieler:innen benötigt.');
    }
    final players = [
      for (final s in seats) Player(id: s.playerId, name: s.name),
    ];
    final game = QwirkleGame(players: players);
    _game = game;
    _lastMove = null;
    for (var i = 0; i < seats.length; i++) {
      seats[i].playerIndex = i;
    }
    _broadcastState();
  }

  void _restartGame() {
    if (_game == null) {
      _startGame();
      return;
    }
    final players = [
      for (final s in seats) Player(id: s.playerId, name: s.name),
    ];
    _game = QwirkleGame(players: players);
    _lastMove = null;
    for (var i = 0; i < seats.length; i++) {
      seats[i].playerIndex = i;
    }
    _broadcastState();
  }

  void _broadcastLobby() {
    final message = LobbyMessage(lobbyPlayers, canStart: seats.length >= 2);
    for (final s in seats) {
      s.send(message);
    }
  }

  void _broadcastState() {
    final game = _game;
    if (game == null) return;
    final disconnected = _disconnectedPlayerIndexes;
    final owner = _currentOwner;
    final hostClaimable = owner != null && _isHostClaimable(owner);
    for (final s in seats) {
      final index = s.playerIndex;
      if (index == null) continue;
      s.send(
        GameStateMessage(
          GameStateSnapshot.forRecipient(
            game,
            index,
            lastMove: _lastMove,
            disconnectedPlayerIndexes: disconnected,
            ownerPlayerIndex: owner?.playerIndex,
            hostClaimable: hostClaimable,
          ),
        ),
      );
    }
  }

  void _handleDisconnect(RoomSeat seat) {
    seat.transport = null;
    seat.subscription = null;
    if (_game == null) {
      // Vor Spielstart hängt am Sitzplatz noch nichts (keine Hand/kein
      // Punktestand) - anders als danach kann einfach neu beigetreten
      // werden, ohne dass das Reconnect-Token gebraucht wird.
      seats.remove(seat);
      if (seat.isOwner && seats.isNotEmpty) {
        seats.first.isOwner = true;
      }
      _broadcastLobby();
    } else {
      seat.connected = false;
      seat.disconnectedSince = DateTime.now();
      // Bewusst KEIN automatisches Überspringen des Zugs (Unterschied zu
      // HostSession): Die Partie wartet, bis der Sitzplatz per
      // Reconnect-Token zurückerobert wird.
      //
      // Ohne diesen Broadcast erfahren die anderen Sitzplätze nie von der
      // Trennung (vorher wurde hier nur die lokale Flagge gesetzt) - gerade
      // wenn diese Person am Zug ist, sähe die Partie sonst kommentarlos
      // aus wie "hängengeblieben", ohne erkennbaren Grund.
      _broadcastState();
    }
    onChanged?.call();
  }

  Future<void> close() async {
    for (final seat in seats) {
      await seat.subscription?.cancel();
      await seat.transport?.close();
    }
  }
}
