/// Bildet Weltkoordinaten (unbegrenztes Spielbrett) auf Pixelkoordinaten
/// über einen FESTEN Ursprung ab.
///
/// Bewusst nicht dynamisch aus der aktuellen Min/Max-Bounding-Box der
/// gerade sichtbaren Steine abgeleitet: eine dynamische Verschiebung
/// würde bei jeder Änderung der Bounding-Box (neuer Zug, neue vorläufige
/// Platzierung) ALLE bereits gezeichneten Steine auf dem Bildschirm
/// mitverschieben, weil sich ihr Pixel-Offset relativ zum neuen Minimum
/// ändert - sichtbar als plötzlicher "Sprung" des Bretts. Ein fester
/// Ursprung macht die Abbildung Weltposition → Pixel dauerhaft stabil.
class BoardGeometry {
  const BoardGeometry(this.cellSize);

  final double cellSize;

  /// Fester Versatz in Zellen - großzügig über jedes realistische
  /// Spielbrett hinaus (ein vollständiger Satz hat 108 Steine; selbst eine
  /// durchgehende T-/L-Schlange käme rechnerisch kaum über ~108 Zellen in
  /// einer Achse hinaus), aber bewusst NICHT beliebig groß gewählt: der
  /// gesamte Koordinatenraum ist gleichzeitig der ohne Einschränkung
  /// pan-bare Bereich von [CenteredBoardViewport] - zu großzügig bemessen
  /// ließe sich weit in komplett leeren, ungezeichneten Bereich scrollen
  /// (wirkt dann wie ein verschwundenes Brett).
  static const int origin = 150;

  double pixelX(int worldX) => (worldX + origin) * cellSize;
  double pixelY(int worldY) => (worldY + origin) * cellSize;

  /// Gesamtgröße des (festen) Koordinatenraums - dient `InteractiveViewer`
  /// nur als Lay­out-Größe, es wird ausschließlich der tatsächlich sichtbare
  /// Ausschnitt gezeichnet.
  double get totalSize => origin * 2 * cellSize;
}
