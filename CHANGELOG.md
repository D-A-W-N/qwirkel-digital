# Changelog

## [Unreleased]

## [0.9.4] - 2026-08-05

- Fixed the board occasionally jumping mid-game on an unrelated tap (tile positions were recomputed relative to a dynamic bounding-box minimum that shifted whenever the board's extent changed - now uses a fixed coordinate origin)
- Network multiplayer's board now expands immediately while staging a placement during your own turn, instead of only after the move is confirmed by the server
- Network multiplayer now shows a live points preview for the staged placement, matching local play
- Fixed a host losing access to their own room after leaving it - the "zuletzt besuchte Räume" list is now shown regardless of the hosting/joining toggle

## [0.9.3] - 2026-08-05

- Fixed the board always opening scrolled to its top-left corner instead of centered (local and network play)
- Network multiplayer now places tiles via drag-and-drop, matching local play, instead of tap-to-select-then-tap-to-place

## [0.9.2] - 2026-08-05

- Fixed hosting/joining an internet room crashing before showing the invite code the very first time (no room history saved yet triggered an "unmodifiable list" crash)
- The internet server address is now hidden by default behind a "andere Server-Adresse verwenden" toggle instead of always showing an editable field

## [0.9.1] - 2026-08-05

- Fixed a shutdown race in the internet-server backend where force-closing the HTTP server could trigger disconnect-handling writes that arrived after the server had already reported itself fully shut down (relevant for redeploys, caught by qwirkle_server's own macOS CI run)

## [0.9.0] - 2026-08-05

- Replaced Internet-Mehrspieler's WebRTC/P2P approach (which required the host to be reachable from outside, i.e. port forwarding, and had no TURN fallback) with a dedicated, always-on backend server (`packages/qwirkle_server`) run on a VPS via Coolify and auto-deployed via GitHub Actions on release tags: players only ever make outbound connections to the server, disconnected players' seats wait to be reclaimed via a reconnect token instead of being auto-skipped, and rooms are persisted to disk so a server redeploy or a days-long pause never loses a running game. LAN play is unaffected.

## [0.8.0] - 2026-08-03

- Changed scoring house rule: each newly placed tile in a turn now scores individually based on the line length at the moment it's placed (e.g. 3 tiles extending a line score 1+2+3, not just the final line length) — previously a multi-tile turn scored once per completed line, matching official Qwirkle rules; also added a second, explicit "points this turn vs. total after confirming" line to the in-progress-move status text to avoid confusing the two

## [0.7.1] - 2026-08-02

- Fixed every Windows in-app update failing: `Expand-Archive` refuses to process a file that doesn't literally end in `.zip`, but the downloaded update was named without one

## [0.7.0] - 2026-08-02

- Show the live point value of the currently staged (unconfirmed) placement during your turn
- Added a bot-speed setting (langsam/normal/schnell) for how long a bot "thinks" before its move
- Bot's last placed tiles are now briefly highlighted, and the status bar summarizes what it did (placement/exchange/pass, with points)
- Fixed exchanging tiles not visibly ending the turn (the engine already advanced it, but the UI's exchange-mode state never reset)
- The starting player and the house-rule reason (longest possible run from the starting hand) are now announced at the start of a game

## [0.6.0] - 2026-08-02

- Bot AI now also plays T-/L-shaped moves under the multi-direction house rule (previously only straight lines, even though human players could already bend a move)
- CI now runs the full test suite on macOS, Linux, and Windows for every change, not just Linux

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
