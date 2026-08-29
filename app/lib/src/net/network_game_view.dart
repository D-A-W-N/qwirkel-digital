import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_net/qwirkle_net.dart';

import '../game/widgets/board_surface.dart';
import '../history/match_history.dart';
import '../game/widgets/compact_button_style.dart';
import '../game/widgets/game_bottom_bar.dart';
import '../game/widgets/hand_view.dart';
import '../game/widgets/pending_score_badge.dart';
import '../game/widgets/score_panel.dart';
import '../game/widgets/turn_dialog.dart';

class NetworkGameView extends StatefulWidget {
  final GameStateSnapshot snapshot;
  final List<Tile> ownHand;
  final bool canInteract;

  /// Sendet den Zug. Der Rückgabewert bedeutet nur "erfolgreich
  /// abgeschickt", NICHT "vom Server bestätigt" - die eigentliche
  /// Bestätigung kommt asynchron über ein neues [snapshot] (vorläufige
  /// Platzierungen werden erst dann geleert, siehe [didUpdateWidget]) oder
  /// als [errorText] zurück.
  final Future<bool> Function(List<TilePlacement> placements) onSendMove;

  /// Setzt den Zug aus (nur möglich, wenn der Beutel leer ist - solange
  /// noch Steine im Beutel sind, kann stattdessen getauscht werden,
  /// spiegelt dieselbe Einschränkung wie im lokalen Spiel).
  final void Function() onSendPass;

  /// Tauscht die übergebenen Handsteine gegen neue aus dem Beutel.
  final void Function(List<Tile> tiles) onSendExchange;

  /// Ob diese Person die Partie neu starten darf (Raumersteller:in im
  /// Internet-Modus bzw. immer im LAN-Modus, sofern man der Host ist) -
  /// steuert, ob der "Neues Spiel"-Button im Partie-Ende-Overlay angezeigt
  /// wird.
  final bool isRoomOwner;

  /// Startet die Partie mit denselben Teilnehmer:innen neu.
  final void Function() onRestartGame;
  final String? statusText;

  /// Vom Server/Host abgelehnter Zug o. ä. - wird auffällig (rot) getrennt
  /// von [statusText] angezeigt, statt in der neutralen Statuszeile
  /// womöglich von einem nachfolgenden Routine-Update überschrieben zu
  /// werden, bevor sie überhaupt bemerkt wird.
  final String? errorText;

  /// Zeigt einen "Raum verlassen"-Button in der AppBar, wenn gesetzt - nur
  /// für Internet-Räume relevant (`InternetRoomScreen`), wo Wegnavigieren
  /// die Verbindung absichtlich nicht mehr trennt und es daher eine
  /// separate, explizite Aktion braucht, um den Sitzplatz endgültig
  /// freizugeben. `null` (LAN-Modus) zeigt keinen solchen Button.
  final VoidCallback? onLeaveRoom;

  /// Ob dies eine LAN- oder eine Internet-Partie ist - nur für die
  /// Partie-Historie (siehe [didUpdateWidget]) relevant, sonst ohne
  /// Auswirkung auf dieses Widget.
  final MatchMode mode;

  /// Nur für Internet-Partien gesetzt (LAN kennt keine Raum-Codes) - fließt
  /// ausschließlich in den [MatchRecord] der Partie-Historie ein.
  final String? roomCode;

  const NetworkGameView({
    super.key,
    required this.snapshot,
    required this.ownHand,
    required this.canInteract,
    required this.onSendMove,
    required this.onSendPass,
    required this.onSendExchange,
    required this.isRoomOwner,
    required this.onRestartGame,
    required this.mode,
    this.roomCode,
    this.statusText,
    this.errorText,
    this.onLeaveRoom,
  });

  @override
  State<NetworkGameView> createState() => _NetworkGameViewState();
}

class _NetworkGameViewState extends State<NetworkGameView> {
  static const double _cellSize = 64;
  static const double _tileSize = 48;

  final Map<Position, Tile> _pendingPlacements = {};

