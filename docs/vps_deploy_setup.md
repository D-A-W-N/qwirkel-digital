# Internet-Server: einmaliges Coolify-Setup

Der dedizierte Internet-Multiplayer-Server (`packages/qwirkle_server`) läuft
als von Coolify verwaltete Application auf dem VPS (Hetzner, bereits mit
Coolify für ein anderes Projekt im Einsatz). Coolify übernimmt Build,
Reverse-Proxy, TLS und - über sein natives "Auto Deploy on Push" - auch das
Redeploy bei jedem Merge nach `main` selbst; es gibt keinen separaten
GitHub-Actions-Deploy-Schritt. Die folgenden Schritte sind einmalig in der
Coolify-Oberfläche nötig.

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

## 2. Auto-Deploy aktivieren

In den Application-Settings "Automatic Deployment"/"Auto Deploy on Push"
für den Branch `main` aktivieren (ggf. den zugehörigen GitHub-Webhook, den
Coolify dafür selbst am Repo einrichtet, bestätigen). Damit deployed
Coolify automatisch neu, sobald `main` sich ändert - inklusive jedes
regulären Release-Merges in diesem Repo.

Ein manuelles Redeploy geht jederzeit über den „Redeploy“-Button in
Coolify selbst.

## 3. Umgebungsvariablen

In den Application-Settings (überschreiben bei Bedarf die Defaults aus der
`docker-compose.yml`):

| Variable              | Bedeutung                                   | Default        |
| ---------------------- | --------------------------------------------- | ---------------- |
| `PORT`                 | Interner Server-Port                          | `8080`           |
| `DATA_DIR`              | Ablageort der Raum-JSON-Dateien               | `/data/rooms`     |
| `ROOM_RETENTION_DAYS`   | Räume ohne Aktivität werden danach verworfen | `14`              |

## 4. Persistenter Speicher

Ein Volume/Mount auf `/data` in Coolify einrichten (die Compose-Datei
deklariert dafür bereits das benannte Volume `qwirkle_data`) - sonst gehen
laufende Partien bei jedem Redeploy verloren.

## 5. Domain

In den Application-Settings die Domain `qgames.streetkidz.duckdns.org`
eintragen, Ziel-Port `8080`. Coolify richtet den Traefik-Reverse-Proxy und
das Let's-Encrypt-Zertifikat dafür automatisch ein. Voraussetzung: der
DuckDNS-Eintrag für `qgames.streetkidz.duckdns.org` muss bereits auf die
VPS-IP zeigen (über [duckdns.org](https://www.duckdns.org) verwaltet,
unabhängig von Coolify).

Health-Check danach: `https://qgames.streetkidz.duckdns.org/health` sollte
`ok` liefern.

## Firewall-Verifikation (Port 8080)

Die `docker-compose.yml` deklariert Port 8080 bewusst über `expose` statt
`ports` - Docker veröffentlicht ihn dadurch gar nicht erst auf einer
Host-Netzwerkschnittstelle, erreichbar ist er nur innerhalb des
Docker-Netzwerks (also für Traefik, das Coolify selbst davorsetzt). Das ist
bereits die wirksamste Schutzschicht, unabhängig von jeder Firewall-Regel.
Zusätzlich (Verteidigung in der Tiefe) einmalig nach dem Setup und nach
jeder Änderung an Firewall/Compose-Datei prüfen:

1. **Von außerhalb der VPS** (z. B. vom eigenen Rechner):

   ```sh
   curl -m 5 http://<VPS-IP>:8080/health
   ```

   Erwartet: Timeout oder „Connection refused" - jede Antwort (insb. `ok`)
   bedeutet, dass 8080 direkt erreichbar ist und TLS/Traefik umgangen
   werden kann. In dem Fall: Compose-Datei erneut prüfen (`expose` statt
   `ports`?) und ob eine Cloud-Firewall den Port versehentlich freigibt.
2. **Hetzner Cloud Firewall** (Hetzner-Konsole → Firewalls, getrennt von
   jeder Firewall auf der VM selbst): nur eingehend 22/tcp (SSH), 80/tcp,
   443/tcp erlauben. Keine Regel für 8080 (oder einen anderen internen
   Port) anlegen.
3. **Firewall auf der VM selbst**, falls zusätzlich zur Hetzner Cloud
   Firewall aktiv (z. B. `ufw`):

   ```sh
   sudo ufw status verbose
   ```

   Sollte ausschließlich 22/tcp, 80/tcp, 443/tcp auflisten - kein Eintrag
   für 8080.

## Backup-Strategie

Laufende Partien liegen als JSON-Dateien unter `/data/rooms/` im
konfigurierten Volume (`qwirkle_data`). Der Einsatz ist bewusst
risikoarm eingestuft: Rauminhalte sind reine Spielzustände (keine
Nutzerkonten/personenbezogenen Daten) und Räume ohne Aktivität verfallen
ohnehin nach `ROOM_RETENTION_DAYS` (Default 14 Tage) - im schlimmsten Fall
müssten Mitspieler:innen eine verlorene Partie neu starten. Ein volles
Enterprise-Backup-Konzept ist dafür nicht nötig, ein einfaches
regelmäßiges Snapshot reicht:

1. **Bevorzugt**: falls die genutzte Coolify-Version eine eingebaute
   Volume-/Scheduled-Backup-Funktion anbietet (Application → Backups bzw.
   Storage), diese für das `qwirkle_data`-Volume aktivieren - das deckt
   Speicherort, Zeitplan und Rotation ab, ohne zusätzliche Infrastruktur.
2. **Fallback**, falls nicht verfügbar: ein periodischer Cronjob auf der
   VPS (oder Coolifys "Scheduled Task", falls es beliebige Befehle
   unterstützt), der das Volume komprimiert außerhalb des Volumes selbst
   ablegt, z. B.:

   ```sh
   docker run --rm -v qwirkle_data:/data -v /root/backups:/backup \
     alpine tar czf /backup/qwirkle-data-$(date +%F).tar.gz /data
   ```

   Aufbewahrung: z. B. die letzten 7 Tage reichen aus - länger als die
   `ROOM_RETENTION_DAYS`-Frist aufzubewahren bringt keinen Mehrwert, da
   abgelaufene Räume ohnehin nicht mehr gültig sind.
3. Wichtig: die Backups **nicht** ausschließlich auf derselben VPS
   belassen (z. B. periodisch auf ein separates Object-Storage-Bucket oder
   den eigenen Rechner herunterladen) - sonst schützt das Backup nicht vor
   einem Totalausfall/Datenverlust der VPS selbst.

## Wartung

- Server-Logs sind über die Coolify-UI (Application → Logs) einsehbar.
