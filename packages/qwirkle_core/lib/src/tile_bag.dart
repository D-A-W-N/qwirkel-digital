import 'dart:math';

import 'tile.dart';

/// Der Steinbeutel: enthält alle noch nicht gezogenen Steine.
///
/// Ein vollständiger Qwirkle-Satz besteht aus 6 Farben x 6 Symbolen x 3
/// Kopien = 108 Steinen.
class TileBag {
  final List<Tile> _tiles;
  final Random _random;

  TileBag._(this._tiles, this._random);

  factory TileBag.standard({Random? random}) {
    final rng = random ?? Random();
    final tiles = <Tile>[
      for (final color in TileColor.values)
        for (final shape in TileShape.values)
          for (var copy = 0; copy < 3; copy++) Tile(color, shape),
    ];
    tiles.shuffle(rng);
    return TileBag._(tiles, rng);
  }

  /// Erstellt einen Beutel mit exakt [tiles] in der übergebenen Reihenfolge
  /// (das Ende der Liste wird zuerst gezogen). Nützlich für Tests und
  /// reproduzierbare Replays.
  factory TileBag.fromTiles(List<Tile> tiles, {Random? random}) {
    return TileBag._(List<Tile>.from(tiles), random ?? Random());
  }

  int get remaining => _tiles.length;

  bool get isEmpty => _tiles.isEmpty;

  /// Zieht bis zu [count] Steine (weniger, falls der Beutel nicht genug enthält).
  List<Tile> draw(int count) {
    final n = min(count, _tiles.length);
    final drawn = _tiles.sublist(_tiles.length - n);
    _tiles.removeRange(_tiles.length - n, _tiles.length);
    return drawn;
  }

  /// Legt [tiles] zurück in den Beutel (z. B. beim Steine-Tauschen) und mischt neu.
  void returnTiles(List<Tile> tiles) {
    _tiles.addAll(tiles);
    _tiles.shuffle(_random);
  }
}