  /// Merkt sich, welcher Hand-Index bereits vorläufig platziert wurde, damit
  /// dieser Stein in der Hand-Leiste als leere Lücke statt doppelt
  /// erscheint - spiegelt `GameController.handSlots`/`_handIndexByPosition`
  /// im lokalen Spiel.
  final Map<Position, int> _handIndexByPosition = {};

  /// Live-Validierungsfehler beim Platzieren (z. B. Lücke in der Reihe) -
  /// getrennt von [widget.errorText] (das kommt vom Server, erst NACH dem
  /// Senden). Wird sofort beim Versuch gesetzt, statt erst nach einem
  /// Roundtrip zum Server - siehe Nutzer-Feedback "Live Feedback beim
  /// Platzieren", spiegelt `GameController.stageTile`s Live-Validierung im
  /// lokalen Spiel.
  String? _liveError;
  bool _isSending = false;
  bool _showStartPulse = true;
  bool _showTutorial = true;
  Timer? _startPulseTimer;

  /// Tausch-Modus: Handsteine werden per Antippen statt per Ziehen
  /// ausgewählt - spiegelt `HandView`s `exchangeMode` im lokalen Spiel.
  bool _exchangeMode = false;
  final Set<int> _selectedForExchange = {};

  /// Eigener Messenger statt `ScaffoldMessenger.of(context)`: `context`
  /// dieses States liegt OBERHALB des eigenen `Scaffold`s (das erst in
  /// `build()` entsteht), sodass `.of(context)` aus `didUpdateWidget`
  /// heraus nicht zuverlässig den hiesigen Messenger fände.
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Letzte bereits als Toast gezeigte Zug-Zusammenfassung (Signatur statt
  /// Objekt, da `LastMoveInfo` kein `==` implementiert) - verhindert, dass
  /// ein unabhängiger Rebuild (z. B. eigene Platzierung) denselben fremden
  /// Zug erneut als Toast auslöst.
  String? _lastToastedMoveSignature;

  String? _moveSignature(LastMoveInfo? move) {
    if (move == null) return null;
    return '${move.playerIndex}-${move.kind}-${move.score}-${move.placements.length}';
  }

  void _showToast(String message, {Color? color}) {
    _scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    _startPulseTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _showStartPulse = false);
      }
    });
    // `didUpdateWidget` erkennt nur ÄNDERUNGEN, feuert also nicht für den
    // bereits beim allerersten Aufbau gesetzten Statustext (z. B. "Spiel
    // gestartet", von `network_game_screen.dart` oft schon vor dem ersten
    // Frame gesetzt) - ohne diesen Extra-Toast würde diese erste Meldung
    // sonst nie angezeigt.
    final initialStatusText = widget.statusText;
    if (initialStatusText != null && initialStatusText.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showToast(initialStatusText);
      });
    }
  }

  @override
  void dispose() {
    _startPulseTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NetworkGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Der Zug wurde vom Server übernommen (die Reihe ist von mir
    // weitergezogen) - die vorläufigen Platzierungen stecken jetzt im
    // bestätigten Brett und können geleert werden. Bewusst NICHT beim
    // Senden selbst geleert (siehe `onSendMove`-Doc): würde der Server den
    // Zug ablehnen oder eine unerwartete Ausnahme werfen, sähen die
    // gerade gelegten Steine sonst kommentarlos verschwunden aus, ohne
    // dass klar wird, warum.
    final turnAdvancedAwayFromMe =
        widget.snapshot.currentPlayerIndex !=
            oldWidget.snapshot.currentPlayerIndex &&
        widget.snapshot.currentPlayerIndex != widget.snapshot.yourPlayerIndex;
    // Regression: eine neu gestartete Partie (Übergang isOver -> nicht mehr
    // isOver) bringt ein komplett frisches Brett/Hand vom Server, aber ohne
    // diesen Fall leerte sich der lokale Platzierungs-Zustand nicht mit -
    // eine am Ende der vorigen Partie noch nicht gesendete Platzierung (z. B.
    // kurz bevor das Zug-Ende-Overlay die Buttons sperrt) blieb als
    // "Geister-Stein" auf dem neuen, eigentlich leeren Brett stehen. Beim
    // Zurücknehmen wurde dann `_handIndexByPosition`s Hand-Index (aus der
    // ALTEN Hand) auf die KOMPLETT NEUE Hand angewendet und blendete dort
    // einen falschen, unzusammenhängenden Stein aus/wieder ein.
    final restarted = oldWidget.snapshot.isOver && !widget.snapshot.isOver;
    final justFinished = !oldWidget.snapshot.isOver && widget.snapshot.isOver;
    if (justFinished) {
      unawaited(
        recordMatch(
          MatchRecord(
            playedAt: DateTime.now(),
            mode: widget.mode,
            roomCode: widget.roomCode,
            standings: [
              for (final player in [
                ...widget.snapshot.players,
              ]..sort((a, b) => b.score.compareTo(a.score)))
                MatchPlayerResult(name: player.name, score: player.score),
            ],
          ),
        ),
      );
    }
    if (turnAdvancedAwayFromMe || restarted) {
      if (_pendingPlacements.isNotEmpty) {
        _pendingPlacements.clear();
        _handIndexByPosition.clear();
      }
      if (_exchangeMode || _selectedForExchange.isNotEmpty) {
        _exchangeMode = false;
        _selectedForExchange.clear();
      }
    }
    if (restarted) {
      _liveError = null;
    }
    // Ein wegklickbarer Dialog macht es unübersehbar, sobald ich selbst am
    // Zug bin - Nutzer-Feedback: nicht immer sofort ersichtlich, wer dran ist.
    final becameMyTurn =
        widget.snapshot.currentPlayerIndex == widget.snapshot.yourPlayerIndex &&
        oldWidget.snapshot.currentPlayerIndex !=
            widget.snapshot.currentPlayerIndex;
    // Andersrum gilt dasselbe für eine zurückkehrende Person: die Partie
    // überspringt ihren Zug bei einer Trennung bewusst NICHT (siehe
    // RoomSession-Doku), es kann also schon vor dem Reconnect ihr Zug
    // gewesen sein und bleibt es danach unverändert - `currentPlayerIndex`
    // ändert sich dann gar nicht, `becameMyTurn` bliebe fälschlich `false`.
    // Erkennbar stattdessen am Wechsel von `canInteract: false -> true`
    // OHNE eigentlichen Zugwechsel (reines Reconnect-Signal - ein normaler
    // Zugwechsel triggert bereits über `becameMyTurn` oben und würde sonst
    // doppelt anzeigen). Nutzer-Feedback: "andersrum sollte der Spieler,
    // der am Zug ist, auch drauf hingewiesen werden".
    final regainedTurnAfterReconnect =
        !becameMyTurn &&
        widget.canInteract &&
        !oldWidget.canInteract &&
        widget.snapshot.currentPlayerIndex == widget.snapshot.yourPlayerIndex;
    if (becameMyTurn || regainedTurnAfterReconnect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showTurnDialog(context, message: 'Du bist jetzt am Zug.');
      });
    }

    // Der fremde-Zug-Hinweis war vorher ein dauerhaft stehendes Banner ohne
    // jedes Selbst-Ausblenden - Nutzer-Feedback: "Benachrichtigungen
    // verschwinden nicht während des Spiels". Ein Toast (SnackBar) bringt
    // das automatische Verschwinden eingebaut mit.
    final lastMove = widget.snapshot.lastMove;
    final lastMoveByOther =
        lastMove != null &&
            lastMove.playerIndex != widget.snapshot.yourPlayerIndex
        ? lastMove
        : null;
    final moveSignature = _moveSignature(lastMoveByOther);
    if (moveSignature != null && moveSignature != _lastToastedMoveSignature) {
      _lastToastedMoveSignature = moveSignature;
      final playerName =
          widget.snapshot.players[lastMoveByOther!.playerIndex].name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showToast(_describeLastMove(lastMoveByOther, playerName));
      });
    }

    // Server-/Host-seitige Statushinweise (z. B. Verbindungsstatus) waren
    // vorher als dauerhafte Box im unteren Panel eingebettet - wandern jetzt
    // ebenfalls als Toast, statt permanent Platz zu belegen.
    if (widget.statusText != null &&
        widget.statusText!.isNotEmpty &&
        widget.statusText != oldWidget.statusText) {
      final message = widget.statusText!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showToast(message);
      });
    }
  }

  void _toggleExchangeSelection(int handIndex) {
    setState(() {
      if (!_selectedForExchange.remove(handIndex)) {
        _selectedForExchange.add(handIndex);
      }
    });
  }

  void _stageTile(Map<Position, Tile> board, int handIndex, Position position) {
    if (!widget.canInteract) return;
    if (handIndex < 0 || handIndex >= widget.ownHand.length) return;
    if (_pendingPlacements.containsKey(position)) return;
    if (_handIndexByPosition.containsValue(handIndex)) return;

    final candidatePlacements = [
      for (final entry in _pendingPlacements.entries)
        TilePlacement(position: entry.key, tile: entry.value),
      TilePlacement(position: position, tile: widget.ownHand[handIndex]),
    ];
    final previewBoard = Board()
      ..apply([
        for (final entry in board.entries)
          TilePlacement(position: entry.key, tile: entry.value),
      ]);
    try {
      previewBoard.scorePlacement(candidatePlacements);
    } on InvalidMoveException catch (e) {
      HapticFeedback.mediumImpact();
      setState(() => _liveError = e.message);
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _pendingPlacements[position] = widget.ownHand[handIndex];
      _handIndexByPosition[position] = handIndex;
      _liveError = null;
    });
  }

  void _unstageTile(Position position) {
    setState(() {
      _pendingPlacements.remove(position);
      _handIndexByPosition.remove(position);
      _liveError = null;
    });
  }

  /// Punktwert der aktuell vorläufig platzierten Steine, live nachgerechnet
  /// - `null`, falls noch nichts platziert ist oder die Platzierung für
  /// sich genommen (noch) keinen gültigen Zug ergibt (z. B. Lücke in der
  /// Reihe). Reine Vorschau: der Server validiert beim tatsächlichen
  /// Senden ohnehin verbindlich, hier nur zur Live-Anzeige wie im lokalen
  /// Spiel (`GameController.pendingScore`).
  int? _pendingScore(Map<Position, Tile> board) {
    if (_pendingPlacements.isEmpty) return null;
    final previewBoard = Board()
      ..apply([
        for (final entry in board.entries)
          TilePlacement(position: entry.key, tile: entry.value),
      ]);
    try {
      return previewBoard.scorePlacement([
        for (final entry in _pendingPlacements.entries)
          TilePlacement(position: entry.key, tile: entry.value),
      ]);
    } catch (_) {
      // Reine Vorschau - eine (un)gültige Platzierung entscheidet
      // `_stageTile` bereits beim Ablegen; hier defensiv gegen jede
      // Ausnahme statt nur die erwartete `InvalidMoveException`, damit ein
      // unerwarteter Randfall niemals den ganzen Build-Vorgang mitreißt.
      return null;
    }
  }

  /// Kurze, menschenlesbare Zusammenfassung eines fremden Zugs - für ein
  /// Live-"was hat die andere Person gerade gemacht"-Feedback, spiegelt
  /// `lastBotSummary` im lokalen Spiel.
  String _describeLastMove(LastMoveInfo move, String playerName) {
    switch (move.kind) {
      case LastMoveKind.placed:
        final count = move.placements.length;
        final tileWord = count == 1 ? 'Stein' : 'Steine';
        final pointWord = move.score == 1 ? 'Punkt' : 'Punkte';
        return '$playerName hat $count $tileWord platziert (${move.score} $pointWord).';
      case LastMoveKind.exchanged:
        return '$playerName hat Steine getauscht.';
      case LastMoveKind.passed:
        return '$playerName hat den Zug übergangen.';
    }
  }

  /// Icon/Farbe/Text der zentralen, immer sichtbaren Statuszeile (siehe
  /// [GameBottomBar]) - priorisiert wie im lokalen Spiel
  /// (`GameScreen._statusIcon`/`_statusColor`/`_statusText`), aber mit
  /// eigenen (Netzwerk-spezifischen) Zuständen. Fehler bleiben bewusst
  /// AUSSERHALB dieser Priorisierung, in einer eigenen, immer sichtbaren
  /// Box (siehe [build]) - sonst würde z. B. eine Live-Validierungs­meldung
  /// die (weiterhin relevante) Punktevorschau der bereits vorbereiteten
  /// Platzierung verdecken, statt beides gleichzeitig zu zeigen.
  IconData _statusIcon(bool isMyTurn) {
    if (widget.snapshot.isOver) return Icons.celebration_outlined;
    if (_pendingPlacements.isNotEmpty) return Icons.add_circle_outline;
    if (!isMyTurn) return Icons.hourglass_empty;
    return Icons.play_circle_outline;
  }

  Color _statusColor(BuildContext context, bool isMyTurn) {
    if (widget.snapshot.isOver) return Colors.green.shade700;
    if (_pendingPlacements.isNotEmpty) return Colors.indigo.shade700;
    if (!isMyTurn) return Theme.of(context).colorScheme.outline;
    return Theme.of(context).colorScheme.primary;
  }

  String _statusText(
    Map<Position, Tile> board,
    bool isMyTurn,
    String currentPlayerName,
  ) {
    if (widget.snapshot.isOver) {
      return 'Die Partie ist beendet. Die Punkte werden nun ausgewertet.';
    }
    if (_pendingPlacements.isNotEmpty) {
      // Der Punktwert dieses Zugs steht jetzt als eigenes Badge oben rechts
      // über dem Brett (siehe [PendingScoreBadge]), statt hier als zweite
      // Zeile die Statuszeile aufzublähen - Nutzer-Feedback: das untere
      // Menü ist auf dem Handy beim eigenen Zug viel zu groß.
      return 'Zug vorbereitet – bestätige die Platzierung oder nimm sie zurück.';
    }
    // Nennt den Namen, statt nur generisch "auf den nächsten Zug" zu warten -
    // übernimmt damit die einzige Information, die vorher exklusiv in der
    // jetzt entfernten separaten "Aktueller Zug: X"-Zeile stand.
    if (!isMyTurn) {
      // Die Partie überspringt eine getrennte Person nicht automatisch
      // (siehe RoomSession-Doku) - ohne diesen Hinweis sähe das Warten
      // kommentarlos wie ein hängendes Spiel aus, statt erkennbar auf eine
      // Reconnect zu warten. Nutzer-Feedback: Benachrichtigung, wenn die
      // Person, die am Zug ist, nicht (mehr) im Spiel ist.
      final currentPlayerConnected =
          widget.snapshot.players[widget.snapshot.currentPlayerIndex].connected;
      if (!currentPlayerConnected) {
        return '$currentPlayerName ist nicht verbunden – die Partie wartet auf eine Rückkehr.';
      }
      return 'Warte auf $currentPlayerName.';
    }
    return 'Du bist am Zug. Ziehe einen Stein auf das Brett.';
  }

  /// Zentrales Overlay am Partie-Ende: Ergebnis + (nur für die Person mit
  /// Owner-Rechten) die Möglichkeit, eine neue Partie zu starten. Ersetzt
  /// die vormals nur inline in der Statusleiste angezeigte Ergebnisliste,
  /// bei der die Zug-/Tausch-/Aussetzen-Buttons für die Person, die den
  /// letzten Stein gelegt hat, danach fälschlich weiter bedienbar blieben.
  Widget _buildGameOverOverlay() {
    final players = widget.snapshot.players;
    final highestScore = players
        .map((p) => p.score)
        .reduce((a, b) => a > b ? a : b);
    final winners = players.where((p) => p.score == highestScore).toList();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                // Scrollbar statt Overflow, falls der verfügbare Platz für
                // die Ergebnisliste nicht reicht (viele Spieler:innen oder
                // ein niedriges Fenster).
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.celebration_outlined,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Partie beendet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        winners.length == 1
                            ? '${winners.first.name} gewinnt!'
                            : '${winners.map((p) => p.name).join(' & ')} gewinnen gemeinsam!',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      for (final player in players)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(player.name),
                              Text(
                                '${player.score} ${player.score == 1 ? 'Punkt' : 'Punkte'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (widget.isRoomOwner)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: widget.onRestartGame,
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Neues Spiel'),
                          ),
                        )
                      else
                        Text(
                          'Warte, bis der/die Raumersteller:in eine neue Partie startet.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Aussetzen ist nur möglich, wenn der Beutel leer ist - solange noch
  /// Steine im Beutel sind, kann stattdessen getauscht werden. Spiegelt
  /// dieselbe Einschränkung wie `canPass` im lokalen Spiel
  /// (`game_screen.dart`).
  Widget _buildActionButtons(bool isMyTurn) {
    final canAct = widget.canInteract && isMyTurn && !_isSending;
    final canPass =
        canAct &&
        widget.snapshot.bagRemaining == 0 &&
        _pendingPlacements.isEmpty;

    return Wrap(
      spacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (!_exchangeMode) ...[
          FilledButton(
            style: compactButtonStyle,
            onPressed: canAct && _pendingPlacements.isNotEmpty
                ? () async {
                    setState(() => _isSending = true);
                    final placements = [
                      for (final entry in _pendingPlacements.entries)
                        TilePlacement(position: entry.key, tile: entry.value),
                    ];
                    // Bewusst NICHT hier leeren: "gesendet" heißt bei einer
                    // Netzwerkpartie noch nicht "vom Server bestätigt" -
                    // das passiert erst in `didUpdateWidget`, sobald ein
                    // neuer Spielstand die Reihe tatsächlich weiterzieht.
                    // So bleibt die Platzierung sichtbar stehen, falls der
                    // Server den Zug ablehnt oder gar nicht antwortet,
                    // statt kommentarlos zu verschwinden.
                    await widget.onSendMove(placements);
                    if (!mounted) return;
                    setState(() => _isSending = false);
                  }
                : null,
            child: const Text('Zug senden'),
          ),
          OutlinedButton(
            style: compactButtonStyle,
            onPressed:
                widget.canInteract &&
                    _pendingPlacements.isNotEmpty &&
                    !_isSending
                ? () => setState(() {
                    _pendingPlacements.clear();
                    _handIndexByPosition.clear();
                    _liveError = null;
                  })
                : null,
            child: const Text('Zurücknehmen'),
          ),
        ] else
          FilledButton(
            style: compactButtonStyle,
            onPressed: canAct && _selectedForExchange.isNotEmpty
                ? () {
                    final tiles = [
                      for (final index in _selectedForExchange)
                        widget.ownHand[index],
                    ];
                    widget.onSendExchange(tiles);
                    setState(() {
                      _exchangeMode = false;
                      _selectedForExchange.clear();
                    });
                  }
                : null,
            child: const Text('Steine tauschen'),
          ),
        TextButton(
          style: compactButtonStyle,
          onPressed: canAct
              ? () => setState(() {
                  _exchangeMode = !_exchangeMode;
                  _selectedForExchange.clear();
                })
              : null,
          child: Text(_exchangeMode ? 'Abbrechen' : 'Steine tauschen…'),
        ),
        if (canPass)
          OutlinedButton(
            style: compactButtonStyle,
            onPressed: widget.onSendPass,
            child: const Text('Aussetzen'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMyTurn =
        widget.snapshot.currentPlayerIndex == widget.snapshot.yourPlayerIndex;
    final players = widget.snapshot.players
        .map(
          (player) =>
              Player(id: player.id, name: player.name, botDifficulty: null),
        )
        .toList();

    final currentPlayer = players[widget.snapshot.currentPlayerIndex];
    final board = <Position, Tile>{
      for (final placement in widget.snapshot.board)
        placement.position: placement.tile,
    };

    // Nur fremde Züge hervorheben/zusammenfassen - die eigenen kennt man ja
    // schon, da man sie selbst gerade platziert hat.
    final lastMove = widget.snapshot.lastMove;
    final lastMoveByOther =
        lastMove != null &&
            lastMove.playerIndex != widget.snapshot.yourPlayerIndex
        ? lastMove
        : null;
    final lastMovePositions = lastMoveByOther?.kind == LastMoveKind.placed
        ? {for (final p in lastMoveByOther!.placements) p.position}
        : const <Position>{};

    final pendingScore = _pendingScore(board);

    // Hand-"Slots": bereits vorläufig platzierte Steine erscheinen als
    // Lücke statt doppelt (in der Hand UND auf dem Brett) - siehe
    // `GameController.handSlots` im lokalen Spiel für dasselbe Muster.
    final handSlots = List<Tile?>.from(widget.ownHand);
    for (final index in _handIndexByPosition.values) {
      if (index < handSlots.length) handSlots[index] = null;
    }

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Qwirkle · ${widget.snapshot.bagRemaining} übrig'),
          actions: [
            if (widget.onLeaveRoom != null)
              IconButton(
                onPressed: widget.onLeaveRoom,
                icon: const Icon(Icons.logout),
                tooltip: 'Raum verlassen',
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              ScorePanel(
                players: players,
                currentIndex: widget.snapshot.currentPlayerIndex,
                scores: [for (final p in widget.snapshot.players) p.score],
                connected: [
                  for (final p in widget.snapshot.players) p.connected,
                ],
              ),
              Expanded(
                child: Stack(
                  children: [
                    BoardSurface(
                      board: board,
                      pendingPlacements: _pendingPlacements,
                      canInteract: widget.canInteract,
                      onDropTile: (handIndex, position) =>
                          _stageTile(board, handIndex, position),
                      onUnstage: _unstageTile,
                      cellSize: _cellSize,
                      tileSize: _tileSize,
                      highlightedPositions: lastMovePositions,
                    ),
                    if (pendingScore != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: PendingScoreBadge(
                          score: pendingScore,
                          totalAfter:
                              widget
                                  .snapshot
                                  .players[widget.snapshot.yourPlayerIndex]
                                  .score +
                              pendingScore,
                        ),
                      ),
                    if (_showStartPulse && !widget.snapshot.isOver)
                      Positioned.fill(
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Neue Partie gestartet',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    if ((_liveError ?? widget.errorText) != null ||
                        _showTutorial)
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Column(
                          children: [
                            if ((_liveError ?? widget.errorText) != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        (_liveError ?? widget.errorText)!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onErrorContainer,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (_showTutorial)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surface.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.15,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'So spielst du',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => setState(
                                            () => _showTutorial = false,
                                          ),
                                          child: const Text('Los geht’s'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Ziehe einen Stein aus deiner Hand auf das Brett und sende deinen Zug. Ziel ist es, Farben oder Formen in Reihen zu bilden.',
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (widget.snapshot.isOver) _buildGameOverOverlay(),
                  ],
                ),
              ),
              // Am Partie-Ende deckt das Ergebnis-Overlay
              // (`_buildGameOverOverlay`) bereits alles Nötige ab (inkl.
              // Neustart-Button), die Leiste entfällt dann.
              if (!widget.snapshot.isOver)
                GameBottomBar(
                  statusIcon: _statusIcon(isMyTurn),
                  statusText: _statusText(board, isMyTurn, currentPlayer.name),
                  statusColor: _statusColor(context, isMyTurn),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HandRow(
                        slots: handSlots,
                        canInteract: widget.canInteract,
                        exchangeMode: _exchangeMode,
                        selectedForExchange: _selectedForExchange,
                        onToggleExchange: _toggleExchangeSelection,
                      ),
                      const SizedBox(height: 6),
                      _buildActionButtons(isMyTurn),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
