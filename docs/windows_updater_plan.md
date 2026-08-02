# Plan: Windows-Support für den In-App-Updater

**Status: Umgesetzt am 2026-08-02** auf einer echten Windows-Maschine. Voller End-to-End-Zyklus mit dem echten Release-Build verifiziert: alte Version läuft, `prepare()` legt das Entpack-Verzeichnis parallel an, `confirmApply()` startet das Helper-Skript, die alte Exe beendet sich, Wait-Process/Copy-Item/Neustart laufen mit echten Pfaden (inkl. Leerzeichen) und echten DLLs durch, Entpack-Verzeichnis und Skript räumen sich selbst auf.

**Dabei gefundener und behobener Bug**: `confirmApply()` startete das Helper-Skript ursprünglich mit `ProcessStartMode.detached`. Auf echtem Windows zeigte sich, dass `powershell.exe` in diesem Modus (kein Konsolen-Handle) sofort beendet wird, bevor auch nur die erste Skriptzeile läuft — vermutlich weil der PowerShell-Konsolen-Host ohne jede Konsole nicht initialisieren kann. Das wäre von macOS aus nicht auffindbar gewesen. Fix: `ProcessStartMode.normal` (mit `-WindowStyle Hidden`) — unter Windows ist ein Kindprozess ohnehin nicht an die Lebensdauer des Elternprozesses gebunden (anders als bei Unix-Prozessgruppen), er überlebt das `exit(0)` der App problemlos.

Noch ausstehend — wie beim macOS-Pfad — ist der erste echte Release-Zyklus: ältere Version installieren und in der App gegen einen neuen Tag aktualisieren.

## Context

Der In-App-Updater (`app/lib/src/update/`) unterstützt bisher nur macOS und Linux (`UpdateTargetPlatform.unsupported` für alles andere, explizit inklusive Windows). Windows ist die letzte fehlende Plattform. Der Grund für den ursprünglichen Ausschluss: Windows kann eine laufende `.exe` (und ihre geladenen DLLs) nicht einfach umbenennen/überschreiben wie macOS/Linux das per `rename()` können — Dateien, die von einem laufenden Prozess offen gehalten werden, sind unter Windows gesperrt. Der bestehende macOS/Linux-Mechanismus (Bundle umbenennen, neues Bundle reinschieben, sofort neu starten) funktioniert deshalb strukturell nicht 1:1.

**Wichtiger Hinweis zur Verifizierbarkeit**: Von macOS aus ist der komplette Mechanismus nicht testbar — `flutter analyze` prüft Typen/Syntax zwar plattformunabhängig auch für windows-spezifischen Code, aber das eigentliche PowerShell-Skript, Pfad-Escaping mit echten Windows-Pfaden (Leerzeichen etc.), `Wait-Process`/`Copy-Item`-Verhalten und der komplette Download→Anwenden→Neustart-Zyklus lassen sich nur auf einer echten Windows-Maschine verifizieren. Vor dem ersten "richtigen" Einsatz sollte das einmal bewusst end-to-end durchgespielt werden (ältere Version installieren, gegen einen neuen Tag testen) — genau wie beim macOS-Pfad, der erst nach dem ersten echten Release-Zyklus als verifiziert galt.

## Mechanismus

Windows-typisches Muster für Apps ohne MSI-Installer (Copy-and-Relaunch via Helper-Skript, kein Installer-Wechsel nötig):

1. **`prepare()`** (unverändert wiederverwendbar): `downloadAssetNextTo`/`fetchChecksumHex`/`verifyChecksum` aus `update_applier.dart` sind bereits plattformunabhängig. Entpacken über `powershell -Command "Expand-Archive -Path '<zip>' -DestinationPath '<ziel>' -Force"` (in PowerShell 5.0+ eingebaut, auf jedem Windows 10/11 vorhanden — kein `archive`-Paket nötig, konsistent mit der bisherigen Entscheidung, native Tools statt eines reinen Dart-Zip-Decoders zu nutzen). Der Windows-Zip-Root enthält die Bundle-Dateien bereits direkt ohne Wrapper-Ordner (`Compress-Archive -Path ".../Release/*"` in `.github/workflows/desktop-build.yml`), also kein Unterordner-Suchen nötig (wie bei Linux, anders als bei macOS).
2. **`confirmApply()`** (neuer Mechanismus): Ein kleines, zur Laufzeit generiertes PowerShell-Skript wird nach `%TEMP%` geschrieben und **losgelöst** gestartet (`ProcessStartMode.detached`) mit der eigenen Prozess-ID, Quell- und Zielverzeichnis sowie dem Exe-Namen als Parametern. Direkt danach beendet sich der Dart-Prozess selbst (`exit(0)`), damit die Datei-Sperren freigegeben werden. Das Skript:
   - wartet per `Wait-Process -Id <PID> -Timeout 30`, bis der alte Prozess wirklich beendet ist,
   - kopiert die entpackten neuen Dateien per `Copy-Item -Recurse -Force` über das Installationsverzeichnis,
   - startet die neue `.exe` neu,
   - räumt sich selbst und das Entpack-Verzeichnis auf.
   - Aufruf mit `-ExecutionPolicy Bypass` (nur für diesen einen Aufruf, ändert nichts an der System-Policy) — sonst blockieren viele Windows-Standardinstallationen jedes Skript grundsätzlich.
