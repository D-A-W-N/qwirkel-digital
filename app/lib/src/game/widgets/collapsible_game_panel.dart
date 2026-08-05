import 'package:flutter/material.dart';

/// Einklappbares Panel am unteren Bildschirmrand - überlagert das Spielbrett
/// als `Positioned`-Overlay statt als fester `Column`-Block, damit dem
/// Brett standardmäßig die volle verfügbare Höhe bleibt. Eingeklappt zeigt
/// es nur eine schmale Statuszeile mit Zieh-Griff; ausgeklappt zeigt es
/// [expandedChild] (Hand, Buttons, ...) in einem nach oben begrenzten,
/// bei Bedarf scrollbaren Bereich - damit auch bei sehr wenig verfügbarer
/// Höhe (z. B. große Systemschrift/Zoom) nichts überläuft, sondern
/// gescrollt wird.
///
/// Sowohl lokales als auch Netzwerkspiel nutzen dieses Widget gemeinsam;
/// welcher Inhalt/Zustand angezeigt wird, entscheidet die aufrufende Seite.
class CollapsibleGamePanel extends StatelessWidget {
  const CollapsibleGamePanel({
    super.key,
    required this.expanded,
    required this.onExpandedChanged,
    required this.collapsedIcon,
    required this.collapsedText,
    required this.collapsedColor,
    required this.expandedChild,
  });

  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final IconData collapsedIcon;
  final String collapsedText;
  final Color collapsedColor;
  final Widget expandedChild;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        elevation: 8,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onExpandedChanged(!expanded),
                // Nach oben wischen öffnet, nach unten schließt - unabhängig
                // vom aktuellen Zustand, damit eine einzelne eindeutige
                // Geste reicht, ohne vorher den Zustand prüfen zu müssen.
                onVerticalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -100) onExpandedChanged(true);
                  if (velocity > 100) onExpandedChanged(false);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(collapsedIcon, size: 18, color: collapsedColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              collapsedText,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Icon(
                            expanded
                                ? Icons.expand_more
                                : Icons.expand_less,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: expandedChild,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
