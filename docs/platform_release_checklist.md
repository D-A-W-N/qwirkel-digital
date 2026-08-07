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

## Android

- [x] Release-APK buildbar und signiert (`.github/workflows/desktop-build.yml`, Build-Job `build-android`)
- [x] Release-Keystore erzeugt, Signing-Secrets im Repo hinterlegt (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`) — **Keystore-Backup liegt nur lokal beim Betreiber, nicht im Repo, siehe Warnung im README/PR**
- [x] `INTERNET`-Berechtigung gesetzt (nötig für LAN-/Internet-Mehrspieler)
- [ ] App-Icon ist noch der generische Flutter-Platzhalter (wie auf Desktop) — eigenes Qwirkle-Icon fehlt noch
- [ ] Auf echtem Gerät getestet (Touch-Bedienung, Bildschirmgrößen) — bisher nur über CI gebaut, nicht manuell verifiziert
- [ ] In-App-Updater unterstützt Android nicht (bewusst zurückgestellt — Android braucht einen eigenen Install-Flow über `REQUEST_INSTALL_PACKAGES`/`FileProvider`, kein einfaches Rename-und-Neustart wie auf Desktop)
- [ ] Play-Store-Veröffentlichung (aktuell nur Sideload-APK über GitHub Releases)
