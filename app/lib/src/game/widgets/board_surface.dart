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
    final occupied = {...board.keys, ...pendingPlacements.keys};
    final positions = occupied.isEmpty ? {const Position(0, 0)} : occupied;

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

    // Statt eines vollen Rechtecks über die Bounding Box (mit ±2 Feldern
    // Rand) nur tatsächlich belegte Felder plus zwei "Ringe" freier
    // Nachbarfelder rendern: Ring 1 sind die einzigen Felder, an denen
    // überhaupt legal neu angelegt werden kann (siehe `anchorPositions` -
    // dieselbe Definition, die auch der Bot für seine Zuggenerierung
    // verwendet), Ring 2 ist rein kosmetischer Rand darum. Bei weit
    // auseinandergezogenen Zügen (z. B. Brücken-Züge über ein bestehendes
    // Feld hinweg) wuchs die alte Rechteck-Fläche quadratisch mit dem
    // Abstand zwischen den Clustern, obwohl der leere Raum dazwischen nie
    // interaktiv war - je nach Boardform potenziell hunderte nutzlose
    // Drop-Ziele pro Frame.
    final ring1 = anchorPositions(occupied);
    final ring2 = anchorPositions({...occupied, ...ring1});
    final boardPositions = {...occupied, ...ring1, ...ring2};

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
              // Isoliert das Neuzeichnen jeder Zelle von ihren Nachbarn: der
              // umgebende `GameController`/`GameStateSnapshot` benachrichtigt
              // bei JEDER Änderung (Punktestand, Statustext, Hand), nicht nur
              // bei Board-Änderungen - ohne Grenze würde ein unveränderter
              // Stein (mit eigenem `CustomPaint` in `TileView`) bei jedem
              // dieser Rebuilds trotzdem neu gezeichnet.
              child: RepaintBoundary(
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
          // Pink/Magenta statt Amber: Amber liegt farblich zu nah an der
          // orangen Qwirkle-Steinfarbe und ging dort optisch unter -
          // Nutzer-Feedback, die Hervorhebung fremder Züge sei nicht
          // auffällig genug. Pink kommt in keiner Stein-Palette vor.
          highlightColor: Colors.pinkAccent,
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
