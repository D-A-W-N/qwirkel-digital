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

  /// Fester Versatz in Zellen, groß genug für jedes realistische
  /// Spielbrett (108 Steine ergeben rechnerisch höchstens eine Diagonale
  /// von ca. 108 Zellen, selbst als lange T-/L-Schlange).
  static const int origin = 500;

  double pixelX(int worldX) => (worldX + origin) * cellSize;
  double pixelY(int worldY) => (worldY + origin) * cellSize;

  /// Gesamtgröße des (festen) Koordinatenraums - dient `InteractiveViewer`
  /// nur als Lay­out-Größe, es wird ausschließlich der tatsächlich sichtbare
  /// Ausschnitt gezeichnet.
  double get totalSize => origin * 2 * cellSize;
}
