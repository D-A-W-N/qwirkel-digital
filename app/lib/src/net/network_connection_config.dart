/// Standard-Adresse des dedizierten Internet-Servers (`qwirkle_server` auf
/// dem VPS) - siehe docs/vps_deploy_setup.md. Im Verbindungsbildschirm
/// überschreibbar (z. B. für lokale Tests gegen `ws://localhost:8080`).
const kDefaultInternetServerUrl = 'wss://qgames.streetkidz.duckdns.org';

class NetworkConnectionConfig {
  NetworkConnectionConfig({
    required String mode,
    required this.isHosting,
    required String host,
    required String port,
    required String name,
    required String serverUrl,
    required String inviteCode,
    String roomName = '',
    this.reconnectToken,
  }) : mode = mode.trim(),
       host = host.trim(),
       port = port.trim(),
       name = name.trim(),
       serverUrl = serverUrl.trim(),
       inviteCode = inviteCode.trim(),
       roomName = roomName.trim() {
    if (this.mode.isEmpty) {
      throw ArgumentError('Mode must not be empty');
    }
    effectivePort;
  }

  final String mode;

  /// Ob diese Session ein Spiel hosten oder einem bestehenden beitreten
  /// soll — unabhängig von [mode] (LAN/Internet), da beide Verbindungsarten
  /// sowohl Host- als auch Beitritts-Rolle unterstützen.
  final bool isHosting;
  final String host;
  final String port;
  final String name;

  /// Nur `mode == 'internet'`: Adresse des dedizierten Servers.
  final String serverUrl;

  /// Nur `mode == 'internet'`: Raum-Code, dem beigetreten werden soll
  /// (leer beim Hosten - der Server vergibt dann einen neuen Code).
  final String inviteCode;

  /// Nur `mode == 'internet'` und [isHosting]: frei vergebener Name für
  /// einen neu zu erstellenden Raum (z. B. "Samstagsrunde"), damit er sich
  /// später in der Raum-Historie leichter wiederfinden lässt als nur über
  /// den Code - Nutzer-Feedback "Räume sollten auch Namen bekommen". Leer
  /// lässt den Server einen Fallback-Namen vergeben.
  final String roomName;

  /// Nur `mode == 'internet'`: aus der lokalen Raum-Historie übernommenes
  /// Reconnect-Token, um nach einer Trennung denselben Sitzplatz
  /// zurückzufordern statt neu beizutreten (siehe `internet_room_history.dart`).
  final String? reconnectToken;

  String get effectiveHost => host.trim();

  String get effectiveName => name.trim();

  String get effectiveServerUrl => serverUrl.trim();

  int get effectivePort {
    final parsed = int.tryParse(port.trim());
    if (parsed == null || parsed <= 0 || parsed > 65535) {
      throw ArgumentError('Ungültiger Port: $port');
    }
    return parsed;
  }
}
