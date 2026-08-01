/// Host-autoritatives Netzwerk-Sync-Protokoll für Qwirkle-Digital.
///
/// Transport aktuell: TCP-Sockets (LAN, per Zeilen-getrenntes JSON). Für
/// Internet-Mehrspieler (Phase 5) wird der Transport durch WebRTC-
/// DataChannels ersetzt; das Nachrichtenprotokoll (`messages.dart`) und die
/// Host-/Client-Logik bleiben dabei unverändert wiederverwendbar.
library;

export 'src/client_session.dart';
export 'src/host_session.dart';
export 'src/messages.dart';
export 'src/serialization.dart';
export 'src/transport.dart';
