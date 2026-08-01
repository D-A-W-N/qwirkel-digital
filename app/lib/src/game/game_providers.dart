import 'package:flutter_riverpod/legacy.dart';

import 'game_controller.dart';

/// Muss pro Spielsitzung (z. B. beim Start eines neuen Spiels) mit einem
/// konkreten [GameController] überschrieben werden.
final gameControllerProvider = ChangeNotifierProvider<GameController>((ref) {
  throw UnimplementedError(
    'gameControllerProvider muss pro Spielsitzung überschrieben werden.',
  );
});
