import 'package:flutter/material.dart';

/// Fester, immer sichtbarer Streifen am unteren Bildschirmrand - zeigt eine
/// kompakte Statuszeile (Icon + Text) über [child] (Hand + Buttons).
///
/// Bewusst NICHT ein-/ausklappbar: ein früherer Anlauf ließ das Panel
/// einklappen, um dem Brett mehr Platz zu geben - aber genau dann, wenn
/// man selbst am Zug ist (und die Hand zum Platzieren braucht), MUSS es
/// ohnehin ausgeklappt sein, und während man wartet, gibt es darin nichts
/// zu sehen, das das Einklappen wertvoll gemacht hätte (Nutzer-Feedback:
/// "eine unten einklappbare Leiste ist irgendwie dumm"). Die schlanke,
/// von Phase 1 bereits reduzierte Chrome reicht als fester Block aus.
class GameBottomBar extends StatelessWidget {
  const GameBottomBar({
    super.key,
    required this.statusIcon,
    required this.statusText,
    required this.statusColor,
    required this.child,
  });

  final IconData statusIcon;
  final String statusText;
  final Color statusColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        // Scrollbar statt Overflow, falls der Inhalt bei extremer
        // Systemschriftgröße doch einmal nicht in die verfügbare Höhe passt.
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, size: 18, color: statusColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
