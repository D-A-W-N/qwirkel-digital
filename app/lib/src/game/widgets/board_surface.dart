import 'package:flutter/material.dart';
import 'package:qwirkle_core/qwirkle_core.dart';

import 'board_geometry.dart';
import 'centered_board_viewport.dart';
import 'tile_view.dart';

/// Präsentationelle (rein prop-basierte, kein Riverpod/Netzwerk-Zustand)
/// Darstellung des Spielbretts - von lokalem und Netzwerk-Spiel gemeinsam
/// genutzt, damit Layout-/Verhaltensänderungen nicht zweimal gepflegt werden
/// müssen. [cellSize]/[tileSize] bleiben Konstruktor-Parameter, damit beide
/// Aufrufer ihre bisherige optische Größe unverändert beibehalten.
class BoardSurface extends StatelessWidget {
  const BoardSurface({
    super.key,
    required this.board,
    required this.pendingPlacements,
    required this.canInteract,
    required this.onDropTile,
    required this.onUnstage,
    required this.cellSize,
    required this.tileSize,
    this.highlightedPositions = const {},
  });

  final Map<Position, Tile> board;
  final Map<Position, Tile> pendingPlacements;
  final bool canInteract;
  final void Function(int handIndex, Position position) onDropTile;
  final void Function(Position position) onUnstage;
  final double cellSize;
  final double tileSize;

  /// Zuletzt platzierte Steine (Bot-Zug lokal, fremder Zug im Netzwerkspiel)
  /// - kurz hervorgehoben, damit sichtbar ist, was gerade passiert ist.
  final Set<Position> highlightedPositions;

  @override
  Widget build(BuildContext context) {
    // Vorläufige (noch nicht bestätigte) Platzierungen zählen mit in die
    // Bounding Box, damit sich der sichtbare Bereich schon während des
    // eigenen Zugs erweitert, statt erst nach dem nächsten bestätigten
    // Spielstand.
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

    final geometry = BoardGeometry(cellSize);

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
                tileSize: tileSize,
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
    required this.tileSize,
    this.highlighted = false,
  });

  final Position position;
  final Tile? existingTile;
  final Tile? pendingTile;
  final bool canInteract;
  final void Function(int handIndex, Position position) onDropTile;
  final void Function(Position position) onUnstage;
  final double tileSize;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final existing = existingTile;
    if (existing != null) {
      return Center(
        child: TileView(
          tile: existing,
          size: tileSize,
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
          child: TileView(tile: pending, size: tileSize, highlighted: true),
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
            color: active
                ? colorScheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
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
