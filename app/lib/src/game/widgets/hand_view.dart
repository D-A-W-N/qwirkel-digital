import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qwirkle_core/qwirkle_core.dart';

import '../game_providers.dart';
import 'tile_view.dart';

/// Zeigt die Hand des aktuellen Spielers (lokales Spiel) - dünner
/// Riverpod-Adapter um [HandRow], das eigentliche (prop-basierte) Rendering
/// ist mit dem Netzwerkspiel geteilt.
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
    return HandRow(
      slots: controller.handSlots,
      // Interaktivität wird hier schon extern über `IgnorePointer` in
      // `_ControlPanel` gesteuert (siehe `game_screen.dart`) - anders als
      // im Netzwerkspiel, das keinen solchen Wrapper hat und stattdessen
      // [HandRow.canInteract] selbst auswertet.
      canInteract: true,
      exchangeMode: exchangeMode,
      selectedForExchange: controller.selectedForExchange,
      onToggleExchange: controller.toggleExchangeSelection,
      selectedHandIndex: controller.selectedHandIndex,
      onSelectHandTile: controller.selectHandTile,
    );
  }
}

/// Präsentationelle (rein prop-basierte) Zeile aller Hand-Slots - von
/// lokalem und Netzwerk-Spiel gemeinsam genutzt.
class HandRow extends StatelessWidget {
  const HandRow({
    super.key,
    required this.slots,
    required this.canInteract,
    required this.exchangeMode,
    required this.selectedForExchange,
    required this.onToggleExchange,
    this.selectedHandIndex,
    this.onSelectHandTile,
  });

  final List<Tile?> slots;
  final bool canInteract;
  final bool exchangeMode;
  final Set<int> selectedForExchange;
  final void Function(int handIndex) onToggleExchange;

  /// Tap-to-Place-Alternative zu Drag&Drop (siehe `GameController
  /// .selectHandTile`/`BoardSurface.onTapEmptyCell`) - `null` (Standard)
  /// deaktiviert die Tap-Auswahl vollständig, ohne Drag&Drop selbst zu
  /// beeinträchtigen.
  final int? selectedHandIndex;
  final void Function(int handIndex)? onSelectHandTile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < slots.length; i++)
            HandSlot(
              key: ValueKey('hand-$i'),
              index: i,
              tile: slots[i],
              canInteract: canInteract,
              exchangeMode: exchangeMode,
              selectedForExchange: selectedForExchange.contains(i),
              onToggleExchange: () => onToggleExchange(i),
              selected: selectedHandIndex == i,
              onSelect: onSelectHandTile == null
                  ? null
                  : () => onSelectHandTile!(i),
            ),
        ],
      ),
    );
  }
}

class HandSlot extends StatelessWidget {
  const HandSlot({
    super.key,
    required this.index,
    required this.tile,
    required this.canInteract,
    required this.exchangeMode,
    required this.selectedForExchange,
    required this.onToggleExchange,
    this.selected = false,
    this.onSelect,
  });

  final int index;
  final Tile? tile;
  final bool canInteract;
  final bool exchangeMode;
  final bool selectedForExchange;
  final VoidCallback onToggleExchange;

  /// Siehe `HandRow.selectedHandIndex`/`onSelectHandTile`.
  final bool selected;
  final VoidCallback? onSelect;

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
    // Drag&Drop bleibt unverändert nutzbar; zusätzlich macht Antippen
    // denselben Stein für die Tap-to-Place-Alternative auswählbar (siehe
    // `BoardSurface.onTapEmptyCell`) - beide Bedienwege koexistieren.
    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? 'Stein ausgewählt, erneut antippen zum Abwählen'
          : 'Stein auswählen',
      child: GestureDetector(
        onTap: onSelect,
        child: Draggable<int>(
          data: index,
          feedback: Material(
            color: Colors.transparent,
            child: TileView(tile: currentTile, size: 56),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: TileView(tile: currentTile),
          ),
          child: TileView(tile: currentTile, highlighted: selected),
        ),
      ),
    );
  }
}
