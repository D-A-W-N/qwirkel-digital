import 'dart:collection';
import 'dart:io';

/// Schützt den Server vor "Join-Flood"-Missbrauch: begrenzt, wie viele
/// WebSocket-Verbindungsversuche eine einzelne IP innerhalb eines
/// gleitenden Zeitfensters machen darf, bevor [GameServer] sie mit HTTP 429
/// abweist, statt sie überhaupt erst zu einem Raum-Beitritt/einer
/// Raum-Erstellung durchzulassen (siehe `RoomManager`, das absichtlich
/// nichts von IPs oder HTTP weiß).
class ConnectionRateLimiter {
  ConnectionRateLimiter({
    this.maxAttempts = 20,
    this.window = const Duration(minutes: 1),
  });

  final int maxAttempts;
  final Duration window;

  final _attemptsByIp = <String, Queue<DateTime>>{};

  /// Zählt einen Verbindungsversuch von [ip] und liefert `true`, wenn er
  /// noch innerhalb des erlaubten Limits liegt, sonst `false`. Abgelehnte
  /// Versuche zählen selbst nicht mit - eine dauerhaft flutende IP bleibt
  /// so blockiert, bis ihr ältester (bereits gezählter) Versuch aus dem
  /// Fenster fällt, statt die Warteschlange unbegrenzt wachsen zu lassen.
  bool allow(String ip) {
    final now = DateTime.now();
    final attempts = _attemptsByIp.putIfAbsent(ip, Queue<DateTime>.new);
    while (attempts.isNotEmpty && now.difference(attempts.first) > window) {
      attempts.removeFirst();
    }
    if (attempts.length >= maxAttempts) return false;
    attempts.addLast(now);
    _purgeStaleIps(now);
    return true;
  }

  /// Entfernt IPs, deren letzter Versuch außerhalb des Fensters liegt -
  /// sonst bliebe für jede jemals gesehene IP dauerhaft ein (wenn auch
  /// leerer) Eintrag bestehen und die Map würde über die Laufzeit des
  /// Prozesses hinweg unbegrenzt wachsen.
  void _purgeStaleIps(DateTime now) {
    _attemptsByIp.removeWhere(
      (_, attempts) =>
          attempts.isEmpty || now.difference(attempts.last) > window,
    );
  }
}

/// Ermittelt die tatsächliche Client-IP einer eingehenden Anfrage. Auf der
/// Produktions-VPS läuft der Server hinter Coolifys Traefik-Reverse-Proxy,
/// dessen Container-Port nie direkt vom Internet aus erreichbar ist (siehe
/// docker-compose.yml: `expose` statt `ports`) - Traefik ist damit der
/// einzige Weg zum Container und setzt zuverlässig `X-Forwarded-For`, das
/// hier vertraut ausgelesen werden kann. Ohne Proxy (z. B. lokale
/// Entwicklung/Tests) fällt das auf die Socket-Adresse zurück.
String clientIpOf(HttpRequest request) {
  final forwardedFor = request.headers.value('x-forwarded-for');
  if (forwardedFor != null && forwardedFor.isNotEmpty) {
    return forwardedFor.split(',').first.trim();
  }
  return request.connectionInfo?.remoteAddress.address ?? 'unknown';
}
