import 'bot.dart';
import 'tile.dart';

/// Ein Spieler (Mensch oder KI) mit Handkarten und Punktestand.
///
/// [botDifficulty] ist `null` für menschliche Spieler:innen; ist er gesetzt,
/// steuert er, mit welcher Schwierigkeit ein [Bot] die Züge dieses Spielers
/// übernimmt.
class Player {
  final String id;
  final String name;
  List<Tile> hand;
  int score;
  final BotDifficulty? botDifficulty;

  Player({
    required this.id,
    required this.name,
    List<Tile>? hand,
    this.score = 0,
    this.botDifficulty,
  }) : hand = hand ?? <Tile>[];

  bool get isBot => botDifficulty != null;

  @override
  String toString() => '$name ($score Punkte)';
}
