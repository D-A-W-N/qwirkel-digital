import 'invalid_move_exception.dart';
import 'move.dart';
import 'position.dart';
import 'tile.dart';

enum _Axis { horizontal, vertical }

class _Line {
  final List<Position> positions;
  final List<Tile> tiles;

  const _Line(this.positions, this.tiles);
}

/// Das Spielbrett: ein unbegrenztes Raster, das nur belegte Felder speichert.
///
/// [scorePlacement] validiert einen Zug und berechnet dessen Punktwert, ohne
/// das Brett zu verändern (dry run). Erst [apply] übernimmt die Steine.
/// So kann ein Aufrufer (Spiel-Engine, KI, Netzwerk-Validierung) einen Zug
/// vorab prüfen, bevor er ihn tatsächlich anwendet.
class Board {
  final Map<Position, Tile> _cells = {};

  Map<Position, Tile> get cells => Map.unmodifiable(_cells);

  bool get isEmpty => _cells.isEmpty;

  Tile? tileAt(Position position) => _cells[position];

  /// Prüft [placements] gegen die Qwirkle-Regeln und liefert den Punktwert
  /// zurück. Wirft [InvalidMoveException], falls der Zug ungültig ist.
  int scorePlacement(List<TilePlacement> placements) {
    if (placements.isEmpty) {
      throw const InvalidMoveException(
        InvalidMoveReason.emptyPlacement,
        'Ein Zug muss mindestens einen Stein enthalten.',
      );
    }
    if (placements.length > 6) {
      throw const InvalidMoveException(
        InvalidMoveReason.tooManyTiles,
        'Ein Zug kann höchstens 6 Steine enthalten.',
      );
    }

    final positions = placements.map((p) => p.position).toSet();
    if (positions.length != placements.length) {
      throw const InvalidMoveException(
        InvalidMoveReason.duplicatePosition,
        'Ein Zug darf ein Feld nicht mehrfach belegen.',
      );
    }
    for (final placement in placements) {
      if (_cells.containsKey(placement.position)) {
        throw InvalidMoveException(
          InvalidMoveReason.positionOccupied,
          'Feld ${placement.position} ist bereits belegt.',
        );
      }
    }

    final bool firstMove = _cells.isEmpty;
    final merged = {
      ..._cells,
      for (final placement in placements) placement.position: placement.tile,
    };

    _Axis? axis;
    if (placements.length > 1) {
      final firstPos = placements.first.position;
      final sameRow = placements.every((p) => p.position.y == firstPos.y);
      final sameCol = placements.every((p) => p.position.x == firstPos.x);
      if (!sameRow && !sameCol) {
        throw const InvalidMoveException(
          InvalidMoveReason.notInLine,
          'Alle Steine eines Zugs müssen in einer Reihe oder Spalte liegen.',
        );
      }
      axis = sameRow ? _Axis.horizontal : _Axis.vertical;
    }

    if (!firstMove) {
      final connected = placements.any((p) => _hasExistingNeighbor(p.position));
      if (!connected) {
        throw const InvalidMoveException(
          InvalidMoveReason.notConnected,
          'Mindestens ein platzierter Stein muss an einen vorhandenen Stein angrenzen.',
        );
      }
    }

    final linesToScore = <List<Tile>>[];

    if (axis != null) {
      final line = _collectLine(placements.first.position, axis, merged);
      _validateLine(line);
      final linePositions = line.positions.toSet();
      for (final placement in placements) {
        if (!linePositions.contains(placement.position)) {
          throw const InvalidMoveException(
            InvalidMoveReason.gapInLine,
            'Die platzierten Steine sind nicht lückenlos verbunden.',
          );
        }
      }
      linesToScore.add(line.tiles);

      final perpendicular =
          axis == _Axis.horizontal ? _Axis.vertical : _Axis.horizontal;
      for (final placement in placements) {
        final crossLine = _collectLine(placement.position, perpendicular, merged);
        if (crossLine.tiles.length > 1) {
          _validateLine(crossLine);
          linesToScore.add(crossLine.tiles);
        }
      }
    } else {
      for (final dir in _Axis.values) {
        final line = _collectLine(placements.first.position, dir, merged);
        if (line.tiles.length > 1) {
          _validateLine(line);
          linesToScore.add(line.tiles);
        }
      }
    }

    if (linesToScore.isEmpty) {
      // Nur möglich beim allerersten Zug des Spiels mit genau einem Stein.
      return placements.length;
    }

    var score = 0;
    for (final line in linesToScore) {
      score += line.length;
      if (line.length == 6) {
        score += 6;
      }
    }
    return score;
  }

  /// Übernimmt zuvor validierte [placements] in das Brett.
  void apply(List<TilePlacement> placements) {
    for (final placement in placements) {
      _cells[placement.position] = placement.tile;
    }
  }

  bool _hasExistingNeighbor(Position position) {
    return _cells.containsKey(position.translate(1, 0)) ||
        _cells.containsKey(position.translate(-1, 0)) ||
        _cells.containsKey(position.translate(0, 1)) ||
        _cells.containsKey(position.translate(0, -1));
  }

  _Line _collectLine(Position start, _Axis axis, Map<Position, Tile> merged) {
    final dx = axis == _Axis.horizontal ? 1 : 0;
    final dy = axis == _Axis.horizontal ? 0 : 1;

    var minPos = start;
    while (merged.containsKey(minPos.translate(-dx, -dy))) {
      minPos = minPos.translate(-dx, -dy);
    }
    var maxPos = start;
    while (merged.containsKey(maxPos.translate(dx, dy))) {
      maxPos = maxPos.translate(dx, dy);
    }

    final positions = <Position>[];
    final tiles = <Tile>[];
    var current = minPos;
    while (true) {
      positions.add(current);
      tiles.add(merged[current]!);
      if (current == maxPos) break;
      current = current.translate(dx, dy);
    }
    return _Line(positions, tiles);
  }

  void _validateLine(_Line line) {
    if (line.tiles.length > 6) {
      throw const InvalidMoveException(
        InvalidMoveReason.lineTooLong,
        'Eine Reihe darf höchstens 6 Steine enthalten.',
      );
    }
    final seen = <Tile>{};
    for (final tile in line.tiles) {
      if (!seen.add(tile)) {
        throw InvalidMoveException(
          InvalidMoveReason.duplicateTileInLine,
          'Stein $tile kommt in derselben Reihe mehrfach vor.',
        );
      }
    }
    final first = line.tiles.first;
    final sameColor = line.tiles.every((t) => t.color == first.color);
    final sameShape = line.tiles.every((t) => t.shape == first.shape);
    if (!sameColor && !sameShape) {
      throw const InvalidMoveException(
        InvalidMoveReason.attributeMismatch,
        'Alle Steine einer Reihe müssen dieselbe Farbe oder dasselbe Symbol teilen.',
      );
    }
  }
}
