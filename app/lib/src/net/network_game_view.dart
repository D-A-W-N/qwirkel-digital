import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_net/qwirkle_net.dart';

import '../game/widgets/board_geometry.dart';
import '../game/widgets/centered_board_viewport.dart';
import '../game/widgets/tile_view.dart';

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
    if (widget.snapshot.currentPlayerIndex != oldWidget.snapshot.currentPlayerIndex &&
        widget.snapshot.currentPlayerIndex != widget.snapshot.yourPlayerIndex) {
      if (_pendingPlacements.isNotEmpty) {
        _pendingPlacements.clear();
        _handIndexByPosition.clear();
      }
      if (_exchangeMode || _selectedForExchange.isNotEmpty) {
        _exchangeMode = false;
        _selectedForExchange.clear();
      }
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

  String _statusText(Map<Position, Tile> board, bool isMyTurn) {
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
    if (!isMyTurn) return 'Warte auf den nächsten Zug.';
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
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: players.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final player = players[index];
                  final active = index == widget.snapshot.currentPlayerIndex;
                  return Chip(
                    avatar: active ? const Icon(Icons.play_arrow, size: 18) : null,
                    label: Text('${player.name}: ${widget.snapshot.players[index].score} ${widget.snapshot.players[index].score == 1 ? 'Punkt' : 'Punkte'}'),
                    backgroundColor: active
                        ? Theme.of(context).colorScheme.tertiaryContainer
                        : null,
                  );
                },
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  _BoardSurface(
                    board: board,
                    pendingPlacements: _pendingPlacements,
                    canInteract: widget.canInteract,
                    onDropTile: (handIndex, position) => _stageTile(board, handIndex, position),
                    onUnstage: _unstageTile,
                    highlightedPositions: lastMovePositions,
                  ),
                  if (_showStartPulse && !widget.snapshot.isOver)
                    Positioned.fill(
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Neue Partie gestartet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_showTutorial)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
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
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => setState(() => _showTutorial = false),
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
                    ),
                  if (widget.snapshot.isOver) _buildGameOverOverlay(),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lastMoveSummary != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
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
                  if ((_liveError ?? widget.errorText) != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
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
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.statusText != null && widget.statusText!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
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
                    widget.snapshot.isOver
                        ? 'Partie beendet'
                        : 'Aktueller Zug: ${currentPlayer.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Du spielst als ${myPlayer.name}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 64,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var index = 0; index < handSlots.length; index++)
                          _HandSlot(
                            key: ValueKey('hand-$index'),
                            index: index,
                            tile: handSlots[index],
                            canInteract: widget.canInteract,
                            exchangeMode: _exchangeMode,
                            selectedForExchange: _selectedForExchange.contains(index),
                            onToggleExchange: () => _toggleExchangeSelection(index),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deine Hand: ${widget.snapshot.players[widget.snapshot.yourPlayerIndex].handCount} Steine',
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_statusText(board, isMyTurn)),
                  ),
                  if (!widget.snapshot.isOver) ...[
                    const SizedBox(height: 8),
                    _buildActionButtons(isMyTurn),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HandSlot extends StatelessWidget {
  const _HandSlot({
    super.key,
    required this.index,
    required this.tile,
    required this.canInteract,
    required this.exchangeMode,
    required this.selectedForExchange,
    required this.onToggleExchange,
  });

  final int index;
  final Tile? tile;
  final bool canInteract;
  final bool exchangeMode;
  final bool selectedForExchange;
  final VoidCallback onToggleExchange;

  @override
  Widget build(BuildContext context) {
    final currentTile = tile;
    if (currentTile == null) {
      return const SizedBox(width: 48, height: 48);
    }
    if (!canInteract) {
      return TileView(tile: currentTile);
    }
    if (exchangeMode) {
      return GestureDetector(
        onTap: onToggleExchange,
        child: TileView(tile: currentTile, highlighted: selectedForExchange),
      );
    }
    return Draggable<int>(
      data: index,
      feedback: Material(
        color: Colors.transparent,
        child: TileView(tile: currentTile, size: 56),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: TileView(tile: currentTile),
      ),
      child: TileView(tile: currentTile),
    );
  }
}

class _BoardSurface extends StatelessWidget {
  const _BoardSurface({
    required this.board,
    required this.pendingPlacements,
    required this.canInteract,
    required this.onDropTile,
    required this.onUnstage,
    this.highlightedPositions = const {},
  });

  final Map<Position, Tile> board;
  final Map<Position, Tile> pendingPlacements;
  final bool canInteract;
  final void Function(int handIndex, Position position) onDropTile;
  final void Function(Position position) onUnstage;

  /// Zuletzt von einer ANDEREN Person platzierte Steine - kurz hervorgehoben,
  /// damit sichtbar ist, was gerade passiert ist (spiegelt die
  /// Bot-Zug-Hervorhebung im lokalen Spiel).
  final Set<Position> highlightedPositions;

  static const double cellSize = 64;

  @override
  Widget build(BuildContext context) {
    // Vorläufige (noch nicht gesendete) Platzierungen zählen mit in die
    // Bounding Box, damit sich der sichtbare Bereich schon während des
    // eigenen Zugs erweitert, statt erst nach dem nächsten Snapshot vom
    // Server - spiegelt `BoardView`s lokales Verhalten.
    final positions = [...board.keys, ...pendingPlacements.keys];
    if (positions.isEmpty) {
      positions.add(const Position(0, 0));
    }

    var minX = positions.first.x;
    var maxX = positions.first.x;
    var minY = positions.first.y;
    var maxY = positions.first.y;

    for (final position in positions) {
      minX = minX < position.x ? minX : position.x;
      maxX = maxX > position.x ? maxX : position.x;
      minY = minY < position.y ? minY : position.y;
      maxY = maxY > position.y ? maxY : position.y;
    }

    minX -= 2;
    maxX += 2;
    minY -= 2;
    maxY += 2;

    final boardPositions = <Position>[];
    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        boardPositions.add(Position(x, y));
      }
    }

    const geometry = BoardGeometry(cellSize);

    return CenteredBoardViewport(
      contentSize: Size(geometry.totalSize, geometry.totalSize),
      focalPoint: Offset(
        geometry.pixelX(((minX + maxX) / 2).round()),
        geometry.pixelY(((minY + maxY) / 2).round()),
      ),
      child: Stack(
        children: [
          for (final position in boardPositions)
            Positioned(
              left: geometry.pixelX(position.x),
              top: geometry.pixelY(position.y),
              width: cellSize,
              height: cellSize,
              child: _BoardCell(
                key: ValueKey('board-${position.x}-${position.y}'),
                position: position,
                existingTile: board[position],
                pendingTile: pendingPlacements[position],
                canInteract: canInteract,
                onDropTile: onDropTile,
                onUnstage: onUnstage,
                highlighted: highlightedPositions.contains(position),
              ),
            ),
        ],
      ),
    );
  }
}

class _BoardCell extends StatelessWidget {
  const _BoardCell({
    super.key,
    required this.position,
    required this.existingTile,
    required this.pendingTile,
    required this.canInteract,
    required this.onDropTile,
    required this.onUnstage,
    this.highlighted = false,
  });

  final Position position;
  final Tile? existingTile;
  final Tile? pendingTile;
  final bool canInteract;
  final void Function(int handIndex, Position position) onDropTile;
  final void Function(Position position) onUnstage;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final existing = existingTile;
    if (existing != null) {
      return Center(
        child: TileView(
          tile: existing,
          size: _BoardSurface.cellSize - 16,
          highlighted: highlighted,
          highlightColor: Colors.amber,
        ),
      );
    }

    final pending = pendingTile;
    if (pending != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canInteract ? () => onUnstage(position) : null,
        child: Center(
          child: TileView(
            tile: pending,
            size: _BoardSurface.cellSize - 16,
            highlighted: true,
          ),
        ),
      );
    }

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => canInteract,
      onAcceptWithDetails: (details) => onDropTile(details.data, position),
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: active ? colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(
              color: active
                  ? colorScheme.primary.withValues(alpha: 0.6)
                  : colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
        );
      },
    );
  }
}
