import 'package:flutter/material.dart';

import 'house_rules.dart';

/// Jederzeit erreichbare Übersicht über Spielziel und Hausregeln - anders
/// als der frühere, nur als Dialog erreichbare "Anleitung"-Hinweis (siehe
/// `setup_screen.dart`) eine vollwertige, scrollbare Seite, die auch das
/// Erststart-Onboarding ([onboarding_screen.dart]) als Inhalt wiederverwendet.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Regeln & Hilfe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Spielziel', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Bilde Reihen aus Farben oder Formen.'),
          const SizedBox(height: 8),
          const Text(
            'Jeder Zug bringt Punkte, wenn die Reihen logisch aufgebaut sind.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Wenn du unsicher bist, probiere zuerst einfache Reihen mit '
            'gleichen Farben oder Formen.',
          ),
          const SizedBox(height: 24),
          Text(
            'Hausregeln dieser App',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'An diesen Stellen weicht diese App bewusst vom offiziellen '
            'Qwirkle-Regelwerk ab:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final rule in qwirkleHouseRules)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(rule.description),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
