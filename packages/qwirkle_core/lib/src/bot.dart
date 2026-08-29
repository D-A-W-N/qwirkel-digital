import 'dart:math';

import 'board.dart';
import 'game.dart';
import 'invalid_move_exception.dart';
import 'move.dart';
import 'position.dart';
import 'tile.dart';

/// Schwierigkeitsgrad einer KI-Spielerin.
enum BotDifficulty {
  /// Zufälliger gültiger Zug.
  easy,

  /// Wählt den Zug mit dem höchsten unmittelbaren Punktwert.
  medium,

  /// Wie [medium], zieht aber von jedem Kandidaten ab, wie viele Punkte ein
  /// Gegner aus den dadurch entstandenen offenen Reihen herausholen könnte,
  /// wenn er einen passenden Stein hätte ("Lookahead-Heuristik").
  hard,
}

/// Die Entscheidung einer KI für ihren Zug: Steine legen, tauschen oder
/// aussetzen.
class BotDecision {
  final List<TilePlacement>? placements;
  final List<Tile>? exchangeTiles;

  const BotDecision.play(List<TilePlacement> this.placements)
    : exchangeTiles = null;
  const BotDecision.exchange(List<Tile> this.exchangeTiles) : placements = null;
  const BotDecision.pass() : placements = null, exchangeTiles = null;

  bool get isPlay => placements != null;
  bool get isExchange => exchangeTiles != null;
  bool get isPass => placements == null && exchangeTiles == null;

  /// Führt diese Entscheidung auf [game] aus (spielt/tauscht/setzt aus).
  int? applyTo(QwirkleGame game) {
    if (isPlay) return game.playTiles(placements!);
    if (isExchange) {
      game.exchangeTiles(exchangeTiles!);
      return null;
    }
    game.passTurn();
    return null;
  }
}

class _Candidate {
  final List<TilePlacement> placements;
  final int score;

  const _Candidate(this.placements, this.score);
}

/// Eine gerade Reihe (Teil-)Kandidat samt ihrer Richtung, damit sie als
/// Basis für einen rechtwinkligen Abzweig (T-/L-Form) dienen kann.
class _LineCandidate {
  final List<TilePlacement> placements;
  final int dx;
  final int dy;
  final int score;

  const _LineCandidate(this.placements, this.dx, this.dy, this.score);
}

const _directions = [(1, 0), (-1, 0), (0, 1), (0, -1)];

/// Ermittelt für [game] den Zug der aktuellen Spielerin gemäß [difficulty].
class Bot {
  final BotDifficulty difficulty;
  final Random _random;

  Bot({required this.difficulty, Random? random})
    : _random = random ?? Random();

  BotDecision decide(QwirkleGame game) {
    final player = game.currentPlayer;
    final candidates = _generateCandidates(game.board, player.hand);

    if (candidates.isEmpty) {
      if (player.hand.isNotEmpty && game.bag.remaining > 0) {
        final count = min(player.hand.length, game.bag.remaining);
        final shuffled = List<Tile>.from(player.hand)..shuffle(_random);
        return BotDecision.exchange(shuffled.take(count).toList());
      }
      return const BotDecision.pass();
    }

    switch (difficulty) {
      case BotDifficulty.easy:
        return BotDecision.play(
          candidates[_random.nextInt(candidates.length)].placements,
        );
      case BotDifficulty.medium:
        return BotDecision.play(_bestByScore(candidates).placements);
      case BotDifficulty.hard:
        return BotDecision.play(
          _bestByHeuristic(game.board, candidates).placements,
        );
    }
  }

  _Candidate _bestByScore(List<_Candidate> candidates) {
    var best = candidates.first;
    var bestOnes = <_Candidate>[best];
    for (final candidate in candidates.skip(1)) {
      if (candidate.score > best.score) {
        best = candidate;
        bestOnes = [candidate];
      } else if (candidate.score == best.score) {
        bestOnes.add(candidate);
      }
    }
    return bestOnes[_random.nextInt(bestOnes.length)];
  }

  _Candidate _bestByHeuristic(Board board, List<_Candidate> candidates) {
    var bestValue = -1 << 30;
    final bestOnes = <_Candidate>[];
    for (final candidate in candidates) {
      final exploit = _opponentExploitPotential(board, candidate.placements);
      final value = candidate.score - exploit;
      if (value > bestValue) {
        bestValue = value;
        bestOnes
          ..clear()
          ..add(candidate);
      } else if (value == bestValue) {
        bestOnes.add(candidate);
      }
    }
    return bestOnes[_random.nextInt(bestOnes.length)];
  }

  /// 1-Ply-Lookahead ohne Kenntnis der tatsächlichen Gegnerhand: schätzt für
  /// jede durch [placements] berührte Reihe ab, wie viele Punkte ein Gegner
  /// mit einem einzigen, ideal passenden Stein aus ihr herausholen könnte
  /// (Reihe der Länge 5 -> Qwirkle-Bonus möglich, deshalb am teuersten
  /// gewichtet; kürzere offene Reihen zählen anteilig weniger).
  int _opponentExploitPotential(Board board, List<TilePlacement> placements) {
    final merged = Map<Position, Tile>.from(board.cells);
    for (final placement in placements) {
      merged[placement.position] = placement.tile;
    }

    final visitedLines = <String>{};
    var potential = 0;
    for (final placement in placements) {
      for (final axisIndex in [0, 1]) {
        final dx = axisIndex == 0 ? 1 : 0;
        final dy = axisIndex == 0 ? 0 : 1;

        var start = placement.position;
        while (merged.containsKey(Position(start.x - dx, start.y - dy))) {
          start = Position(start.x - dx, start.y - dy);
        }
        final key = '$axisIndex:${start.x},${start.y}';
        if (!visitedLines.add(key)) continue;

        var length = 0;
        var current = start;
        while (merged.containsKey(current)) {
          length++;
          current = Position(current.x + dx, current.y + dy);
        }
        // Eine isolierte Reihe (Länge 1) oder eine bereits volle Reihe
        // (Länge 6) lässt sich durch einen einzelnen Gegnerstein nicht mehr
        // sinnvoll bzw. gar nicht mehr erweitern.
        if (length < 2 || length >= 6) continue;
        potential += length == 5 ? 12 : (length + 1);
      }
    }
    return potential;
  }

