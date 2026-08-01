import 'position.dart';
import 'tile.dart';

/// Die Platzierung eines einzelnen Steins bei einem Zug.
class TilePlacement {
  final Position position;
  final Tile tile;

  const TilePlacement({required this.position, required this.tile});

  @override
  String toString() => '$tile@$position';
}
