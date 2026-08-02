# Qwirkle Digital

Qwirkle Digital ist eine native Desktop-Anwendung für das bekannte Legespiel Qwirkle mit:

- Einzelspieler gegen KI
- lokalem Pass-and-Play
- Online-Multiplayer über eine einfache Host/Join-Session
- einer Flutter-basierten Desktop-UI für macOS, Linux und Windows

## Projektstruktur

- [app](app) – Flutter-App mit UI, Settings und Spieloberfläche
- [packages/qwirkle_core](packages/qwirkle_core) – reine Spiellogik, Regeln, KI und Scoring
- [packages/qwirkle_net](packages/qwirkle_net) – Netzwerk-Session-Logik für Multiplayer
- [docs](docs) – Release- und Desktop-Planung
- [.github/workflows](.github/workflows) – CI für Desktop-Builds

## Voraussetzungen

- Flutter SDK 3.24 oder neuer
- Dart SDK passend zur Flutter-Version
- Für macOS: Xcode und Command Line Tools
- Für Linux/Windows: die jeweiligen Desktop-Toolchains für Flutter

## Entwicklung starten

```sh
cd packages/qwirkle_core && dart pub get
cd ../../app && flutter pub get
```

## App ausführen

```sh
cd app
flutter run -d macos
flutter run -d linux
flutter run -d windows
```

## Tests und Qualität

```sh
cd packages/qwirkle_core
dart test
cd ../..
cd app
flutter test
flutter analyze
```

## Desktop-Builds

```sh
cd app
flutter build macos --release
flutter build linux --release
flutter build windows --release
```

## Branching und Releases

Für die Entwicklung gilt ein einfacher Git-Flow:

- `develop` ist der Integrationszweig für alle fertig getesteten Features
- `feature/*` wird für neue Arbeit angelegt
- `release/*` wird für die finale Vorbereitung eines Releases genutzt
- `main` bleibt der stabil veröffentlichbare Stand
- Build- und Release-Artefakte werden nur bei taggierten Releases im Format `v*` erzeugt

Die genaue Arbeitsweise ist in [docs/branching/README.md](docs/branching/README.md) beschrieben.

## Release-Checkliste

- [x] macOS-Release-Build ist lokal vorbereitet
- [x] Desktop-Workflow und CI-Datei sind angelegt
- [ ] finale App-Icons und Splash-Assets ergänzen
- [ ] macOS Signing/Notarization vorbereiten
- [ ] Linux- und Windows-Release auf echten Hosts verifizieren
- [ ] Installer/Package-Workflow für Distribution definieren

## Beitragen

1. Fork erstellen
2. Feature-Branch anlegen
3. Änderungen entwickeln und testen
4. Pull Request eröffnen

## Lizenz

Das Projekt ist aktuell für den privaten und frühen Release-Use vorbereitet. Eine endgültige Open-Source- oder kommerzielle Lizenz kann im Repository-Setup noch festgelegt werden.
