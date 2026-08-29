import 'package:flutter/material.dart';

import 'house_rules.dart';

/// Wischbares Erststart-Intro (Willkommen, Funktionen, Hausregeln) - wird nur
/// gezeigt, solange [OnboardingPrefs.hasSeenOnboarding] noch `false` ist
/// (siehe `startup_gate.dart`). [onDone] wird beim Abschluss oder beim
/// Überspringen aufgerufen und übernimmt das Markieren als "gesehen".
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 3;
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pageCount - 1) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _page == _pageCount - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Visibility(
                  visible: !isLastPage,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  child: TextButton(
                    onPressed: widget.onDone,
                    child: const Text('Überspringen'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: const [
                  _WelcomePage(),
                  _FeaturesPage(),
                  _HouseRulesPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pageCount; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(isLastPage ? "Los geht's" : 'Weiter'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      icon: Icons.grid_view_rounded,
      title: 'Willkommen bei Qwirkle Digital',
      children: const [
        Text(
          'Leg Steine mit passender Farbe oder Form an, sammle Punkte und '
          'bilde möglichst lange Reihen - digital, aber mit demselben '
          'Grundprinzip wie am Tisch.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage();

  static const _features = [
    (
      Icons.people_outline,
      'Pass & Play',
      'Bis zu 6 Personen an einem Gerät.',
    ),
    (
      Icons.smart_toy_outlined,
      'Bots',
      'Drei Schwierigkeitsgrade als Gegner oder Mitspieler.',
    ),
    (
      Icons.wifi_tethering,
      'LAN & Internet',
      'Spiele über das lokale Netzwerk oder online - auch über mehrere '
          'Tage verteilt, mit Wiederverbindung.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      icon: Icons.auto_awesome_outlined,
      title: 'Was die App kann',
      children: [
        for (final feature in _features)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(feature.$1, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.$2,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(feature.$3),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HouseRulesPage extends StatelessWidget {
  const _HouseRulesPage();

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      icon: Icons.rule_folder_outlined,
      title: 'Hausregeln dieser App',
      subtitle:
          'An diesen Stellen weicht diese App bewusst vom offiziellen '
          'Qwirkle-Regelwerk ab - in "Regeln & Hilfe" jederzeit nachlesbar.',
      children: [
        for (final rule in qwirkleHouseRules)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(rule.description),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}
