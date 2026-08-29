/// Eine einzelne Abweichung dieser App von den offiziellen Qwirkle-Regeln.
///
/// An einer Stelle gepflegt und sowohl vom Erststart-Onboarding
/// ([onboarding_screen.dart]) als auch von der jederzeit erreichbaren
/// [rules_screen.dart] verwendet, damit beide nie auseinanderlaufen.
class HouseRule {
  final String title;
  final String description;

  const HouseRule({required this.title, required this.description});
}

const qwirkleHouseRules = [
  HouseRule(
    title: 'Richtungswechsel innerhalb eines Zugs',
    description:
        'Deine neu gelegten Steine dürfen in einem Zug auch die Richtung '
        'wechseln (z. B. eine T- oder L-Form bilden) – sie müssen dabei '
        'aber lückenlos zusammenhängen.',
  ),
  HouseRule(
    title: 'Punktezählung pro Stein',
    description:
        'Bei mehreren Steinen in einem Zug zählt jeder Stein einzeln nach '
        'der Länge seiner Reihe zum Zeitpunkt seines Anlegens – 3 Steine, '
        'die eine Reihe verlängern, bringen z. B. 1+2+3 statt nur der '
        'fertigen Reihenlänge.',
  ),
  HouseRule(
    title: 'Partieende',
    description:
        'Die Partie endet erst, wenn wirklich alle Hände leer sind oder '
        'niemand mehr ziehen kann – nicht schon, sobald die erste Person '
        'ihre Hand leert. Jede Person, die ihre Hand leert, bekommt dafür '
        'den üblichen Bonus.',
  ),
  HouseRule(
    title: 'Startspieler:in',
    description:
        'Wer beginnt, wird über die längste Reihe ermittelt, die sich aus '
        'der eigenen Starthand legen ließe – nicht zufällig.',
  ),
];
