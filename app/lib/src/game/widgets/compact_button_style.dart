import 'package:flutter/material.dart';

/// Kompakterer Button-Stil für die Zug-/Tausch-/Aussetzen-Buttons - auf dem
/// Handy nahmen die Standard-Button-Größen zusammen mit Hand-Zeile und
/// Statuszeile zu viel von der ohnehin knappen Bildschirmhöhe ein (Nutzer-
/// Feedback). Von lokalem und Netzwerk-Spiel gemeinsam genutzt.
const compactButtonStyle = ButtonStyle(
  padding: WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  ),
  minimumSize: WidgetStatePropertyAll(Size(0, 32)),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 13)),
);
