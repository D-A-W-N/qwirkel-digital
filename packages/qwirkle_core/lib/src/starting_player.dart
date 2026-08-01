import 'player.dart';
import 'tile.dart';

/// Ermittelt die längste Reihe, die sich aus [hand] legen ließe: die größte
/// Menge an Steinen, die eine Farbe mit lauter unterschiedlichen Symbolen
/// teilt, oder ein Symbol mit lauter unterschiedlichen Farben.
int longestPossibleRun(List<Tile> hand) {
  if (hand.isEmpty) return 0;

  final shapesByColor = <TileColor, Set<TileShape>>{};
  final colorsByShape = <TileShape, Set<TileColor>>{};
  for (final tile in hand) {
    shapesByColor.putIfAbsent(tile.color, () => {}).add(tile.shape);
    colorsByShape.putIfAbsent(tile.shape, () => {}).add(tile.color);
  }

  var best = 1;
  for (final shapes in shapesByColor.values) {
    if (shapes.length > best) best = shapes.length;
  }
  for (final colors in colorsByShape.values) {
    if (colors.length > best) best = colors.length;
  }
  return best;
}

/// Bestimmt den Index des Startspielers nach Hausregel: Wer aus der
/// Starthand die längste Reihe legen könnte, beginnt. Bei Gleichstand
/// entscheidet [tieBreaker] (z. B. jüngster Spieler zuerst); ohne
/// [tieBreaker] gewinnt der erste Kandidat in Spielerreihenfolge.
int determineStartingPlayerIndex(
  List<Player> players, {
  Comparator<Player>? tieBreaker,
}) {
  if (players.isEmpty) {
    throw ArgumentError('players darf nicht leer sein.');
  }

  final runs = [for (final p in players) longestPossibleRun(p.hand)];
  final maxRun = runs.reduce((a, b) => a > b ? a : b);
  final candidates = [
    for (var i = 0; i < players.length; i++)
      if (runs[i] == maxRun) i,
  ];

  if (candidates.length == 1 || tieBreaker == null) {
    return candidates.first;
  }
  candidates.sort((a, b) => tieBreaker(players[a], players[b]));
  return candidates.first;
}
