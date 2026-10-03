# JavaScript Minecraft Workshop Server

Ein vollständiger, selbst enthaltener Server-Stack zum Lehren von JavaScript-Programmierung durch Minecraft. Ein `docker compose up` startet alles.

## Was enthalten ist

| Container | Aufgabe |
|---|---|
| **caddy** | HTTPS-Reverse-Proxy, holt TLS-Zertifikat automatisch von Let's Encrypt |
| **spigot** | Spigot 26.3 (GraalVM JDK 25) mit [script4kids](https://github.com/cndrbrbr/script4kids)-, [cavecompass](https://github.com/cndrbrbr/cavecompass)-, [geomaptools](https://github.com/cndrbrbr/geomaptools)- und [PrometheusExporter](https://github.com/sladkoff/minecraft-prometheus-exporter)-Plugin |
| **webscriptcraft** | [Web-IDE](https://github.com/cndrbrbr/webscriptcraft) zum Schreiben und Visualisieren von Skripten |
| **homepage** | Workshop-Homepage sowie Blockly- und JavaScript-Kurs, ausgeliefert per nginx |

---

## Lokal testen

Kein Domain-Name, kein TLS nötig. `docker-compose.local.yml` muss explizit mit `-f` angegeben werden und deaktiviert Caddy. So wird verhindert, dass die lokale Konfiguration versehentlich in Produktion aktiv ist.

### 1. `.env` anlegen

```bash
git clone https://github.com/cndrbrbr/javascriptMinecraftWorkshopServer
cd javascriptMinecraftWorkshopServer

cp .env.example .env
# .env öffnen und HOST_IP auf die lokale IP des Rechners setzen:
# HOST_IP=192.168.1.49
```

### 2. Starten

```bash
./start_localhost.sh
```

Beim **ersten Start** baut Spigot sich selbst via BuildTools (~5–10 Min). Danach liegt der JAR auf dem Volume und der Start dauert nur Sekunden.

| Adresse | Service |
|---|---|
| http://HOST_IP:8080 | Workshop-Homepage |
| http://HOST_IP:8081 | Web-IDE |
| http://HOST_IP:8082 | Script-Upload |
| HOST_IP:25565 | Minecraft-Server |
| HOST_IP:9940 | Prometheus-Metriken (PrometheusExporter-Plugin) |

Die Homepage-Links zeigen automatisch auf die richtige IP — gesetzt durch `HOST_IP` in der `.env`.

> **Hinweis:** Für den Upload muss der Minecraft-Client mit `HOST_IP:25565` verbunden sein, nicht mit einer anderen Server-Adresse.

---

## Produktion (meckminecraft.de)

### 1. Server vorbereiten

Auf einem neuen Debian-Server als root:

```bash
bash setup-debian.sh <dein-benutzername>
```

Installiert Docker, Docker Compose, Git und die GitHub CLI (`gh`). Danach einmal aus- und wieder einloggen.

### 2. DNS-Einträge setzen

```
meckminecraft.de             A   <server-ip>
www.meckminecraft.de         A   <server-ip>
javascript.meckminecraft.de  A   <server-ip>
upload.meckminecraft.de      A   <server-ip>
```

### 3. Repo klonen und starten

```bash
gh auth login

gh repo clone cndrbrbr/javascriptMinecraftWorkshopServer
cd javascriptMinecraftWorkshopServer
```

Dann starten — Domain als Argument übergeben:

```bash
./start_production.sh meckminecraft.de
```

Das Skript setzt automatisch alle nötigen URLs (`SERVER_DOMAIN`, `IDE_URL`, `UPLOAD_URL`, `MC_ADDRESS`) auf die angegebene Domain.

Caddy übernimmt TLS automatisch, sobald die DNS-Einträge aufgelöst sind.

| URL | Service |
|---|---|
| https://meckminecraft.de | Workshop-Homepage |
| https://javascript.meckminecraft.de | Web-IDE |
| https://upload.meckminecraft.de | Script-Upload |
| meckminecraft.de:25565 | Minecraft-Server |
| meckminecraft.de:9940 | Prometheus-Metriken (intern für Monitoring-Server) |

---

## Serverkonfiguration

Alle Einstellungen in `docker-compose.yml` unter `environment` — kein Image-Rebuild nötig:

| Variable | Standard | Bedeutung |
|---|---|---|
| `SERVER_DOMAIN` | `meckminecraft.de` | Domain für Caddy (TLS) |
| `IDE_URL` | `https://javascript.meckminecraft.de` | Link zur Web-IDE auf der Homepage |
| `UPLOAD_URL` | `https://upload.meckminecraft.de` | Link zur Upload-Seite auf der Homepage |
| `MC_ADDRESS` | `meckminecraft.de` | Minecraft-Serveradresse auf der Homepage |

`kurs/` und `kurs-js/` werden von `homepage` selbst ausgeliefert und per relativem Link
verlinkt — keine eigene URL-Variable nötig.
| `MC_LEVELNAME` | `world` | Name der Welt |
| `MC_MAXPLAYERS` | `30` | Maximale Spielerzahl |
| `MC_PORT` | `25565` | Minecraft-Port |
| `MC_MEM_MIN` | `512M` | Minimaler RAM |
| `MC_MEM_MAX` | `2G` | Maximaler RAM |
| `FORCE_BUILD` | `false` | `true` → Spigot neu bauen, auch wenn JAR schon auf Volume liegt |

Spigot startet bei einem Absturz automatisch neu. Bei `/stop` in der Server-Console stoppt er sauber ohne Neustart.

> **Hinweis `online-mode=false`:** Der VPS kann Mojang's Authentifizierungsserver nicht erreichen, daher läuft der Server im Offline-Modus. Die Whitelist (`white-list=true`) übernimmt die Zugriffskontrolle.

---

## Whitelist

Der Server läuft mit `white-list=true` und `online-mode=false` (s.u.) — geprüft wird strikt per **Offline-UUID**
(`MD5("OfflinePlayer:<Name>")`), nicht per Name und nicht per echter Mojang-UUID. `cndrbrbr` ist mit der
korrekten Offline-UUID standardmäßig eingetragen.

Weitere Spieler vor dem Workshop hinzufügen:

1. `spigot/whitelist.json` einen Eintrag mit Name **und** korrekter Offline-UUID hinzufügen:
   ```bash
   python3 -c "
   import hashlib
   name = 'Steve'
   d = bytearray(hashlib.md5(('OfflinePlayer:' + name).encode()).digest())
   d[6] = (d[6] & 0x0f) | 0x30
   d[8] = (d[8] & 0x3f) | 0x80
   h = d.hex()
   print(f'{h[0:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}')"
   ```
   Alternativ: den Spieler einmal verbinden lassen — der Server loggt `UUID of player <Name> is <uuid>`, auch
   wenn die Verbindung als "nicht gewhitelistet" abgelehnt wird. Diese UUID übernehmen.

2. Container neu starten, damit die Datei neu eingelesen wird:
   ```bash
   docker compose restart spigot
   ```
   (Auf einem leeren Volume wird `whitelist.json` ohnehin nur beim allerersten Start auf das Volume kopiert.)

> **Hinweis:** `echo "whitelist add X" >> /proc/1/fd/0` — früher hier dokumentiert, um ohne Neustart nachzuladen —
> funktioniert mit diesem Container **nicht**. `spigot` läuft mit `tty: true`, wodurch `fd 0` ein PTY-*Slave* ist;
> Schreiben darauf landet auf der PTY-*Master*-Seite (die auch `docker logs` einliest) statt als Eingabe beim
> Java-Prozess anzukommen — der Text taucht im Log auf, wird aber nie als Server-Befehl ausgeführt. Für echte
> interaktive Konsolenbefehle ohne Neustart: `docker attach <container>` (Trennen mit `Ctrl-P Ctrl-Q`, nicht `Ctrl-C`).

---

## Updates

### Plugins (script4kids / cavecompass / geomaptools) aktualisieren

Die Plugins werden beim Image-Build als fertige Release-JARs von GitHub geladen. Welche Versionen,
steht als `ARG` oben in `spigot/Dockerfile`:

| ARG | Plugin | Release-Tag |
|---|---|---|
| `JSMN_VERSION` | script4kids | `v<version>-mc<MC_VERSION>`, z. B. `v1.1.0-mc26.3` |
| `CAVECOMPASS_VERSION` | cavecompass | `v<version>-mc<MC_VERSION>`, z. B. `v0.10.1-mc26.3` |
| `GEOMAPTOOLS_VERSION` | geomaptools | `v<version>-mc<MC_VERSION>`, z. B. `v4.37-mc26.3` |
| `PROMETHEUS_EXPORTER_VERSION` | PrometheusExporter | `v<version>` |

Für ein Update die Version dort hochsetzen und das Image neu bauen. Alte JARs von script4kids,
cavecompass und geomaptools werden beim Start aus `data/plugins/` entfernt, damit nicht zwei Versionen gleichzeitig laden.

```bash
# Lokal:
sudo docker compose -f docker-compose.yml -f docker-compose.local.yml build spigot && \
sudo docker compose -f docker-compose.yml -f docker-compose.local.yml up -d spigot

# Produktion:
docker compose --profile production build spigot && docker compose --profile production up -d spigot
```

### Minecraft-Version wechseln

`MC_VERSION` in `spigot/Dockerfile` setzen (für script4kids, cavecompass und geomaptools muss es dazu ein
passendes Release geben). Beim nächsten Start baut der Container die neue Spigot-Version via BuildTools.

> **Vorher ein Backup der Welt machen!** Minecraft konvertiert die Welt beim ersten Start auf die neue
> Version — das lässt sich nicht rückgängig machen. Auch die Spieler brauchen dann einen Minecraft-Client
> in genau dieser Version.

### Web-IDE aktualisieren

```bash
# Lokal:
sudo docker compose -f docker-compose.yml -f docker-compose.local.yml build webscriptcraft && \
sudo docker compose -f docker-compose.yml -f docker-compose.local.yml up -d webscriptcraft

# Produktion:
docker compose --profile production build webscriptcraft && docker compose --profile production up -d webscriptcraft
```

### Homepage aktualisieren

```bash
# Lokal:
sudo docker compose -f docker-compose.yml -f docker-compose.local.yml build homepage && \
sudo docker compose -f docker-compose.yml -f docker-compose.local.yml up -d homepage

# Produktion:
docker compose --profile production build homepage && docker compose --profile production up -d homepage
```

Weltdaten und Spielerskripte liegen im `minecraft_data`-Volume und werden von Rebuilds nicht berührt.

---

## Monitoring

Der Server stellt Prometheus-Metriken über das [PrometheusExporter](https://github.com/sladkoff/minecraft-prometheus-exporter)-Plugin auf Port `9940` bereit. Das Monitoring (Prometheus + Grafana) läuft auf einem separaten Server und trägt diesen Server als Scrape-Target ein:

```yaml
# prometheus.yml auf dem Monitoring-Server
scrape_configs:
  - job_name: "minecraft"
    static_configs:
      - targets: ["<server-ip>:9940"]
```

---

## Workshop-Ablauf (für Teilnehmer)

1. Stack starten: `sudo docker compose up -d`
2. Minecraft-Server beitreten (Adresse von der Homepage ablesen).
3. Web-IDE im Browser öffnen.
4. Script-Upload öffnen: Minecraft-Benutzernamen eingeben, `.js`-Datei auswählen, hochladen.
5. In Minecraft ausführen: `/runscript <name>`
6. Alle Skripte anzeigen: `/listscripts`

Die Upload-Seite prüft, ob der Spieler gerade eingeloggt ist — kein API-Key nötig.

---

## Projektstruktur

```
.env.example                    Vorlage für lokale Konfiguration (HOST_IP)
.env                            Lokale Konfiguration — nicht im Repo
docker-compose.yml              Orchestration (Produktion)
docker-compose.local.yml     Lokaler Test: kein Caddy, direkte Ports, HOST_IP
Caddyfile                       HTTPS-Proxy-Konfiguration
setup-debian.sh                 OS-Setup für neuen Debian-Server
spigot/
  Dockerfile                    Runtime-Image (GraalVM JDK + BuildTools) + Plugin-Release-JARs
  entrypoint.sh                 Start: Spigot bauen (1. Start), Crash-Restart-Loop
  watch_copy.sh                 Hilfsskript: Config-Datei per inotify auf Volume syncen
  server.properties             Minecraft-Serverkonfiguration (beim 1. Start auf Volume kopiert)
  whitelist.json                Whitelist (beim 1. Start auf Volume kopiert)
  eula.txt                      EULA-Akzeptanz
spigot/ (Volume: minecraft_data)
  spigot-26.3.jar               Beim ersten Start via BuildTools gebaut
  data/cfg/                     server.properties, bukkit.yml, spigot.yml, ...
  data/plugins/                 Plugin-JARs und Plugin-Daten
  data/worlds/                  Weltdaten
webscriptcraft/
  Dockerfile                    nginx mit Web-IDE
homepage/
  Dockerfile                    nginx mit Workshop-Homepage, Blockly- und JS-Kurs
  entrypoint.sh                 Setzt Links per envsubst beim Container-Start
  html/index.html               Homepage-Inhalt
  html/kurs/                    Blockly-Kurs (12 Lektionen), IDE-Link per envsubst
  html/kurs-js/                 JavaScript-Kurs (12 Kapitel)
```
