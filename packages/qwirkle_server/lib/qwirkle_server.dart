/// Dedizierter Internet-Multiplayer-Server für Qwirkle-Digital: hostet
/// beliebig viele Räume (siehe `qwirkle_net`s `RoomManager`/`RoomSession`)
/// über WebSocket und persistiert sie auf Platte, damit Partien einen
/// Prozess-Neustart (Redeploy) überstehen.
library;

export 'src/game_server.dart';
export 'src/room_store.dart';
