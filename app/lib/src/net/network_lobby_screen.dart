import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
import 'internet_room_history.dart';
import 'network_connection_config.dart';
import 'network_game_screen.dart';

class NetworkLobbyScreen extends ConsumerStatefulWidget {
  const NetworkLobbyScreen({super.key});

  @override
  ConsumerState<NetworkLobbyScreen> createState() => _NetworkLobbyScreenState();
}

class _NetworkLobbyScreenState extends ConsumerState<NetworkLobbyScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '4040');
  final _nameController = TextEditingController(text: 'Spieler');
  String? _errorText;
  final _serverUrlController = TextEditingController(
    text: kDefaultInternetServerUrl,
  );
  final _inviteCodeController = TextEditingController();
  final _roomNameController = TextEditingController();
  bool _isHosting = false;
  String _connectionMode = 'lan';
  bool _showServerUrlField = false;
  List<InternetRoomEntry> _recentRooms = const [];
  final List<String> _tips = [
    'Hoste ein Spiel, wenn du die Partie starten willst.',
    'Wähle einen eindeutigen Namen, damit andere dich sofort erkennen.',
    'Die Partie beginnt, sobald der Host den Start auslöst.',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentRooms();
  }

  Future<void> _loadRecentRooms() async {
    final entries = await loadInternetRoomHistory();
    if (!mounted) return;
    setState(() => _recentRooms = entries);
  }

  Future<void> _dismissRecentRoom(String roomCode) async {
    await forgetInternetRoom(roomCode);
    if (!mounted) return;
    setState(() {
      _recentRooms = _recentRooms.where((e) => e.roomCode != roomCode).toList();
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _nameController.dispose();
    _serverUrlController.dispose();
    _inviteCodeController.dispose();
    _roomNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final tips = settings.tipsEnabled
        ? _tips
        : [
            'Tipps sind deaktiviert. Du kannst sie in den Einstellungen wieder aktivieren.',
          ];

    return Scaffold(
      appBar: AppBar(title: const Text('Netzwerk-Lobby')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'LAN-Mehrspieler',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Wähle, ob du eine Partie hosten oder einem bestehenden Spiel beitreten willst.',
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              title: Text(_isHosting ? 'Hosting-Modus' : 'Beitritts-Modus'),
              subtitle: Text(
                _isHosting
                    ? 'Du erstellst die Partie und startest sie, sobald alle da sind.'
                    : 'Du verbindest dich mit einer bestehenden Partie.',
              ),
              value: _isHosting,
              onChanged: (value) => setState(() => _isHosting = value),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'lan',
                  label: Text('LAN / lokal'),
                  icon: Icon(Icons.wifi),
                ),
                ButtonSegment(
                  value: 'internet',
                  label: Text('Internet'),
                  icon: Icon(Icons.language),
                ),
              ],
              selected: {_connectionMode},
              onSelectionChanged: (selection) {
                setState(() => _connectionMode = selection.first);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Dein Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_connectionMode == 'lan') ...[
              if (!_isHosting) ...[
                TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host-Adresse',
                    hintText: 'z. B. 192.168.1.23 (IP des Hosts)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              if (_showServerUrlField) ...[
                TextField(
                  controller: _serverUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Server-Adresse',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showServerUrlField = true),
                    icon: const Icon(Icons.settings, size: 18),
                    label: const Text('Andere Server-Adresse verwenden'),
                  ),
                ),
              const SizedBox(height: 12),
              if (_isHosting) ...[
                const Text(
                  'Der Einladungscode wird nach dem Erstellen des Raums angezeigt und kann dann geteilt werden.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _roomNameController,
                  decoration: const InputDecoration(
                    labelText: 'Raumname (optional)',
                    hintText: 'z. B. Samstagsrunde',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else
                TextField(
                  controller: _inviteCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Einladungscode',
                    border: OutlineInputBorder(),
                  ),
                ),
              // Immer sichtbar, unabhängig vom Hosting-/Beitritts-Umschalter:
              // auch wer selbst gehostet hat, muss nach dem Verlassen wieder
              // zurückfinden - ohne das war der eigene Raum nach dem
              // Beenden nirgends mehr auffindbar.
              if (_recentRooms.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Zuletzt besuchte Räume',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Partien können sich über mehrere Tage ziehen - hier geht es direkt zurück in einen bereits besuchten Raum (als Host oder Mitspieler:in).',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                ..._recentRooms.map(
                  (entry) => Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      leading: Icon(
                        entry.isOver ? Icons.flag_outlined : Icons.history,
                      ),
                      title: Row(
                        children: [
                          // Name statt Code als primäre Bezeichnung - der
                          // Code allein war kaum wiederzuerkennen. Fällt bei
                          // älteren, vor diesem Feature gespeicherten
                          // Einträgen auf den Code zurück.
                          Text(entry.roomName ?? entry.roomCode),
                          if (entry.isOver) ...[
                            const SizedBox(width: 8),
                            Chip(
                              label: const Text('Beendet'),
                              labelStyle: Theme.of(
                                context,
                              ).textTheme.labelSmall,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Code: ${entry.roomCode} · als ${entry.playerName} · '
                            'zuletzt ${_formatLastSeen(entry.lastSeen)}',
                          ),
                          if (entry.playerNames.isNotEmpty)
                            Text(
                              'Mit ${entry.playerNames.join(', ')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                      isThreeLine: entry.playerNames.isNotEmpty,
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Aus der Historie entfernen',
                        onPressed: () => _dismissRecentRoom(entry.roomCode),
                      ),
                      onTap: () {
                        setState(() {
                          // Zurückkehren läuft immer über den Beitritts-Flow
                          // (mit gespeichertem Reconnect-Token) - die
                          // Owner-Rechte kommen dabei vom Server zurück,
                          // unabhängig davon, ob man den Raum ursprünglich
                          // selbst erstellt hat.
                          _isHosting = false;
                          _inviteCodeController.text = entry.roomCode;
                          _nameController.text = entry.playerName;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            if (_errorText != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: () {
                try {
                  final config = NetworkConnectionConfig(
                    mode: _connectionMode,
                    isHosting: _isHosting,
                    host: _hostController.text,
                    port: _portController.text,
                    name: _nameController.text,
                    serverUrl: _serverUrlController.text,
                    inviteCode: _inviteCodeController.text,
                    roomName: _roomNameController.text,
                  );
                  setState(() => _errorText = null);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NetworkGameScreen(config: config),
                    ),
                  );
                } catch (error) {
                  setState(() => _errorText = error.toString());
                }
              },
              child: Text(_isHosting ? 'Host starten' : 'Beitreten'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Schnellhilfe',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tip)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatLastSeen(DateTime lastSeen) {
  final diff = DateTime.now().difference(lastSeen);
  if (diff.inMinutes < 1) return 'gerade eben';
  if (diff.inHours < 1) return 'vor ${diff.inMinutes} Min.';
  if (diff.inDays < 1) return 'vor ${diff.inHours} Std.';
  return 'vor ${diff.inDays} Tag${diff.inDays == 1 ? '' : 'en'}';
}
