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

- Flutter SDK 3.44 oder neuer (CI baut aktuell mit 3.44.8)
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

Siehe [docs/platform_release_checklist.md](docs/platform_release_checklist.md) für den aktuellen Stand pro Plattform.

## Installation (fertige Builds)

Fertige Builds für macOS, Linux und Windows gibt es unter [GitHub Releases](https://github.com/D-A-W-N/qwirkel-digital/releases) — jeweils als Zip/Tar.gz, kein Installer.

- **macOS**: Die App ist nicht signiert/notarisiert. Beim ersten Start blockiert Gatekeeper sie als "nicht verifizierter Entwickler" — über Rechtsklick → Öffnen (oder Systemeinstellungen → Datenschutz & Sicherheit) trotzdem starten.
- **Linux/Windows**: Archiv entpacken, ausführbare Datei starten.
- **Updates**: Auf macOS, Linux und Windows prüft die App selbst auf neue Versionen und kann sich per Klick aktualisieren (Einstellungen → "Nach Updates suchen").

## Beitragen

1. Fork erstellen
2. Feature-Branch anlegen
3. Änderungen entwickeln und testen
4. Pull Request eröffnen

## Lizenz

MIT, siehe [LICENSE](LICENSE).
