import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Das eigene, geräteweit gemerkte Spielerprofil - aktuell nur der
/// Anzeigename, damit er nicht bei jedem Screen (lokales Setup,
/// Netzwerk-Lobby) erneut eingetippt werden muss.
class PlayerProfile {
  const PlayerProfile({required this.displayName});

  final String displayName;

  PlayerProfile copyWith({String? displayName}) {
    return PlayerProfile(displayName: displayName ?? this.displayName);
  }

  static PlayerProfile defaults() => const PlayerProfile(displayName: '');
}

/// Siehe `AppSettingsNotifier` (app_settings.dart) für die Begründung, warum
/// externe Aufrufer [update] statt der `@protected` Notifier-`state`-Setzung
/// verwenden.
class PlayerProfileNotifier extends Notifier<PlayerProfile> {
  @override
  PlayerProfile build() => PlayerProfile.defaults();

  void update(PlayerProfile profile) => state = profile;
}

final playerProfileProvider =
    NotifierProvider<PlayerProfileNotifier, PlayerProfile>(
      PlayerProfileNotifier.new,
    );

Future<void> initializePlayerProfile(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final displayName = prefs.getString('playerProfile.displayName') ?? '';
  if (ref.read(playerProfileProvider).displayName != displayName) {
    ref
        .read(playerProfileProvider.notifier)
        .update(PlayerProfile(displayName: displayName));
  }
}

Future<void> savePlayerProfile(PlayerProfile profile) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('playerProfile.displayName', profile.displayName);
}
