import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_net/qwirkle_net.dart';

import '../game/widgets/board_surface.dart';
import '../game/widgets/game_bottom_bar.dart';
import '../game/widgets/hand_view.dart';
import '../game/widgets/score_panel.dart';
import '../game/widgets/turn_dialog.dart';

class NetworkGameView extends StatefulWidget {
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
    this.statusText,
    this.errorText,
  });

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

  @override
  void initState() {
    super.initState();
    _startPulseTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _showStartPulse = false);
      }
    });
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
        widget.snapshot.currentPlayerIndex != oldWidget.snapshot.currentPlayerIndex &&
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
        oldWidget.snapshot.currentPlayerIndex != widget.snapshot.currentPlayerIndex;
    if (becameMyTurn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showTurnDialog(context, message: 'Du bist jetzt am Zug.');
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
      setState(() => _liveError = e.message);
      return;
    }

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
      final score = _pendingScore(board);
      // Zwei getrennte Zahlen, damit der Punktwert dieses einen Zugs nicht
      // mit dem laufenden Gesamtstand der Partie verwechselt wird - siehe
      // dieselbe Unterscheidung im lokalen Spiel (`GameController`).
      final scoreSuffix = score != null
          ? '\nDieser Zug: $score Punkt${score == 1 ? '' : 'e'} '
                '· Gesamt danach: ${widget.snapshot.players[widget.snapshot.yourPlayerIndex].score + score}'
          : '';
      return 'Zug vorbereitet – bestätige die Platzierung oder nimm sie zurück.$scoreSuffix';
    }
    // Nennt den Namen, statt nur generisch "auf den nächsten Zug" zu warten -
    // übernimmt damit die einzige Information, die vorher exklusiv in der
    // jetzt entfernten separaten "Aktueller Zug: X"-Zeile stand.
    if (!isMyTurn) return 'Warte auf $currentPlayerName.';
    return 'Du bist am Zug. Ziehe einen Stein auf das Brett.';
  }

  /// Zentrales Overlay am Partie-Ende: Ergebnis + (nur für die Person mit
  /// Owner-Rechten) die Möglichkeit, eine neue Partie zu starten. Ersetzt
  /// die vormals nur inline in der Statusleiste angezeigte Ergebnisliste,
  /// bei der die Zug-/Tausch-/Aussetzen-Buttons für die Person, die den
  /// letzten Stein gelegt hat, danach fälschlich weiter bedienbar blieben.
  Widget _buildGameOverOverlay() {
    final players = widget.snapshot.players;
    final highestScore = players.map((p) => p.score).reduce((a, b) => a > b ? a : b);
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
                                style: const TextStyle(fontWeight: FontWeight.bold),
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
    final canPass = canAct && widget.snapshot.bagRemaining == 0 && _pendingPlacements.isEmpty;

    return Wrap(
      spacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (!_exchangeMode) ...[
          FilledButton(
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
            onPressed: widget.canInteract && _pendingPlacements.isNotEmpty && !_isSending
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
            onPressed: canAct && _selectedForExchange.isNotEmpty
                ? () {
                    final tiles = [
                      for (final index in _selectedForExchange) widget.ownHand[index],
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
            onPressed: widget.onSendPass,
            child: const Text('Aussetzen'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMyTurn = widget.snapshot.currentPlayerIndex == widget.snapshot.yourPlayerIndex;
    final players = widget.snapshot.players
        .map(
          (player) => Player(
            id: player.id,
            name: player.name,
            botDifficulty: null,
          ),
        )
        .toList();

    final currentPlayer = players[widget.snapshot.currentPlayerIndex];
    final myPlayer = players[widget.snapshot.yourPlayerIndex];
    final board = <Position, Tile>{
      for (final placement in widget.snapshot.board)
        placement.position: placement.tile,
    };

    // Nur fremde Züge hervorheben/zusammenfassen - die eigenen kennt man ja
    // schon, da man sie selbst gerade platziert hat.
    final lastMove = widget.snapshot.lastMove;
    final lastMoveByOther =
        lastMove != null && lastMove.playerIndex != widget.snapshot.yourPlayerIndex
        ? lastMove
        : null;
    final lastMovePositions = lastMoveByOther?.kind == LastMoveKind.placed
        ? {for (final p in lastMoveByOther!.placements) p.position}
        : const <Position>{};
    final lastMoveSummary = lastMoveByOther == null
        ? null
        : _describeLastMove(lastMoveByOther, players[lastMoveByOther.playerIndex].name);

    // Hand-"Slots": bereits vorläufig platzierte Steine erscheinen als
    // Lücke statt doppelt (in der Hand UND auf dem Brett) - siehe
    // `GameController.handSlots` im lokalen Spiel für dasselbe Muster.
    final handSlots = List<Tile?>.from(widget.ownHand);
    for (final index in _handIndexByPosition.values) {
      if (index < handSlots.length) handSlots[index] = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Qwirkle · ${widget.snapshot.bagRemaining} übrig'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            ScorePanel(
              players: players,
              currentIndex: widget.snapshot.currentPlayerIndex,
              scores: [for (final p in widget.snapshot.players) p.score],
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
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                          ),
                        ),
                      ),
                    ),
                  if ((_liveError ?? widget.errorText) != null ||
                      lastMoveSummary != null ||
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
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      (_liveError ?? widget.errorText)!,
                                      style: Theme.of(context).textTheme.bodyMedium
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
                          if (lastMoveSummary != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.history, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      lastMoveSummary,
                                      style: Theme.of(context).textTheme.bodyMedium,
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
                                    color: Colors.black.withValues(alpha: 0.15),
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
                                        onPressed: () =>
                                            setState(() => _showTutorial = false),
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
                    if (widget.statusText != null &&
                        widget.statusText!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.statusText!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Du spielst als ${myPlayer.name}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    HandRow(
                      slots: handSlots,
                      canInteract: widget.canInteract,
                      exchangeMode: _exchangeMode,
                      selectedForExchange: _selectedForExchange,
                      onToggleExchange: _toggleExchangeSelection,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Deine Hand: ${widget.snapshot.players[widget.snapshot.yourPlayerIndex].handCount} Steine',
                    ),
                    const SizedBox(height: 8),
                    _buildActionButtons(isMyTurn),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

