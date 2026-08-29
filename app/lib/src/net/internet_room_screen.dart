import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/human_readable_error.dart';
import 'internet_room_history.dart';
import 'network_connection_config.dart';
import 'network_game_view.dart';
import 'room_connection_manager.dart';

/// Zeigt eine einzelne Internet-Raum-Verbindung an, deren [ClientSession]
/// vom app-weiten [RoomConnectionManager] gehalten wird - Wegnavigieren
/// (z. B. zur [MyRoomsScreen]) trennt die Verbindung NICHT mehr, wie es
/// `NetworkGameScreen` (weiterhin für LAN zuständig) tun würde.
///
/// Zwei Wege, diesen Screen zu öffnen: [InternetRoomScreen] erstellt einen
/// neuen Raum oder tritt einem bei (aus der Lobby kommend, [config] bekannt),
/// [InternetRoomScreen.existingRoom] öffnet lediglich die Ansicht für einen
/// bereits verbundenen Raum (aus der Raum-Übersicht kommend).
class InternetRoomScreen extends ConsumerStatefulWidget {
  // Bewusst keine initialisierende `this.config`-Formal: das würde den
  // Parametertyp auf das nullable Feld (geteilt mit `.existingRoom`) statt
  // auf den hier tatsächlich verlangten nicht-nullablen Typ aufweiten.
  const InternetRoomScreen({super.key, required NetworkConnectionConfig config})
    // ignore: prefer_initializing_formals
    : config = config,
      existingRoomCode = null;

  const InternetRoomScreen.existingRoom({super.key, required String roomCode})
    : config = null,
      existingRoomCode = roomCode;

  final NetworkConnectionConfig? config;
  final String? existingRoomCode;

  @override
  ConsumerState<InternetRoomScreen> createState() => _InternetRoomScreenState();
}

class _InternetRoomScreenState extends ConsumerState<InternetRoomScreen> {
  // In `initState` erfasst statt jedes Mal per `ref.read` geholt: `dispose`
  // darf `ref` nicht mehr benutzen (der Widget-Kontext ist dort bereits
  // unmounted), braucht aber trotzdem noch Zugriff auf den Manager, um das
  // Vordergrund-Flag zurückzusetzen.
  late final RoomConnectionManager _manager;
  String? _roomCode;
  bool _isInitializing = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _manager = ref.read(roomConnectionManagerProvider);
    final existingRoomCode = widget.existingRoomCode;
    if (existingRoomCode != null) {
      _roomCode = existingRoomCode;
      _isInitializing = false;
      _manager.setForegroundRoom(existingRoomCode);
    } else {
      unawaited(_connect());
    }
  }

  Future<void> _connect() async {
    final config = widget.config!;
    final manager = _manager;
    try {
      if (config.effectiveName.isEmpty) {
        throw ArgumentError('Bitte gib einen Namen ein.');
      }
      final RoomConnectionEntry entry;
      if (config.isHosting) {
        entry = await manager.createInternetRoom(
          serverUrl: config.effectiveServerUrl,
          playerName: config.effectiveName,
          roomName: config.roomName,
        );
      } else {
        // Ein zuvor gespeichertes Reconnect-Token (falls für diesen Raum
        // vorhanden) fordert denselben Sitzplatz zurück, statt einen neuen
        // zu beziehen - wichtig, wenn die Partie schon läuft.
        // `config.reconnectToken` wird von der Lobby nie gesetzt, daher der
        // Lookup über die Historie hier.
        final history = await loadInternetRoomHistory();
        final saved = history.where((e) => e.roomCode == config.inviteCode);
        entry = await manager.joinInternetRoom(
          serverUrl: config.effectiveServerUrl,
          playerName: config.effectiveName,
          roomCode: config.inviteCode,
          reconnectToken: saved.isEmpty ? null : saved.first.reconnectToken,
        );
      }
      if (!mounted) return;
      setState(() => _roomCode = entry.roomCode);
      if (entry.roomCode != null) {
        manager.setForegroundRoom(entry.roomCode);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _initError = humanReadableError(error));
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    // Bewusst KEIN Schließen der Session hier - sie gehört jetzt dem
    // Manager und läuft im Hintergrund weiter, bis "Raum verlassen" gedrückt
    // wird oder die App beendet wird. `_manager` (nicht `ref.read`!), da der
    // Widget-Kontext hier bereits unmounted sein kann.
    _manager.setForegroundRoom(null);
    super.dispose();
  }

  Future<void> _confirmLeaveRoom(BuildContext context, String roomCode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Raum verlassen?'),
        content: const Text(
          'Dein Sitzplatz wird endgültig freigegeben. Du kannst diesem Raum '
          'später nur mit einem neuen Beitritt wieder beitreten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Verlassen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _manager.leaveRoom(roomCode);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final roomCode = _roomCode;
    if (roomCode == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Internet-Spiel')),
        body: Center(
          child: _isInitializing
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_initError ?? 'Verbindung fehlgeschlagen.'),
                ),
        ),
      );
    }

    final manager = ref.watch(roomConnectionManagerProvider);
    final entry = manager.entryFor(roomCode);
    if (entry == null) {
      // Der Raum wurde (z. B. aus einem anderen Screen heraus) verlassen,
      // während dieser Screen noch offen war.
      return Scaffold(
        appBar: AppBar(title: const Text('Internet-Spiel')),
        body: const Center(child: Text('Dieser Raum wurde verlassen.')),
      );
    }

    if (entry.snapshot != null) {
      final snapshot = entry.snapshot!;
      return NetworkGameView(
        snapshot: snapshot,
        ownHand: snapshot.players[snapshot.yourPlayerIndex].hand ?? const [],
        canInteract:
            snapshot.currentPlayerIndex == snapshot.yourPlayerIndex &&
            !snapshot.isOver &&
            !entry.reconnecting,
        onSendMove: (placements) async {
          if (placements.isEmpty) return false;
          entry.session.sendMove(placements);
          return true;
        },
        onSendPass: entry.session.sendPass,
        onSendExchange: entry.session.sendExchange,
        isRoomOwner: entry.isRoomOwner,
        onRestartGame: entry.session.sendRestartGame,
        statusText: entry.status,
        errorText: entry.errorText,
        onLeaveRoom: () => _confirmLeaveRoom(context, roomCode),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Internet-Spiel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Internet-Verbindung',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(entry.status ?? 'Initialisiere Session...'),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.vpn_key),
                title: const Text('Einladungscode'),
                subtitle: SelectableText(roomCode),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Internet-Lobby',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (entry.lobbyPlayers.isEmpty)
              const Text('Noch keine Teilnehmer')
            else
              ...entry.lobbyPlayers.map(
                (player) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(player.name),
                  trailing: Icon(Icons.pending, color: Colors.orange.shade700),
                ),
              ),
            const Spacer(),
            if (entry.isRoomOwner) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: entry.session.sendStartGame,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Spiel starten'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Zurück (Verbindung bleibt bestehen)'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _confirmLeaveRoom(context, roomCode),
                child: const Text('Raum verlassen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
