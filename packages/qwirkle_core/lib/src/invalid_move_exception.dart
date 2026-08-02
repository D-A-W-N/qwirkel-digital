/// Gründe, warum ein Zug ungültig ist. Nützlich für UI-Feedback und KI-Logik.
enum InvalidMoveReason {
  emptyPlacement,
  tooManyTiles,
  duplicatePosition,
  positionOccupied,
  gapInLine,
  notConnected,
  attributeMismatch,
  duplicateTileInLine,
  lineTooLong,
}

/// Wird geworfen, wenn ein Zug gegen die Qwirkle-Regeln verstößt.
class InvalidMoveException implements Exception {
  final InvalidMoveReason reason;
  final String message;

  const InvalidMoveException(this.reason, this.message);

  @override
  String toString() => 'InvalidMoveException($reason): $message';
}
