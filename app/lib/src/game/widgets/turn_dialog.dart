import 'package:flutter/material.dart';

/// Zeigt einen leichten, wegklickbaren Hinweis "Du bist am Zug" - für den
/// Moment, in dem der Zugwechsel sonst nicht sofort auffällt (z. B. beim
/// lokalen Hotseat-Wechsel zwischen Personen, oder wenn ein neuer
/// Netzwerk-Spielstand eintrifft, während man gerade nicht hinsieht). Von
/// lokalem und Netzwerkspiel gemeinsam genutzt - nur der [message]-Text
/// unterscheidet sich.
Future<void> showTurnDialog(BuildContext context, {required String message}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Du bist am Zug'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Los geht’s'),
        ),
      ],
    ),
  );
}