3. **`cleanupStaleBackup()`**: Für Windows gibt es (anders als macOS/Linux) kein `.bak`-Umbenennungsschema, da der Austausch nicht per `rename()`, sondern per Kopieren nach Prozessende passiert — hier räumt die Methode nur ein eventuell liegen gebliebenes Entpack-Verzeichnis auf (z. B. falls die App zwischen Entpacken und Skriptstart abgestürzt ist).

**Bewusste Vereinfachung für V1**: kein Rollback, falls der Kopiervorgang mitten drin fehlschlägt (z. B. Festplatte voll) — gleiches Risikoprofil wie die meisten einfachen, installer-losen Windows-Apps. Ein sauberes Rollback bräuchte ein Backup-vor-dem-Überschreiben-Schema, das im PowerShell-Skript selbst nachgebaut werden müsste — für einen ersten Windows-Support bewusst zurückgestellt, kein Blocker.

## Konkreter PowerShell-Skript-Entwurf

```powershell
param(
  [int]$ProcessId,
  [string]$SourceDir,
  [string]$TargetDir,
  [string]$ExeName
)
try { Wait-Process -Id $ProcessId -Timeout 30 -ErrorAction SilentlyContinue } catch {}
Start-Sleep -Milliseconds 500
Copy-Item -Path (Join-Path $SourceDir '*') -Destination $TargetDir -Recurse -Force
Start-Process -FilePath (Join-Path $TargetDir $ExeName)
Remove-Item -Path $SourceDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
```

Aufruf aus Dart (`confirmApply()`):

```dart
await Process.start(
  'powershell.exe',
  [
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
    '-File', scriptPath,
    '-ProcessId', pid.toString(),
    '-SourceDir', _extractDirPath,
    '-TargetDir', _bundleDir,
    '-ExeName', _exeName,
  ],
  mode: ProcessStartMode.normal, // NICHT .detached, siehe Status oben
);
exit(0);
```

## Zu ändernde/neue Dateien

- **`app/lib/src/update/update_models.dart`**: `UpdateTargetPlatform` bekommt `windows`; `currentTargetPlatform()` prüft `Platform.isWindows`.
- **`app/lib/src/update/update_asset_selector.dart`**: `_assetNamesByPlatform` bekommt `UpdateTargetPlatform.windows: 'qwirkle-digital-windows.zip'`.
- **`app/lib/src/update/update_controller.dart`**: `updateApplierProvider`-Switch bekommt `case UpdateTargetPlatform.windows: return WindowsUpdateApplier(client);`.
- **Neu: `app/lib/src/update/update_applier_windows.dart`**: `WindowsUpdateApplier implements UpdateApplier` wie oben beschrieben, nutzt die geteilten Hilfsfunktionen aus `update_applier.dart` (`downloadAssetNextTo`, `fetchChecksumHex`, `verifyChecksum`) — kein `makeExecutable`-Aufruf nötig (keine Unix-Rechte unter Windows).
- **`setup_screen.dart`/`update_settings_section.dart`**: keine Änderung nötig — beide gaten bereits generisch auf `UpdateTargetPlatform.unsupported`, Windows wird automatisch aktiv, sobald es nicht mehr darauf abbildet.
- **`README.md`**: Zeile zum fehlenden Windows-Support entfernen/aktualisieren (aktuell: "Für Windows gibt es das nicht — dort müssen neue Releases manuell heruntergeladen werden.").
- **Neu: Test in `app/test/update_applier_test.dart`**: `WindowsUpdateApplier.cleanupStaleBackup` funktioniert ohne vorherigen `prepare()`-Aufruf (gleiches Regressionsmuster wie die bestehenden macOS-/Linux-Tests dort, siehe `MacosUpdateApplier`/`LinuxUpdateApplier` in derselben Datei) — reine Pfad-Logik, läuft auf jedem Host-Betriebssystem, prüft aber nur diesen einen Teilaspekt.

## Referenz: bestehende Muster zum Nachschlagen

- `app/lib/src/update/update_applier_linux.dart` — strukturell am ähnlichsten (kein Bundle-Wrapper-Ordner, direkter Exe-Name), guter Ausgangspunkt zum Kopieren/Anpassen.
- `app/lib/src/update/update_applier_macos.dart` — zeigt das Backup/Rollback-Muster, falls das für Windows später nachgerüstet werden soll.
- `app/lib/src/update/update_applier.dart` — geteilte Hilfsfunktionen (Download, Checksum, Retry-Rename), die auch für Windows wiederverwendet werden.

## Verifikation

- `flutter analyze` und `flutter test` müssen sauber bleiben (fängt Typ-/Syntaxfehler plattformunabhängig ab).
- Der bestehende `windows-latest`-CI-Job in `.github/workflows/desktop-build.yml` baut die App weiterhin erfolgreich (bestätigt nur, dass der neue Code kompiliert und die App startet — nicht, dass der Updater funktioniert).
- **Alles Weitere nur manuell auf einer echten Windows-Maschine**: Download, Checksum-Prüfung, Entpacken, das PowerShell-Skript (insbesondere Pfade mit Leerzeichen), Prozessende-Erkennung, Kopiervorgang, Neustart.