  List<_Candidate> _generateCandidates(Board board, List<Tile> hand) {
    final candidates = <_Candidate>[];
    final anchors = _findAnchors(board);

    for (final anchor in anchors) {
      for (final tile in hand.toSet()) {
        final placements = [TilePlacement(position: anchor, tile: tile)];
        final score = _tryScore(board, placements);
        if (score != null) {
          candidates.add(_Candidate(placements, score));
        }
      }
      for (final direction in _directions) {
        final lineCandidates = <_LineCandidate>[];
        _extendLine(
          board,
          List<Tile>.from(hand),
          anchor,
          direction.$1,
          direction.$2,
          const [],
          lineCandidates,
        );
        for (final line in lineCandidates) {
          // Einzelsteinkandidaten wurden bereits separat erzeugt.
          if (line.placements.length > 1) {
            candidates.add(_Candidate(line.placements, line.score));
          }
          _addPerpendicularBranches(board, hand, line, candidates);
        }
      }
    }
    return candidates;
  }

  void _extendLine(
    Board board,
    List<Tile> remainingHand,
    Position position,
    int dx,
    int dy,
    List<TilePlacement> current,
    List<_LineCandidate> results,
  ) {
    final triedTiles = <Tile>{};
    for (var i = 0; i < remainingHand.length; i++) {
      final tile = remainingHand[i];
      if (!triedTiles.add(tile)) continue;

      final trial = [...current, TilePlacement(position: position, tile: tile)];
      final score = _tryScore(board, trial);
      if (score == null) continue;

      results.add(_LineCandidate(trial, dx, dy, score));

      final nextPosition = Position(position.x + dx, position.y + dy);
      final continuation = board.tileAt(nextPosition) == null
          ? nextPosition
          // Brücken-Zug: liegt bereits ein Stein im Weg, überspringt die
          // Suche ihn (und jeden weiteren zusammenhängenden Stein) und legt
          // dahinter weiter an derselben Reihe an - laut Hausregel gelten
          // neue Steine auf beiden Seiten eines vorhandenen Steins als
          // verbunden (siehe Board._areOrthogonallyConnected).
          : _skipOccupiedRun(board, nextPosition, dx, dy);
      final nextHand = List<Tile>.from(remainingHand)..removeAt(i);
      _extendLine(board, nextHand, continuation, dx, dy, trial, results);
    }
  }

  /// Läuft von [position] aus in Richtung ([dx], [dy]) über bereits belegte
  /// Felder hinweg und liefert die erste wieder freie Position dahinter.
  Position _skipOccupiedRun(Board board, Position position, int dx, int dy) {
    var current = position;
    while (board.tileAt(current) != null) {
      current = Position(current.x + dx, current.y + dy);
    }
    return current;
  }

  /// Verzweigt von jedem Stein einer geraden Reihe [line] rechtwinklig ab
  /// und erzeugt so T-/L-förmige Zugkandidaten (Richtungswechsel innerhalb
  /// eines Zugs, siehe Hausregel in [Board.scorePlacement]). Es wird
  /// bewusst nur ein einzelner Abzweig pro Reihe versucht (kein weiteres
  /// Verzweigen des Abzweigs), um die Suche begrenzt zu halten.
  void _addPerpendicularBranches(
    Board board,
    List<Tile> hand,
    _LineCandidate line,
    List<_Candidate> candidates,
  ) {
    final remainingHand = List<Tile>.from(hand);
    for (final placement in line.placements) {
      remainingHand.remove(placement.tile);
    }
    if (remainingHand.isEmpty) return;

    final perpendicular = line.dx != 0
        ? const [(0, 1), (0, -1)]
        : const [(1, 0), (-1, 0)];

    for (final placement in line.placements) {
      for (final direction in perpendicular) {
        final branchStart = Position(
          placement.position.x + direction.$1,
          placement.position.y + direction.$2,
        );
        if (board.tileAt(branchStart) != null) continue;

        final branches = <_LineCandidate>[];
        _extendLine(
          board,
          List<Tile>.from(remainingHand),
          branchStart,
          direction.$1,
          direction.$2,
          line.placements,
          branches,
        );
        for (final branch in branches) {
          candidates.add(_Candidate(branch.placements, branch.score));
        }
      }
    }
  }

  Set<Position> _findAnchors(Board board) {
    if (board.isEmpty) return {const Position(0, 0)};
    final anchors = <Position>{};
    for (final position in board.cells.keys) {
      for (final direction in _directions) {
        final neighbor = Position(
          position.x + direction.$1,
          position.y + direction.$2,
        );
        if (board.tileAt(neighbor) == null) {
          anchors.add(neighbor);
        }
      }
    }
    return anchors;
  }

  int? _tryScore(Board board, List<TilePlacement> placements) {
    try {
      return board.scorePlacement(placements);
    } on InvalidMoveException {
      return null;
    }
  }
}
