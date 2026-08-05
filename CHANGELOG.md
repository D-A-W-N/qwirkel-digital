# Changelog

## [Unreleased]

## [0.9.17] - 2026-08-06

- Fixed the settings sheet not being fully visible/scrollable at large system text scale, which made the update controls unreachable

## [0.9.16] - 2026-08-05

- Replaced the collapsible bottom panel from 0.9.13 with a fixed, always-visible bar - the collapse/expand toggle never actually helped in practice (nothing worth hiding while waiting, forced open on your own turn anyway to reach the hand)

## [0.9.15] - 2026-08-05

- Fixed internet play occasionally freezing after a dropped connection (e.g. when the server backend redeploys mid-game) - the client/room owner now automatically retries reconnecting with a growing backoff instead of requiring a manual leave-and-rejoin

## [0.9.14] - 2026-08-05

- Added a dismissible "Du bist am Zug" dialog whenever it becomes your turn, in both local (hotseat) and network play, so a turn change is never missed - replaces the old one-shot local game-start snackbar

## [0.9.13] - 2026-08-05

- The board now gets the full screen by default in both local and network play - hand/buttons/status live in a new collapsible bottom panel instead of a fixed block, reclaiming most of the screen for players using large system text/zoom. The panel auto-expands whenever it becomes your turn and is always manually toggleable (tap or drag the handle)

## [0.9.12] - 2026-08-05

- Local and network play now share the same board, hand, score and status-banner widgets instead of parallel, drifting implementations - network play's chrome is noticeably leaner as a result (one redundant status line/banner removed), and the waiting status now names who you're waiting for

## [0.9.11] - 2026-08-05

- Fixed a bug where restarting a network/LAN game could leave a "ghost" tile on the fresh board (a placement staged but never sent right before the previous game ended) and taking it back would swap in an unrelated tile from the new hand

## [0.9.10] - 2026-08-05

- The "Zuletzt besuchte Räume" list now marks finished games with a "Beendet" label, and any entry can be removed from the list via a new close button

## [0.9.9] - 2026-08-05

- Network multiplayer now shows a summary of what the other player just did (tiles placed, exchanged, or passed), matching local play's bot-move highlight
- Replaced the still-clickable Zug senden/Zurücknehmen/Tauschen/Aussetzen buttons at the end of a network game with a centered overlay showing final scores and, for the room owner, a way to start a new round

## [0.9.8] - 2026-08-05

- Changed house rule: emptying your hand no longer awards a 6-point bonus

## [0.9.7] - 2026-08-05

- Changed house rule: the game no longer ends the instant one player empties their hand while the bag is empty - it now continues until every player's hand is empty (or nobody can move), so players who still have tiles get to keep playing; everyone who empties their hand still gets the usual 6-point bonus, not just the first
- Added pass and exchange to network multiplayer (previously only placing tiles was possible), matching local play

## [0.9.6] - 2026-08-05

- Fixed network moves that failed for an unexpected reason being silently swallowed (no error, tiles just reappeared reset) - the server now always responds with an error instead of only for a few specific, expected failure kinds
- Network play no longer clears a staged placement until the server actually confirms the move; a rejected move now stays visible together with a clearly marked error instead of disappearing
- Placing a tile in network play is now validated live (immediate feedback for e.g. a gap in the line), matching local play, instead of only surfacing after sending

## [0.9.5] - 2026-08-05

- Fixed the board appearing to vanish while scrolling (the fixed coordinate canvas from 0.9.4's jump fix was generously sized at 64000x64000px, almost entirely empty space around the actual play area - shrunk to a much less easy to get lost in ~19200x19200px)

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
