import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/onboarding/startup_gate.dart';
import 'src/settings/app_settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: QwirkleApp()));
}

class QwirkleApp extends ConsumerWidget {
  const QwirkleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await initializeAppSettings(ref);
    });

    return MaterialApp(
      title: 'Qwirkle Digital',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const StartupGate(),
    );
  }
}
