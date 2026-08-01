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

  /// Wie [medium], bevorzugt bei ähnlich guten Zügen aber Züge, die keine
  /// offene 5er-Reihe für den Gegner hinterlassen ("Lookahead-Heuristik").
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
      final penalty = _openLinePenalty(board, candidate.placements);
      final value = candidate.score - penalty * 3;
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

  /// Zählt Reihen, die durch [placements] auf genau 5 Steine wachsen (und
  /// damit dem Gegner eine leichte Qwirkle-Vervollständigung ermöglichen).
  int _openLinePenalty(Board board, List<TilePlacement> placements) {
    final merged = Map<Position, Tile>.from(board.cells);
    for (final placement in placements) {
      merged[placement.position] = placement.tile;
    }

    final visitedLines = <String>{};
    var penalty = 0;
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
        if (length == 5) penalty++;
      }
    }
    return penalty;
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
        _extendLine(
          board,
          List<Tile>.from(hand),
          anchor,
          direction.$1,
          direction.$2,
          const [],
          candidates,
        );
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
    List<_Candidate> results,
  ) {
    final triedTiles = <Tile>{};
    for (var i = 0; i < remainingHand.length; i++) {
      final tile = remainingHand[i];
      if (!triedTiles.add(tile)) continue;

      final trial = [...current, TilePlacement(position: position, tile: tile)];
      final score = _tryScore(board, trial);
      if (score == null) continue;

      // Einzelsteinkandidaten wurden bereits separat erzeugt.
      if (trial.length > 1) {
        results.add(_Candidate(trial, score));
      }

      final nextPosition = Position(position.x + dx, position.y + dy);
      if (board.tileAt(nextPosition) == null) {
        final nextHand = List<Tile>.from(remainingHand)..removeAt(i);
        _extendLine(board, nextHand, nextPosition, dx, dy, trial, results);
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
