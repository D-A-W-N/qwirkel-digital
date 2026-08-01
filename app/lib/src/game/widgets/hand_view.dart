import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qwirkle_core/qwirkle_core.dart';

import '../game_providers.dart';
import 'tile_view.dart';

/// Zeigt die Hand des aktuellen Spielers.
///
/// Im normalen Modus sind die Steine per Drag&Drop auf das Brett ziehbar.
/// Im Tausch-Modus lassen sie sich stattdessen antippen, um sie für den
/// Steinetausch auszuwählen.
class HandView extends ConsumerWidget {
  final bool exchangeMode;

  const HandView({super.key, required this.exchangeMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(gameControllerProvider);
    final slots = controller.handSlots;

    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < slots.length; i++)
            _HandSlot(index: i, tile: slots[i], exchangeMode: exchangeMode),
        ],
      ),
    );
  }
}

class _HandSlot extends ConsumerWidget {
  final int index;
  final Tile? tile;
  final bool exchangeMode;

  const _HandSlot({
    required this.index,
    required this.tile,
    required this.exchangeMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTile = tile;
    if (currentTile == null) {
      return const SizedBox(width: 48, height: 48);
    }

    final controller = ref.watch(gameControllerProvider);

    if (exchangeMode) {
      final selected = controller.selectedForExchange.contains(index);
      return GestureDetector(
        onTap: () => controller.toggleExchangeSelection(index),
        child: TileView(tile: currentTile, highlighted: selected),
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
