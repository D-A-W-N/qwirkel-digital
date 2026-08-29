import 'position.dart';

const _neighborOffsets = [(1, 0), (-1, 0), (0, 1), (0, -1)];

/// Liefert alle leeren Felder, die orthogonal an mindestens ein belegtes
/// Feld aus [occupied] angrenzen - die einzigen Positionen, an denen ein
/// neuer Stein legal an Bestehendes anschließen kann (siehe
/// `Board.scorePlacement`s Nachbarschafts-Pflicht für jeden Zug außer dem
/// allerersten). Bei leerem [occupied] gilt nur der Ursprung `(0, 0)` als
/// Anker (erster Zug der Partie).
///
/// Geteilt zwischen [Bot]s Zuggenerierung (welche Felder probieren?) und
/// `BoardSurface`s Rendering (welche Felder brauchen überhaupt einen
/// Drop-Ziel-Rahmen?), damit beide Seiten exakt dieselbe Vorstellung von
/// "möglicher Anlagepunkt" haben.
Set<Position> anchorPositions(Iterable<Position> occupied) {
  final occupiedSet = occupied is Set<Position> ? occupied : occupied.toSet();
  if (occupiedSet.isEmpty) return {const Position(0, 0)};

  final anchors = <Position>{};
  for (final position in occupiedSet) {
    for (final offset in _neighborOffsets) {
      final neighbor = Position(position.x + offset.$1, position.y + offset.$2);
      if (!occupiedSet.contains(neighbor)) anchors.add(neighbor);
    }
  }
  return anchors;
}
