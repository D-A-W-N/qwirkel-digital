import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qwirkle_core/qwirkle_core.dart';

import 'game_providers.dart';
import 'widgets/board_view.dart';
import 'widgets/hand_view.dart';
import 'widgets/score_panel.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _exchangeMode = false;
  bool _gameOverShown = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(gameControllerProvider);
    final game = controller.game;

    if (game.isOver && !_gameOverShown) {
      _gameOverShown = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showGameOverDialog(context, game),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Qwirkle · Beutel: ${game.bag.remaining}')),
      body: SafeArea(
        child: Column(
          children: [
            ScorePanel(
              players: game.players,
              currentIndex: game.currentPlayerIndex,
            ),
            if (controller.lastError != null)
              Container(
                width: double.infinity,
                color: Colors.red.shade100,
                padding: const EdgeInsets.all(8),
                child: Text(
                  controller.lastError!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            const Expanded(child: BoardView()),
            _ControlPanel(
              exchangeMode: _exchangeMode,
              onToggleMode: () {
                setState(() => _exchangeMode = !_exchangeMode);
                controller.resetPendingPlacements();
                controller.clearExchangeSelection();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGameOverDialog(BuildContext context, QwirkleGame game) {
    final standings = [...game.players]
      ..sort((a, b) => b.score.compareTo(a.score));
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Spiel beendet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < standings.length; i++)
              Text(
                '${i + 1}. ${standings[i].name}: ${standings[i].score} Punkte',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context)
              ..pop()
              ..pop(),
            child: const Text('Zurück zum Menü'),
          ),
        ],
      ),
    );
  }
}

class _ControlPanel extends ConsumerWidget {
  final bool exchangeMode;
  final VoidCallback onToggleMode;

  const _ControlPanel({required this.exchangeMode, required this.onToggleMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(gameControllerProvider);
    final canPass =
        controller.game.bag.isEmpty && !controller.hasPendingPlacements;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HandView(exchangeMode: exchangeMode),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (!exchangeMode) ...[
                ElevatedButton(
                  onPressed: controller.hasPendingPlacements
                      ? controller.confirmMove
                      : null,
                  child: const Text('Zug bestätigen'),
                ),
                OutlinedButton(
                  onPressed: controller.hasPendingPlacements
                      ? controller.resetPendingPlacements
                      : null,
                  child: const Text('Zurücknehmen'),
                ),
              ] else
                ElevatedButton(
                  onPressed: controller.hasExchangeSelection
                      ? controller.confirmExchange
                      : null,
                  child: const Text('Steine tauschen'),
                ),
              TextButton(
                onPressed: onToggleMode,
                child: Text(exchangeMode ? 'Abbrechen' : 'Steine tauschen…'),
              ),
              if (canPass)
                OutlinedButton(
                  onPressed: controller.passTurn,
                  child: const Text('Aussetzen'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
