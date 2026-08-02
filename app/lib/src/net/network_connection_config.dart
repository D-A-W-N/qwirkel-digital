class NetworkConnectionConfig {
  NetworkConnectionConfig({
    required String mode,
    required String host,
    required String port,
    required String name,
    required String signalingUrl,
    required String inviteCode,
  }) : mode = mode.trim(),
       host = host.trim(),
       port = port.trim(),
       name = name.trim(),
       signalingUrl = signalingUrl.trim(),
       inviteCode = inviteCode.trim() {
    if (this.mode.isEmpty) {
      throw ArgumentError('Mode must not be empty');
    }
    effectivePort;
  }

  final String mode;
  final String host;
  final String port;
  final String name;
  final String signalingUrl;
  final String inviteCode;

  String get effectiveHost => host.trim();

  String get effectiveName => name.trim();

  int get effectivePort {
    final parsed = int.tryParse(port.trim());
    if (parsed == null || parsed <= 0 || parsed > 65535) {
      throw ArgumentError('Ungültiger Port: $port');
    }
    return parsed;
  }
}
