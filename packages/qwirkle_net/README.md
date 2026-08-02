# qwirkle_net

Netzwerk-Session-Logik für Qwirkle-Digital-Multiplayer: host-autoritative `HostSession`/`ClientSession` (Zugvalidierung läuft ausschließlich über [qwirkle_core](../qwirkle_core), nie client-seitig), ein transportunabhängiges `MessageTransport`-Interface (TCP für LAN, WebRTC-DataChannel für Internet-Play), sowie ein minimaler, selbst hostbarer Signaling-Server für den WebRTC-Verbindungsaufbau.

Siehe [Root-README](../../README.md) für Setup und Testbefehle.
