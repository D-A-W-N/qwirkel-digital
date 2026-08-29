import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'internet_room_history.dart';
import 'internet_room_screen.dart';
import 'network_connection_config.dart';
import 'room_connection_manager.dart';

/// Übersicht aller Internet-Räume, mit denen diese Person gerade verbunden
/// ist ODER schon einmal verbunden war - der zentrale Einstiegspunkt für
/// paralleles Spielen in mehreren Räumen. Live-Räume (im
/// [RoomConnectionManager] gehalten) werden direkt geöffnet; Räume, die nur
/// noch in der lokalen Historie stehen, lösen einen frischen Beitritt mit
/// dem gespeicherten Reconnect-Token aus.
class MyRoomsScreen extends ConsumerStatefulWidget {
  const MyRoomsScreen({super.key});

  @override
  ConsumerState<MyRoomsScreen> createState() => _MyRoomsScreenState();
}

/// Eine Zeile der Raum-Übersicht: entweder nur aus der Historie bekannt,
/// nur live (frisch erstellt, noch nicht in der Historie nachgeladen) oder
/// beides.
class _RoomRow {
  final String roomCode;
  final RoomConnectionEntry? live;
  final InternetRoomEntry? history;

  const _RoomRow({required this.roomCode, this.live, this.history});

  String get displayName => live?.roomName ?? history?.roomName ?? roomCode;
}

class _MyRoomsScreenState extends ConsumerState<MyRoomsScreen> {
  List<InternetRoomEntry> _history = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final entries = await loadInternetRoomHistory();
    if (!mounted) return;
    setState(() {
      _history = entries;
      _loading = false;
    });
  }

  String _statusFor(_RoomRow row) {
    final live = row.live;
    if (live == null) {
      return (row.history?.isOver ?? false)
          ? 'Beendet – tippen zum erneuten Öffnen'
          : 'Nicht verbunden – tippen zum Verbinden';
    }
    if (live.reconnecting) return 'Verbindung wird wiederhergestellt…';
    final snapshot = live.snapshot;
    if (snapshot == null) return 'Wartet in der Lobby';
    if (snapshot.isOver) return 'Partie beendet';
    if (snapshot.currentPlayerIndex == snapshot.yourPlayerIndex) {
      return 'Du bist am Zug!';
    }
    final current = snapshot.players[snapshot.currentPlayerIndex];
    return current.connected
        ? 'Warte auf ${current.name}'
        : '${current.name} ist nicht verbunden';
  }

  bool _isYourTurn(_RoomRow row) {
    final snapshot = row.live?.snapshot;
    return snapshot != null &&
        !snapshot.isOver &&
        snapshot.currentPlayerIndex == snapshot.yourPlayerIndex;
  }

  void _openRow(_RoomRow row) {
    if (row.live != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InternetRoomScreen.existingRoom(roomCode: row.roomCode),
        ),
      );
      return;
    }
    final history = row.history!;
    final config = NetworkConnectionConfig(
      mode: 'internet',
      isHosting: false,
      host: '',
      // Für den Internet-Modus irrelevant, aber `NetworkConnectionConfig`
      // validiert den Port unabhängig vom Modus - ein Platzhalter genügt.
      port: '1',
      name: history.playerName,
      serverUrl: kDefaultInternetServerUrl,
      inviteCode: history.roomCode,
    );
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => InternetRoomScreen(config: config)));
  }

  InternetRoomEntry? _historyFor(String roomCode) {
    for (final entry in _history) {
      if (entry.roomCode == roomCode) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(roomConnectionManagerProvider);

    final rows = <_RoomRow>[
      for (final entry in manager.rooms)
        _RoomRow(
          roomCode: entry.roomCode!,
          live: entry,
          history: _historyFor(entry.roomCode!),
        ),
      for (final historyEntry in _history)
        if (manager.entryFor(historyEntry.roomCode) == null)
          _RoomRow(roomCode: historyEntry.roomCode, history: historyEntry),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Meine Räume')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Noch keine Internet-Räume. Erstelle oder betrete einen '
                  'über "Netzwerk-Setup öffnen".',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      _isYourTurn(row)
                          ? Icons.notifications_active
                          : Icons.meeting_room_outlined,
                    ),
                    title: Text(row.displayName),
                    subtitle: Text('${_statusFor(row)} · Code: ${row.roomCode}'),
                    onTap: () => _openRow(row),
                  ),
                );
              },
            ),
    );
  }
}
