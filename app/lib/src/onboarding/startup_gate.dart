import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../setup/setup_screen.dart';
import 'onboarding_prefs.dart';
import 'onboarding_screen.dart';

/// Entscheidet beim App-Start, ob das Erststart-Onboarding
/// ([OnboardingScreen]) oder direkt der [SetupScreen] gezeigt wird -
/// abhängig von [OnboardingPrefs.hasSeenOnboarding].
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key});

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  bool? _hasSeenOnboarding;

  @override
  void initState() {
    super.initState();
    ref.read(onboardingPrefsProvider).hasSeenOnboarding().then((seen) {
      if (mounted) setState(() => _hasSeenOnboarding = seen);
    });
  }

  Future<void> _completeOnboarding() async {
    await ref.read(onboardingPrefsProvider).markSeen();
    if (mounted) setState(() => _hasSeenOnboarding = true);
  }

  @override
  Widget build(BuildContext context) {
    final hasSeen = _hasSeenOnboarding;
    // Kurzer, unsichtbarer Zwischenschritt, während die gespeicherte
    // Präferenz asynchron geladen wird (SharedPreferences) - in der Praxis
    // nur einen Frame lang sichtbar.
    if (hasSeen == null) return const SizedBox.shrink();
    if (hasSeen) return const SetupScreen();
    return OnboardingScreen(onDone: _completeOnboarding);
  }
}
