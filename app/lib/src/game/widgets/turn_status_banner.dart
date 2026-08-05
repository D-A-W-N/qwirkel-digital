import 'package:flutter/material.dart';

/// Präsentationelle Statuszeile (Icon + Text) - von lokalem und
/// Netzwerk-Spiel gemeinsam genutzt. Welche Priorität welcher Zustand hat
/// (Fehler vs. eigener Zug vs. Warten, ...) bleibt bewusst Sache der
/// jeweiligen Aufrufer:in, da sich die möglichen Zustände zwischen lokalem
/// Spiel (u. a. Bot-Zug) und Netzwerkspiel (u. a. fremder letzter Zug)
/// unterscheiden - geteilt wird nur die Darstellung.
class TurnStatusBanner extends StatelessWidget {
  const TurnStatusBanner({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
