/// Die sechs Farben eines Qwirkle-Steinsatzes.
enum TileColor { red, orange, yellow, green, blue, purple }

/// Die sechs Symbole eines Qwirkle-Steinsatzes.
enum TileShape { circle, cross, diamond, square, star, clover }

/// Ein einzelner Spielstein, definiert durch Farbe und Symbol.
///
/// Zwei [Tile]-Instanzen mit gleicher Farbe und gleichem Symbol gelten als
/// gleich (Wert-Gleichheit), auch wenn der volle Satz jede Kombination
/// dreifach enthält.
class Tile {
  final TileColor color;
  final TileShape shape;

  const Tile(this.color, this.shape);

  /// Zwei Steine "passen", wenn sie Farbe oder Symbol (aber nicht beides
  /// zwingend unterschiedlich) teilen.
  bool sharesAttributeWith(Tile other) =>
      color == other.color || shape == other.shape;

  @override
  bool operator ==(Object other) =>
      other is Tile && other.color == color && other.shape == shape;

  @override
  int get hashCode => Object.hash(color, shape);

  @override
  String toString() => '${color.name}-${shape.name}';
}
