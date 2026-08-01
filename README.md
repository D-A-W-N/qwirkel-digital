# Qwirkle-Digital

Digitale Umsetzung des Legespiels Qwirkle. Einzelspieler gegen KI-Gegner (1-6 Spieler)
sowie Online-Mehrspieler mit Freunden. Ziel-Plattformen: macOS, Linux, Windows (später Mobile).

## Struktur

- `packages/qwirkle_core` – reine Spiellogik (Board, Beutel, Zugvalidierung, Scoring), unabhängig von Flutter.
- `app` – Flutter-App (UI, State-Management).

## Setup

```sh
cd packages/qwirkle_core && dart pub get
cd ../../app && flutter pub get
```

## App starten

```sh
cd app
flutter run -d macos   # oder -d chrome / -d windows / -d linux
```

## Tests

```sh
cd packages/qwirkle_core
dart test
```
