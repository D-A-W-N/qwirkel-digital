import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qwirkle_core/qwirkle_core.dart';

import '../game_providers.dart';
import 'tile_view.dart';

/// Zeigt das (unbegrenzte) Spielbrett als pan-/zoombares Raster.
///
/// Leere Felder sind Drop-Ziele für Steine aus der Hand; belegte und
/// vorläufig platzierte Felder zeigen den jeweiligen Stein.
class BoardView extends ConsumerWidget {
  const BoardView({super.key});

  static const double cellSize = 56;
  static const int margin = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(gameControllerProvider);
    final positions = [
      ...controller.game.board.cells.keys,
      ...controller.pendingPlacements.keys,
    ];

    var minX = 0, maxX = 0, minY = 0, maxY = 0;
    if (positions.isNotEmpty) {
      minX = positions.map((p) => p.x).reduce((a, b) => a < b ? a : b);
      maxX = positions.map((p) => p.x).reduce((a, b) => a > b ? a : b);
      minY = positions.map((p) => p.y).reduce((a, b) => a < b ? a : b);
      maxY = positions.map((p) => p.y).reduce((a, b) => a > b ? a : b);
    }
    minX -= margin;
    maxX += margin;
    minY -= margin;
    maxY += margin;

    final cols = maxX - minX + 1;
    final rows = maxY - minY + 1;

    return InteractiveViewer(
      constrained: false,
      minScale: 0.4,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(400),
      child: SizedBox(
        width: cols * cellSize,
        height: rows * cellSize,
        child: Stack(
          children: [
            for (var x = minX; x <= maxX; x++)
              for (var y = minY; y <= maxY; y++)
                Positioned(
                  left: (x - minX) * cellSize,
                  top: (y - minY) * cellSize,
                  width: cellSize,
                  height: cellSize,
                  child: _BoardCell(position: Position(x, y)),
                ),
          ],
        ),
      ),
    );
  }
}

class _BoardCell extends ConsumerWidget {
  final Position position;

  const _BoardCell({required this.position});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(gameControllerProvider);
    final existing = controller.game.board.tileAt(position);
    if (existing != null) {
      return Center(
        child: TileView(tile: existing, size: BoardView.cellSize - 8),
      );
    }

    final pendingTile = controller.pendingPlacements[position];
    if (pendingTile != null) {
      return GestureDetector(
        onTap: () => controller.unstageTile(position),
        child: Center(
          child: TileView(
            tile: pendingTile,
            size: BoardView.cellSize - 8,
            highlighted: true,
          ),
        ),
      );
    }

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) =>
          controller.stageTile(details.data, position),
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
