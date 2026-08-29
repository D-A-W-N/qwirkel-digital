import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_providers.dart';
import 'board_surface.dart';

/// Zeigt das (unbegrenzte) Spielbrett des lokalen Spiels - dünner
/// Riverpod-Adapter um [BoardSurface], das eigentliche (prop-basierte)
/// Rendering ist mit dem Netzwerkspiel geteilt.
class BoardView extends ConsumerWidget {
  const BoardView({super.key});

  static const double cellSize = 56;
  static const double tileSize = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(gameControllerProvider);
    return BoardSurface(
      board: controller.game.board.cells,
      pendingPlacements: controller.pendingPlacements,
      // Interaktivität wird hier schon extern über `IgnorePointer` in
      // `game_screen.dart` gesteuert - anders als im Netzwerkspiel, das
      // keinen solchen Wrapper hat und stattdessen [BoardSurface.canInteract]
      // selbst auswertet.
      canInteract: true,
      onDropTile: controller.stageTile,
      onUnstage: controller.unstageTile,
      cellSize: cellSize,
      tileSize: tileSize,
      highlightedPositions: controller.lastBotPlacements,
      hasSelection: controller.selectedHandIndex != null,
      onTapEmptyCell: (position) {
        final index = controller.selectedHandIndex;
        if (index != null) controller.stageTile(index, position);
      },
    );
  }
}
