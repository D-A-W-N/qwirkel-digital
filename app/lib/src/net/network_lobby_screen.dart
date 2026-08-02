import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
import 'network_connection_config.dart';
import 'network_game_screen.dart';

class NetworkLobbyScreen extends ConsumerStatefulWidget {
  const NetworkLobbyScreen({super.key});

  @override
  ConsumerState<NetworkLobbyScreen> createState() => _NetworkLobbyScreenState();
}

class _NetworkLobbyScreenState extends ConsumerState<NetworkLobbyScreen> {
  final _hostController = TextEditingController(text: '127.0.0.1');
  final _portController = TextEditingController(text: '4040');
  final _nameController = TextEditingController(text: 'Spieler');
  String? _errorText;
  final _signalingUrlController = TextEditingController(
    text: 'ws://127.0.0.1:8080',
  );
  final _inviteCodeController = TextEditingController(text: 'qwirkle-01');
  bool _isHosting = false;
  String _connectionMode = 'lan';
  final List<String> _tips = [
    'Hoste ein Spiel, wenn du die Partie starten willst.',
    'Wähle einen eindeutigen Namen, damit andere dich sofort erkennen.',
    'Die Partie beginnt, sobald der Host den Start auslöst.',
  ];

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _nameController.dispose();
    _signalingUrlController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final tips = settings.tipsEnabled
        ? _tips
        : ['Tipps sind deaktiviert. Du kannst sie in den Einstellungen wieder aktivieren.'];

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
                    ? 'Der Host wartet auf Mitspieler und startet das Spiel.'
                    : 'Du verbindest dich zu einem Host.',
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
              TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Host-Adresse',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              TextField(
                controller: _signalingUrlController,
                decoration: const InputDecoration(
                  labelText: 'Signaling-URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _inviteCodeController,
                decoration: const InputDecoration(
                  labelText: 'Einladungscode',
                  border: OutlineInputBorder(),
                ),
              ),
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
                    signalingUrl: _signalingUrlController.text,
                    inviteCode: _inviteCodeController.text,
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
            ...tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
