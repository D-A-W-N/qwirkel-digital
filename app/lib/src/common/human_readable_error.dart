import 'dart:async';
import 'dart:io';

/// Wandelt eine gefangene Ausnahme in eine für Endnutzer:innen verständliche
/// deutsche Meldung um, statt eines rohen `Object.toString()`.
///
/// Ohne das zeigt z. B. ein `ArgumentError` "Invalid argument(s): ..."
/// (englisches Boilerplate vor einer bereits deutschen Meldung) oder eine
/// `SocketException` interne Details wie Errno-Codes an. Eigene
/// Exception-Klassen dieser App (z. B. `UpdateApplyException`,
/// `GithubReleaseException`) überschreiben `toString()` bereits mit einer
/// sauberen, deutschen Meldung - für die bleibt der Fallback unverändert.
String humanReadableError(Object error) {
  if (error is ArgumentError) {
    final message = error.message;
    return message == null ? error.toString() : '$message';
  }
  if (error is StateError) {
    return error.message;
  }
  if (error is SocketException) {
    return 'Verbindung fehlgeschlagen. Prüfe deine Internetverbindung und versuche es erneut.';
  }
  if (error is WebSocketException) {
    return 'Die Verbindung wurde unterbrochen. Bitte versuche es erneut.';
  }
  if (error is TimeoutException) {
    return 'Zeitüberschreitung. Bitte versuche es erneut.';
  }
  if (error is FormatException) {
    return 'Ungültige oder unerwartete Antwort erhalten.';
  }
  return error.toString();
}
