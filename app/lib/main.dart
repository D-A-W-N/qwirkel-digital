import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/setup/setup_screen.dart';

void main() {
  runApp(const ProviderScope(child: QwirkleApp()));
}

class QwirkleApp extends StatelessWidget {
  const QwirkleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qwirkle',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const SetupScreen(),
    );
  }
}
