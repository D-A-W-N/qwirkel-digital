/// Eine Position auf dem (unbegrenzten) Spielbrett-Raster.
class Position {
  final int x;
  final int y;

  const Position(this.x, this.y);

  Position translate(int dx, int dy) => Position(x + dx, y + dy);

  @override
  bool operator ==(Object other) =>
      other is Position && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}
