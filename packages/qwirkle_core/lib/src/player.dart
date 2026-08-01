import 'tile.dart';

/// Ein Spieler (Mensch oder KI) mit Handkarten und Punktestand.
class Player {
  final String id;
  final String name;
  List<Tile> hand;
  int score;

  Player({
    required this.id,
    required this.name,
    List<Tile>? hand,
    this.score = 0,
  }) : hand = hand ?? <Tile>[];

  @override
  String toString() => '$name ($score Punkte)';
}
