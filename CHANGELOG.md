# Changelog

## [Unreleased]

## [0.5.0] - 2026-08-02

- Extended the in-app self-updater to Windows (copy-and-relaunch via a detached PowerShell helper, since a running `.exe` cannot be renamed/overwritten in place)
- Added a house rule: a turn's newly placed tiles no longer need to lie in a single straight row/column, as long as they stay connected (T-/L-shaped placements are now allowed) — noted as a house rule in the in-app instructions

## [0.4.2] - 2026-08-02

- Fixed the silent startup update check being skippable by an unrelated failure (a stale-backup cleanup error could prevent the actual update check from ever running)

## [0.4.1] - 2026-08-02

- Fixed the host not seeing players join the lobby (client saw them fine)
- Fixed placed tiles getting stuck as a pending overlay and the status text getting stuck on "Host führt den Zug aus..." after a host move was rejected
- Host now detects and displays its own reachable LAN address instead of leaving misleading `127.0.0.1` defaults in the connection fields

## [0.4.0] - 2026-08-02

- Wired up internet multiplayer (WebRTC signaling/connection was fully implemented but never connected to the network screen)
- Fixed LAN hosting being unreachable from the UI (the host/join toggle was never actually passed through)
- Fixed the network host hanging when a player's connection dropped mid-game; the client now surfaces a "connection lost" error instead of silently freezing
- Added a deadlock end-condition: a game no longer runs forever if every player passes in a row with the bag empty
- Network games now render tiles with the same shapes/colors as local play instead of raw text
- CI now runs `qwirkle_net`'s test suite (previously never wired in)

## [0.3.1] - 2026-08-02

- Fixed a crash on every app startup in release mode, introduced in 0.3.0 (`cleanupStaleBackup()` read an uninitialized field before the updater had ever run)
- Fixed a stale error banner that could keep showing after backing out of a rejected tile placement
- Made empty board grid cells visible so stone spacing reads as consistent

## [0.3.0] - 2026-08-02

- Added an in-app self-updater for macOS and Linux (checks GitHub Releases, downloads, verifies, and applies updates in place)

## [0.2.0] - 2026-08-02

- Tightened Qwirkle placement validation rules
- Added GitHub Actions release workflow (tag-triggered builds and publishing)
- Added a persistent status bar to the game screen for turn/state feedback (bot thinking, exchange mode, pending placement, game over)

## [0.1.0] - 2026-08-02

- Initial desktop-ready project structure for Qwirkle Digital
- Added local single-player, pass-and-play and AI gameplay
- Added network lobby and multiplayer session flow
- Added CI workflow for macOS, Linux and Windows desktop builds
- Added desktop asset placeholders for Linux and Windows packaging
