# Changelog

## [Unreleased]

- Replaced the WebRTC/P2P internet-play groundwork (`SignalingClient`/`SignalingServer`) with `WebSocketTransport` + `RoomManager`/`RoomSession` against a dedicated, always-on backend (`qwirkle_server`): every seat (including the room creator) is a network client, reconnect tokens let a disconnected seat rejoin without being auto-skipped, and `room_persistence.dart` serializes the full room state for on-disk persistence across process restarts

## [0.1.0] - 2026-08-02

- Initial host-authoritative `HostSession`/`ClientSession` network session logic over TCP (LAN play)
- Transport-agnostic `MessageTransport` interface, plus a `SignalingClient`/`SignalingServer` and WebRTC-DataChannel transport groundwork for internet play
