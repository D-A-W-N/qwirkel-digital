import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_net/qwirkle_net.dart';

class NetworkGameView extends StatefulWidget {
  const NetworkGameView({
    super.key,
    required this.snapshot,
    required this.ownHand,
    required this.canInteract,
    required this.onSendMove,
    this.statusText,
  });

  final GameStateSnapshot snapshot;
  final List<Tile> ownHand;
  final bool canInteract;
  final Future<void> Function(List<TilePlacement> placements) onSendMove;
  final String? statusText;

  @override
  State<NetworkGameView> createState() => _NetworkGameViewState();
}

class _NetworkGameViewState extends State<NetworkGameView> {
  int? _selectedHandIndex;
  final Map<Position, Tile> _pendingPlacements = {};
  bool _isSending = false;
  bool _showStartPulse = true;
  bool _showTutorial = true;
  Timer? _startPulseTimer;

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
                    backgroundColor: active ? Colors.amber.shade200 : null,
                  );
                },
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  InteractiveViewer(
                    constrained: false,
                    minScale: 0.4,
                    maxScale: 2.5,
                    boundaryMargin: const EdgeInsets.all(400),
                    child: _BoardSurface(
                      board: board,
                      pendingPlacements: _pendingPlacements,
                      onSelectPosition: (position) {
                        if (_selectedHandIndex == null || !widget.canInteract) return;
                        setState(() {
                          _pendingPlacements[position] = widget.ownHand[_selectedHandIndex!];
                        });
                      },
                    ),
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
                              color: Colors.white,
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
                              'Wähle einen Stein aus deiner Hand, tippe auf das Brett und sende deinen Zug. Ziel ist es, Farben oder Formen in Reihen zu bilden.',
                            ),
                          ],
                        ),
                      ),
                    ),
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
                    height: 56,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.ownHand.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final tile = widget.ownHand[index];
                        final selected = _selectedHandIndex == index;
                        return GestureDetector(
                          key: ValueKey('hand-$index'),
                          onTap: widget.canInteract
                              ? () => setState(() => _selectedHandIndex = index)
                              : null,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : const Color(0xFF222222),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                tile.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                        );
                      },
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
                    child: Text(
                      widget.snapshot.isOver
                          ? 'Die Partie ist beendet. Die Punkte werden nun ausgewertet.'
                          : isMyTurn
                              ? 'Du bist am Zug. Wähle einen Stein und tippe auf das Brett.'
                              : 'Warte auf den nächsten Zug.',
                    ),
                  ),
                  if (widget.snapshot.isOver) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ergebnis',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          ...widget.snapshot.players.asMap().entries.map((entry) {
                            final player = entry.value;
                            final isWinner = widget.snapshot.players
                                .map((p) => p.score)
                                .reduce((a, b) => a > b ? a : b) == player.score &&
                                widget.snapshot.players
                                    .where((p) => p.score == player.score)
                                    .length ==
                                    1;
                            return Text(
                              '${player.name}: ${player.score} ${player.score == 1 ? 'Punkt' : 'Punkte'}${isWinner ? ' (Gewinner)' : ''}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: widget.canInteract && isMyTurn && _pendingPlacements.isNotEmpty && !_isSending
                        ? () async {
                            setState(() => _isSending = true);
                            final placements = [
                              for (final entry in _pendingPlacements.entries)
                                TilePlacement(position: entry.key, tile: entry.value),
                            ];
                            await widget.onSendMove(placements);
                            setState(() {
                              _pendingPlacements.clear();
                              _selectedHandIndex = null;
                              _isSending = false;
                            });
                          }
                        : null,
                    child: const Text('Zug senden'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardSurface extends StatelessWidget {
  const _BoardSurface({
    required this.board,
    required this.pendingPlacements,
    required this.onSelectPosition,
  });

  final Map<Position, Tile> board;
  final Map<Position, Tile> pendingPlacements;
  final void Function(Position position) onSelectPosition;

  @override
  Widget build(BuildContext context) {
    final positions = board.keys.toList();
    if (positions.isEmpty) {
      positions.add(Position(0, 0));
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

    final cellSize = 64.0;
    final boardPositions = <Position>[];
    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        boardPositions.add(Position(x, y));
      }
    }
    final cols = maxX - minX + 1;
    final rows = maxY - minY + 1;

    return SizedBox(
      width: cols * cellSize,
      height: rows * cellSize,
      child: Stack(
        children: [
          for (final position in boardPositions)
            Positioned(
              left: (position.x - minX) * cellSize,
              top: (position.y - minY) * cellSize,
              width: cellSize,
              height: cellSize,
              child: GestureDetector(
                key: ValueKey('board-${position.x}-${position.y}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelectPosition(position),
                child: Center(
                  child: _BoardCell(
                    position: position,
                    tile: board[position] ?? pendingPlacements[position],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BoardCell extends StatelessWidget {
  const _BoardCell({required this.position, required this.tile});

  final Position position;
  final Tile? tile;

  @override
  Widget build(BuildContext context) {
    if (tile == null) {
      return Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white10),
        ),
      );
    }

    return Center(
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            tile!.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
      ),
    );
  }
}

