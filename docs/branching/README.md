# Git-Flow für Qwirkle Digital

## Ziel

Die Entwicklung soll über klare Branches laufen, damit:

- Feature-Änderungen isoliert entwickelt werden können
- der Hauptentwicklungszweig stabil bleibt
- nur taggierte Releases Builds und Artefakte erzeugen

## Branch-Strategie

- main: stabiler, veröffentlichbarer Zustand
- develop: Integrationszweig für alle fertig entwickelten Features
- feature/\*: ein Feature oder ein Bugfix pro Branch
- release/\*: Vorbereitung eines Releases aus develop
- hotfix/\*: dringende Korrekturen direkt auf main

## Workflow

1. Von develop einen Feature-Branch ableiten:
   ```sh
   git checkout develop
   git pull origin develop
   git checkout -b feature/kurzer-name
   ```
2. Änderungen entwickeln, testen und committen.
3. Pull Request von feature/\* nach develop eröffnen.
4. Nach Review und Merge wird develop weiterentwickelt.
5. Für ein Release wird aus develop ein release/\*-Branch erzeugt:
   ```sh
   git checkout develop
   git checkout -b release/v1.0.0
   ```
6. Release-Checks, Finalisierung und Tagging:
   ```sh
   git tag v1.0.0
   git push origin develop --tags
   ```
7. Der Release-Branch wird anschließend in main gemergt und der Tag löst den Build-Workflow aus.

## CI-Regeln

- Pushes auf Feature-Branches lösen keine Release-Builds aus.
- Pushes auf develop führen nur die normalen Prüfungen aus, falls gewünscht.
- Nur Tags im Format v\* lösen den Release-Build und die Veröffentlichung von Artefakten aus.

## Empfehlung für Pull Requests

- PRs sollten immer in develop münden.
- Für kleine Hotfixes kann direkt auf main gearbeitet werden, aber bevorzugt über hotfix/\* und anschließendes Merge-Back nach develop.
