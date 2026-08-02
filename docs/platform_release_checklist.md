# Desktop-Release-Checkliste

## Allgemein

- [x] App auf macOS, Linux und Windows buildbar (`.github/workflows/desktop-build.yml`, alle drei Plattformen bei jedem Tag-Release)
- [x] Tests laufen auf allen drei Ziel-Betriebssystemen selbst — `ci.yml` läuft als Matrix-Build auf `ubuntu-latest`, `macos-latest` und `windows-latest`
- [x] Offizielle Build- und Startbefehle dokumentiert (Root-[README.md](../README.md))
- [x] Versionierung und Build-Nummer konsistent (`pubspec.yaml`-`version:` und Git-Tag `vX.Y.Z` seit v0.3.0 synchron gehalten)

## macOS

- [ ] Signed/Notarized Build vorbereitet (bewusst zurückgestellt — siehe Gatekeeper-Hinweis im Root-README)
- [x] App-Icon und Splash gesetzt
- [ ] Privacy-Info geprüft

## Linux

- [ ] Debian/Ubuntu- und Flatpak-Workflow geprüft
- [x] App-Icon und Desktop-Datei vorbereitet (`app/linux/runner/qwirkle_digital.desktop`)
- [ ] Start-Shortcut und Dateizuordnung geprüft

## Windows

- [ ] Installer- oder ZIP-Workflow geprüft (aktuell nur ZIP, kein Installer)
- [x] App-Icon vorbereitet (`app/windows/runner/resources/app_icon.ico`)
- [ ] Signierung/Vertrauensstatus vorbereitet
