import 'package:flutter/material.dart';

import 'match_history.dart';

/// Zeigt vergangene Partien (lokal, LAN, Internet), neueste zuerst - reine
/// Ergebnisliste ohne aggregierte Statistiken (siehe Punkt 19 der
/// App-Review).
class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  List<MatchRecord>? _records;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await loadMatchHistory();
    if (!mounted) return;
    setState(() => _records = records);
  }

  IconData _iconFor(MatchMode mode) => switch (mode) {
    MatchMode.local => Icons.people_outline,
    MatchMode.lan => Icons.wifi,
    MatchMode.internet => Icons.language,
  };

  String _labelFor(MatchMode mode) => switch (mode) {
    MatchMode.local => 'Lokal',
    MatchMode.lan => 'LAN',
    MatchMode.internet => 'Internet',
  };

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return Scaffold(
      appBar: AppBar(title: const Text('Partie-Historie')),
      body: records == null
          ? const Center(child: CircularProgressIndicator())
          : records.isEmpty
          ? const Center(child: Text('Noch keine abgeschlossene Partie.'))
          : ListView.builder(
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_iconFor(record.mode), size: 18),
                            const SizedBox(width: 6),
                            Text(_labelFor(record.mode)),
                            const Spacer(),
                            Text(_formatDate(record.playedAt)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (var i = 0; i < record.standings.length; i++)
                          Text(
                            '${i + 1}. ${record.standings[i].name}: '
                            '${record.standings[i].score} Punkte',
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
