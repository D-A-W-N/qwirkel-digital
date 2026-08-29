import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qwirkle_core/qwirkle_core.dart';

import '../game/game_controller.dart';
import '../game/game_providers.dart';
import '../game/game_screen.dart';
import '../net/my_rooms_screen.dart';
import '../net/network_lobby_screen.dart';
import '../settings/app_settings.dart';
import '../update/update_controller.dart';
import '../update/update_dialog.dart';
import '../update/update_models.dart';
import '../update/update_settings_section.dart';

/// Spiel-Setup für den lokalen Pass&Play-Modus: Spieleranzahl (2-6) und Namen.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  static const minPlayers = 2;
  static const maxPlayers = 6;

  int _playerCount = 2;
  bool _updateCheckTriggered = false;
  late final List<TextEditingController> _nameControllers;
  late final List<BotDifficulty?> _botDifficulties;

  @override
  void initState() {
    super.initState();
    _nameControllers = List.generate(
      maxPlayers,
      (i) => TextEditingController(text: 'Spieler ${i + 1}'),
    );
    _botDifficulties = List.generate(maxPlayers, (_) => null);
  }

  /// Cleans up a stale post-update backup (proof this process is a
  /// successfully-booted relaunch) and, if due, runs a silent throttled
  /// update check. Inert outside release builds and unsupported platforms.
  Future<void> _runStartupUpdateFlow() async {
    if (!kReleaseMode) return;
    if (currentTargetPlatform() == UpdateTargetPlatform.unsupported) return;

    try {
      await ref.read(updateApplierProvider).cleanupStaleBackup();
    } catch (_) {
      // Best-effort: a leftover backup (or a failure to locate/delete one)
      // must never block the actual update check below.
    }

    if (!ref.read(appSettingsProvider).updateCheckEnabled) return;

    final lastChecked = await ref.read(updatePrefsProvider).lastCheckedAt();
    if (lastChecked != null &&
        DateTime.now().difference(lastChecked) < const Duration(hours: 24)) {
      return;
    }

    await ref.read(updateControllerProvider.notifier).checkForUpdate();
  }

  @override
  void dispose() {
    for (final controller in _nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startGame() {
    final players = [
      for (var i = 0; i < _playerCount; i++)
        Player(
          id: 'p$i',
          name: _nameControllers[i].text.trim().isEmpty
              ? 'Spieler ${i + 1}'
              : _nameControllers[i].text.trim(),
          botDifficulty: _botDifficulties[i],
        ),
    ];
    final game = QwirkleGame(players: players);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProviderScope(
          overrides: [
            gameControllerProvider.overrideWith((ref) => GameController(game)),
          ],
          child: const GameScreen(),
        ),
      ),
    );
  }

  void _showHowToPlayDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spielziel'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bilde Reihen aus Farben oder Formen.'),
              SizedBox(height: 8),
              Text(
                'Jeder Zug bringt Punkte, wenn die Reihen logisch aufgebaut sind.',
              ),
              SizedBox(height: 8),
              Text(
                'Wenn du unsicher bist, probiere zuerst einfache Reihen mit gleichen Farben oder Formen.',
              ),
              SizedBox(height: 8),
              Text(
                'Hausregel: Innerhalb eines Zugs dürfen deine neuen Steine auch die Richtung wechseln (z. B. eine T- oder L-Form bilden) – sie müssen dabei aber lückenlos zusammenhängen.',
              ),
              SizedBox(height: 8),
              Text(
                'Hausregel: Bei mehreren Steinen in einem Zug zählt jeder Stein einzeln nach der Länge seiner Reihe zum Zeitpunkt seines Anlegens (z. B. bringen 3 Steine, die eine Reihe verlängern, 1+2+3 statt nur der fertigen Reihenlänge).',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      // Ohne das ist die Sheet-Höhe auf einen festen Bruchteil des
      // Bildschirms gedeckelt (Standard von `showModalBottomSheet`) UND der
      // Inhalt war nicht scrollbar - bei großer Systemschrift/Zoom (siehe
      // Nutzer-Feedback: Update-Bereich für sehbehinderten Freund nicht
      // erreichbar) überlief die Spalte dann einfach nach unten aus dem
      // Bildschirm, ohne jede Möglichkeit, dorthin zu scrollen.
      isScrollControlled: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final settings = ref.watch(appSettingsProvider);
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                ),
                child: SingleChildScrollView(
                  key: const Key('settingsSheetScrollView'),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Einstellungen',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: settings.animationsEnabled,
                        onChanged: (value) async {
                          final nextSettings = ref
                              .read(appSettingsProvider)
                              .copyWith(animationsEnabled: value);
                          ref.read(appSettingsProvider.notifier).state =
                              nextSettings;
                          await saveAppSettings(nextSettings);
                        },
                        title: const Text('Animationen'),
                        subtitle: const Text(
                          'Aktiviert sanfte Übergänge im Spiel.',
                        ),
                      ),
                      SwitchListTile.adaptive(
                        value: settings.tipsEnabled,
                        onChanged: (value) async {
                          final nextSettings = ref
                              .read(appSettingsProvider)
                              .copyWith(tipsEnabled: value);
                          ref.read(appSettingsProvider.notifier).state =
                              nextSettings;
                          await saveAppSettings(nextSettings);
                        },
                        title: const Text('Hinweise'),
                        subtitle: const Text(
                          'Zeigt kurze Tipps im Spiel und in der Lobby.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bot-Geschwindigkeit',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Wie lange ein Bot vor seinem Zug "nachdenkt".',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<BotSpeed>(
                              segments: [
                                for (final speed in BotSpeed.values)
                                  ButtonSegment(
                                    value: speed,
                                    label: Text(speed.label),
                                  ),
                              ],
                              selected: {settings.botSpeed},
                              onSelectionChanged: (selection) async {
                                final nextSettings = ref
                                    .read(appSettingsProvider)
                                    .copyWith(botSpeed: selection.first);
                                ref.read(appSettingsProvider.notifier).state =
                                    nextSettings;
                                await saveAppSettings(nextSettings);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const UpdateSettingsSection(),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text(
                                  'Einstellungen zurücksetzen?',
                                ),
                                content: const Text(
                                  'Damit werden Animationen, Tipps und Bot-Geschwindigkeit auf die Standardwerte zurückgesetzt.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(false),
                                    child: const Text('Abbrechen'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(true),
                                    child: const Text('Zurücksetzen'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              await resetAppSettings(ref);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            }
                          },
                          icon: const Icon(Icons.restore),
                          label: const Text('Auf Standard zurücksetzen'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_updateCheckTriggered) {
      _updateCheckTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _runStartupUpdateFlow(),
      );
    }
    ref.listen<UpdateState>(updateControllerProvider, (previous, next) {
      if (next.phase == UpdatePhase.available) {
        maybeShowUpdateDialog(context, ref, manual: false);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Qwirkle · Spielmodus')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Qwirkle digital',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Spiele lokal mit Freunden, gegen Bots oder über LAN/Internet mit anderen Spieler:innen.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () => _showHowToPlayDialog(context),
                              icon: const Icon(Icons.help_outline),
                              label: const Text('Anleitung'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showSettingsSheet(context),
                              icon: const Icon(Icons.tune),
                              label: const Text('Einstellungen'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Anzahl Spieler (Pass & Play, $minPlayers-$maxPlayers)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _playerCount > minPlayers
                                ? () => setState(() => _playerCount--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '$_playerCount',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          IconButton(
                            onPressed: _playerCount < maxPlayers
                                ? () => setState(() => _playerCount++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Netzwerk spielen',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Hoste ein Spiel oder tritt über LAN/Internet einer Partie bei.',
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.tonal(
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const NetworkLobbyScreen(),
                                        ),
                                      ),
                                      child: const Text('Netzwerk-Setup öffnen'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const MyRoomsScreen(),
                                        ),
                                      ),
                                      child: const Text('Meine Räume'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Spieler und Gegner',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _playerCount,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _nameControllers[i],
                                  decoration: InputDecoration(
                                    labelText: 'Name Spieler ${i + 1}',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<BotDifficulty?>(
                                  initialValue: _botDifficulties[i],
                                  decoration: const InputDecoration(
                                    labelText: 'Typ',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text('Mensch'),
                                    ),
                                    DropdownMenuItem(
                                      value: BotDifficulty.easy,
                                      child: Text('Bot: Leicht'),
                                    ),
                                    DropdownMenuItem(
                                      value: BotDifficulty.medium,
                                      child: Text('Bot: Mittel'),
                                    ),
                                    DropdownMenuItem(
                                      value: BotDifficulty.hard,
                                      child: Text('Bot: Schwer'),
                                    ),
                                  ],
                                  onChanged: (value) => setState(
                                    () => _botDifficulties[i] = value,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _startGame,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Spiel starten'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
