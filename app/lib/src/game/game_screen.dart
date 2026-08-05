import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qwirkle_core/qwirkle_core.dart';

import '../settings/app_settings.dart';
import 'game_controller.dart';
import 'game_providers.dart';
import 'widgets/board_view.dart';
import 'widgets/collapsible_game_panel.dart';
import 'widgets/hand_view.dart';
import 'widgets/score_panel.dart';
import 'widgets/turn_dialog.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _exchangeMode = false;
  bool _gameOverShown = false;
  Timer? _botTimer;

  /// Ob das untere Panel (Hand + Buttons) gerade ausgeklappt ist - startet
  /// ausgeklappt (vertraut, Hand sofort sichtbar) und klappt sich danach
  /// automatisch wieder auf, sobald eine menschliche Person am Zug ist,
  /// bleibt aber jederzeit manuell ein-/ausklappbar. Ein eingeklapptes
  /// Panel lässt dem Brett fast die volle Bildschirmhöhe - siehe
  /// Nutzer-Feedback zu wenig Spielfläche bei großer Systemschrift/Zoom.
  bool _panelExpanded = true;

  /// Letzter `currentPlayerIndex`, für den der "Du bist am Zug"-Hinweis
  /// (Panel-Ausklappen + Dialog) schon ausgelöst wurde - verhindert
  /// Mehrfachauslösung pro Zug und dass ein manuelles Einklappen sofort im
  /// selben Zug wieder rückgängig gemacht wird. `null` markiert "noch nie
  /// ausgelöst", damit der allererste Zug der Partie eine leicht andere
  /// Formulierung bekommt (ersetzt den vormaligen einmaligen Start-Snackbar
  /// - Nutzer-Feedback: der Zugwechsel war nicht immer sofort ersichtlich,
  /// besonders beim lokalen Hotseat-Wechsel zwischen Personen).
  int? _lastTurnAnnouncedIndex;

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(gameControllerProvider);
    final settings = ref.watch(appSettingsProvider);
    final game = controller.game;

    if (game.isOver && !_gameOverShown) {
      _gameOverShown = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showGameOverDialog(context, game),
      );
    } else if (!game.isOver && controller.isCurrentPlayerBot) {
      _scheduleBotTurn(controller, settings.botSpeed);
    }

    // Sobald eine menschliche Person am Zug ist (Wechsel weg vom Bot ODER
    // Wechsel zur nächsten Person im lokalen Hotseat), klappt das Panel
    // automatisch wieder auf UND ein wegklickbarer Dialog macht den
    // Zugwechsel unübersehbar - eine manuelle Zwischenzeit-Einklappung
    // bleibt aber innerhalb desselben Zugs erhalten (nur EIN Trigger pro
    // Zugwechsel).
    if (!game.isOver &&
        !controller.isCurrentPlayerBot &&
        game.currentPlayerIndex != _lastTurnAnnouncedIndex) {
      final isFirstTurn = _lastTurnAnnouncedIndex == null;
      _lastTurnAnnouncedIndex = game.currentPlayerIndex;
      final playerName = game.currentPlayer.name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_panelExpanded) setState(() => _panelExpanded = true);
        showTurnDialog(
          context,
          message: isFirstTurn
              ? '$playerName beginnt (längste mögliche Reihe aus der Starthand).'
              : '$playerName ist jetzt am Zug.',
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Qwirkle · Beutel: ${game.bag.remaining}'),
        bottom: controller.isCurrentPlayerBot && !game.isOver && settings.animationsEnabled
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${game.currentPlayer.name} (Bot) denkt nach …',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            ScorePanel(
              players: game.players,
              currentIndex: game.currentPlayerIndex,
            ),
            Expanded(
              child: IgnorePointer(
                ignoring: controller.isCurrentPlayerBot,
                child: const BoardView(),
              ),
            ),
            // Bewusst ein normales Column-Kind statt eines `Positioned`-
            // Overlays über dem Brett: ein Overlay würde bei ausgeklapptem
            // Panel den unteren Brett-Bereich zwar nur optisch verdecken,
            // aber auch dessen Drag-Ziele blockieren (das Panel läge im
            // Stack darüber und würde Drops abfangen, bevor sie das Brett
            // erreichen). Als Column-Kind bekommt das Brett stattdessen via
            // `Expanded` immer exakt die tatsächlich verbleibende (und
            // damit vollständig nutzbare) Höhe.
            CollapsibleGamePanel(
              expanded: _panelExpanded,
              onExpandedChanged: (value) =>
                  setState(() => _panelExpanded = value),
              collapsedIcon: _statusIcon(controller, game, _exchangeMode),
              collapsedText: _statusText(controller, game, _exchangeMode),
              collapsedColor: _statusColor(
                controller,
                game,
                _exchangeMode,
                context,
              ),
              expandedChild: _ControlPanel(
                exchangeMode: _exchangeMode,
                enabled: !controller.isCurrentPlayerBot,
                onToggleMode: () {
                  setState(() => _exchangeMode = !_exchangeMode);
                  controller.resetPendingPlacements();
                  controller.clearExchangeSelection();
                },
                onExchangeConfirmed: () =>
                    setState(() => _exchangeMode = false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(
    GameController controller,
    QwirkleGame game,
    bool exchangeMode,
  ) {
    if (game.isOver) return Icons.celebration_outlined;
    if (controller.isCurrentPlayerBot) return Icons.smart_toy_outlined;
    if (exchangeMode) return Icons.swap_horiz_outlined;
    if (controller.hasPendingPlacements) return Icons.add_circle_outline;
    return Icons.play_circle_outline;
  }

  Color _statusColor(
    GameController controller,
    QwirkleGame game,
    bool exchangeMode,
    BuildContext context,
  ) {
    if (controller.lastError != null) return Colors.red.shade700;
    if (game.isOver) return Colors.green.shade700;
    if (controller.isCurrentPlayerBot) return Colors.blue.shade700;
    if (exchangeMode) return Colors.orange.shade700;
    if (controller.hasPendingPlacements) return Colors.indigo.shade700;
    return Theme.of(context).colorScheme.primary;
  }

  String _statusText(
    GameController controller,
    QwirkleGame game,
    bool exchangeMode,
  ) {
    if (game.isOver) return 'Die Runde ist beendet.';
    if (controller.lastError != null) return controller.lastError!;
    if (controller.isCurrentPlayerBot) {
      return '${game.currentPlayer.name} denkt über den nächsten Zug nach…';
    }
    if (exchangeMode) {
      return 'Tauschmodus aktiv – wähle Steine aus deiner Hand aus.';
    }
    if (controller.hasPendingPlacements) {
      final score = controller.pendingScore;
      // Zwei getrennte Zahlen, damit der Punktwert dieses einen Zugs nicht
      // mit dem laufenden Gesamtstand der Partie verwechselt wird (siehe
      // Nutzer-Feedback: beide wurden für dieselbe Zahl gehalten).
      final scoreSuffix = score != null
          ? '\nDieser Zug: $score Punkt${score == 1 ? '' : 'e'} '
                '· Gesamt danach: ${game.currentPlayer.score + score}'
          : '';
      return 'Zug vorbereitet – bestätige die Platzierung oder nimm sie zurück.$scoreSuffix';
    }
    if (controller.lastBotSummary != null) {
      return controller.lastBotSummary!;
    }
    return 'Wähle einen Stein aus deiner Hand und platziere ihn auf dem Brett.';
  }

  /// Löst den Zug einer KI-Spielerin verzögert aus (damit der Zugwechsel
  /// sichtbar bleibt) und vermeidet Mehrfachauslösung pro Build.
  void _scheduleBotTurn(GameController controller, BotSpeed speed) {
    if (_botTimer != null) return;
    _botTimer = Timer(speed.turnDelay, () {
      _botTimer = null;
      if (!mounted) return;
      controller.playBotTurn();
    });
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
  final bool enabled;
  final VoidCallback onToggleMode;
  final VoidCallback onExchangeConfirmed;

  const _ControlPanel({
    required this.exchangeMode,
    required this.enabled,
    required this.onToggleMode,
    required this.onExchangeConfirmed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(gameControllerProvider);
    final canPass =
        enabled &&
        controller.game.bag.isEmpty &&
        !controller.hasPendingPlacements;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IgnorePointer(
          ignoring: !enabled,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: HandView(exchangeMode: exchangeMode),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (!exchangeMode) ...[
              ElevatedButton(
                onPressed: enabled && controller.hasPendingPlacements
                    ? controller.confirmMove
                    : null,
                child: const Text('Zug bestätigen'),
              ),
              OutlinedButton(
                onPressed: enabled && controller.hasPendingPlacements
                    ? controller.resetPendingPlacements
                    : null,
                child: const Text('Zurücknehmen'),
              ),
            ] else
              ElevatedButton(
                onPressed: enabled && controller.hasExchangeSelection
                    ? () {
                        controller.confirmExchange();
                        onExchangeConfirmed();
                      }
                    : null,
                child: const Text('Steine tauschen'),
              ),
            TextButton(
              onPressed: enabled ? onToggleMode : null,
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
    );
  }
}
