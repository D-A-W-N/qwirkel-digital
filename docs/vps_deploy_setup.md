# Internet-Server: einmaliges Coolify-Setup

Der dedizierte Internet-Multiplayer-Server (`packages/qwirkle_server`) läuft
als von Coolify verwaltete Application auf dem VPS (Hetzner, bereits mit
Coolify für ein anderes Projekt im Einsatz). Coolify übernimmt Build,
Reverse-Proxy und TLS selbst - kein eigener Caddy/Compose-Stack nötig. Die
folgenden Schritte sind einmalig in der Coolify-Oberfläche nötig, bevor
`.github/workflows/deploy-server.yml` bei jedem `v*`-Tag automatisch
deployen kann.

## 1. Neue Application in Coolify anlegen

- Ressourcentyp: **Docker Compose** (nicht "Dockerfile" - so ist der
  Build-Kontext eindeutig, siehe unten).
- Quelle: dieses GitHub-Repo, Branch `main`.
- Compose-Datei: [`docker-compose.yml`](../docker-compose.yml) am Repo-Root.
  Der Service darin (`qwirkle-server`) baut aus
  [`packages/qwirkle_server/Dockerfile`](../packages/qwirkle_server/Dockerfile)
  mit Build-Kontext = Repo-Root (nötig, weil `qwirkle_server` per Pfad von
  `../qwirkle_net`/`../qwirkle_core` abhängt).

**Falls Coolifys Compose-Import den Build-Kontext/Dockerfile-Pfad aus dem
`build:`-Block nicht wie erwartet übernimmt** (unterscheidet sich je nach
Coolify-Version): in den Coolify-Docs zum "Docker Compose"-Ressourcentyp
nachsehen, wie ein abweichender Kontext/Dockerfile-Pfad dort konfiguriert
wird - im Zweifel in der Coolify-UI direkt nachjustieren.

## 2. Umgebungsvariablen

In den Application-Settings (überschreiben bei Bedarf die Defaults aus der
`docker-compose.yml`):

| Variable              | Bedeutung                                   | Default        |
| ---------------------- | --------------------------------------------- | ---------------- |
| `PORT`                 | Interner Server-Port                          | `8080`           |
| `DATA_DIR`              | Ablageort der Raum-JSON-Dateien               | `/data/rooms`     |
| `ROOM_RETENTION_DAYS`   | Räume ohne Aktivität werden danach verworfen | `14`              |

## 3. Persistenter Speicher

Ein Volume/Mount auf `/data` in Coolify einrichten (die Compose-Datei
deklariert dafür bereits das benannte Volume `qwirkle_data`) - sonst gehen
laufende Partien bei jedem Redeploy verloren.

## 4. Domain

In den Application-Settings die Domain `qgames.streetkidz.duckdns.org`
eintragen, Ziel-Port `8080`. Coolify richtet den Traefik-Reverse-Proxy und
das Let's-Encrypt-Zertifikat dafür automatisch ein. Voraussetzung: der
DuckDNS-Eintrag für `qgames.streetkidz.duckdns.org` muss bereits auf die
VPS-IP zeigen (über [duckdns.org](https://www.duckdns.org) verwaltet,
unabhängig von Coolify).

Health-Check danach: `https://qgames.streetkidz.duckdns.org/health` sollte
`ok` liefern.

## 5. Deploy-Webhook für GitHub Actions

In Coolify für diese Application:

- Einen API-Token erzeugen (Coolify → Keys & Tokens / API Tokens).
- Die Deploy-Webhook-URL der Application kopieren (Coolify zeigt sie im
  Application-Bereich unter "Webhooks"/"Deploy" an - Format je nach Version
  z. B. `https://<coolify-host>/api/v1/deploy?uuid=<application-uuid>`).

Im GitHub-Repo unter „Settings → Secrets and variables → Actions“:

| Secret                | Wert                                  |
| ----------------------- | ---------------------------------------- |
| `COOLIFY_WEBHOOK_URL`   | Die kopierte Deploy-Webhook-URL         |
| `COOLIFY_API_TOKEN`     | Der erzeugte API-Token                  |

`deploy-server.yml` ruft diese URL bei jedem `v*`-Tag mit
`Authorization: Bearer <token>` auf. Weicht das genaue Auth-/URL-Format in
eurer Coolify-Version davon ab, den `curl`-Aufruf im Workflow entsprechend
anpassen - das lässt sich nicht ohne Zugriff auf die konkrete
Coolify-Instanz vorab verifizieren.

Ein manuelles Redeploy (ohne neuen Tag) geht jederzeit über den „Run
workflow“-Button des `Deploy Server`-Workflows in GitHub Actions, oder
direkt über den „Redeploy“-Button in Coolify selbst.

## Wartung

- Laufende Partien liegen als JSON-Dateien in `/data/rooms/` im
  konfigurierten Volume - bei Bedarf über Coolifys eigene
  Backup-/Volume-Funktionen sichern.
- Server-Logs sind über die Coolify-UI (Application → Logs) einsehbar.
