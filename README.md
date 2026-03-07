# JavaScript Minecraft Workshop Server

Ein vollständiger, selbst enthaltener Server-Stack zum Lehren von JavaScript-Programmierung durch Minecraft. Ein `docker compose up` startet alles.

## Was enthalten ist

| Container | Aufgabe |
|---|---|
| **caddy** | HTTPS-Reverse-Proxy, holt TLS-Zertifikat automatisch von Let's Encrypt |
| **spigot** | Spigot 1.21.11 mit dem [script4kids](https://github.com/cndrbrbr/script4kids)-Plugin |
| **webscriptcraft** | [Web-IDE](https://github.com/cndrbrbr/webscriptcraft) zum Schreiben und Visualisieren von Skripten |
| **homepage** | Workshop-Homepage, ausgeliefert per nginx |

---

## Lokal testen

Kein Domain-Name, kein TLS nötig. `docker-compose.local.yml` wird von Docker automatisch mitgeladen und deaktiviert Caddy.

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
sudo docker compose -f docker-compose.yml -f docker-compose.local.yml up --build
```

Beim **ersten Start** baut Spigot sich selbst via BuildTools (~5–10 Min). Danach liegt der JAR auf dem Volume und der Start dauert nur Sekunden.

| Adresse | Service |
|---|---|
| http://HOST_IP:8080 | Workshop-Homepage |
| http://HOST_IP:8081 | Web-IDE |
| http://HOST_IP:8082 | Script-Upload |
| HOST_IP:25565 | Minecraft-Server |

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

Bei Bedarf Domain in `docker-compose.yml` anpassen (Standard: `meckminecraft.de`):

```yaml
caddy:
  environment:
    SERVER_DOMAIN: meckminecraft.de
homepage:
  environment:
    IDE_URL: https://javascript.meckminecraft.de
    UPLOAD_URL: https://upload.meckminecraft.de
    MC_ADDRESS: meckminecraft.de
```

Dann starten:

```bash
docker compose --profile production up -d --build
```

Caddy übernimmt TLS automatisch, sobald die DNS-Einträge aufgelöst sind.

| URL | Service |
|---|---|
| https://meckminecraft.de | Workshop-Homepage |
| https://javascript.meckminecraft.de | Web-IDE |
| https://upload.meckminecraft.de | Script-Upload |
| meckminecraft.de:25565 | Minecraft-Server |

---

## Serverkonfiguration

Alle Einstellungen in `docker-compose.yml` unter `environment` — kein Image-Rebuild nötig:

| Variable | Standard | Bedeutung |
|---|---|---|
| `SERVER_DOMAIN` | `meckminecraft.de` | Domain für Caddy (TLS) |
| `IDE_URL` | `https://javascript.meckminecraft.de` | Link zur Web-IDE auf der Homepage |
| `UPLOAD_URL` | `https://upload.meckminecraft.de` | Link zur Upload-Seite auf der Homepage |
| `MC_ADDRESS` | `meckminecraft.de` | Minecraft-Serveradresse auf der Homepage |
| `MC_LEVELNAME` | `world` | Name der Welt |
| `MC_MAXPLAYERS` | `30` | Maximale Spielerzahl |
| `MC_PORT` | `25565` | Minecraft-Port |
| `MC_MEM_MIN` | `512M` | Minimaler RAM |
| `MC_MEM_MAX` | `2G` | Maximaler RAM |
| `FORCE_BUILD` | `false` | `true` → Spigot neu bauen, auch wenn JAR schon auf Volume liegt |

Spigot startet bei einem Absturz automatisch neu. Bei `/stop` in der Server-Console stoppt er sauber ohne Neustart.

---

## Whitelist

Der Server läuft mit `white-list=true`. `cndrbrbr` ist standardmäßig eingetragen. Weitere Spieler vor dem Workshop hinzufügen:

```bash
docker compose exec spigot bash -c 'echo "whitelist add Steve" >> /proc/1/fd/0'
```

Oder `spigot/whitelist.json` im Repo bearbeiten und den Container neu starten (nur auf leerem Volume wirksam).

---

## Updates

### Plugin (script4kids) aktualisieren

```bash
sudo docker compose build spigot && sudo docker compose up -d spigot
```

### Web-IDE aktualisieren

```bash
sudo docker compose build webscriptcraft && sudo docker compose up -d webscriptcraft
```

### Homepage aktualisieren

```bash
sudo docker compose build homepage && sudo docker compose up -d homepage
```

Weltdaten und Spielerskripte liegen im `minecraft_data`-Volume und werden von Rebuilds nicht berührt.

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
  Dockerfile                    Plugin-Build (Maven) + Runtime-Image (JDK + BuildTools)
  entrypoint.sh                 Start: Spigot bauen (1. Start), Crash-Restart-Loop
  watch_copy.sh                 Hilfsskript: Config-Datei per inotify auf Volume syncen
  server.properties             Minecraft-Serverkonfiguration (beim 1. Start auf Volume kopiert)
  whitelist.json                Whitelist (beim 1. Start auf Volume kopiert)
  eula.txt                      EULA-Akzeptanz
spigot/ (Volume: minecraft_data)
  spigot-1.21.11.jar            Beim ersten Start via BuildTools gebaut
  data/cfg/                     server.properties, bukkit.yml, spigot.yml, ...
  data/plugins/                 Plugin-JARs und Plugin-Daten
  data/worlds/                  Weltdaten
webscriptcraft/
  Dockerfile                    nginx mit Web-IDE
homepage/
  Dockerfile                    nginx mit Workshop-Homepage
  entrypoint.sh                 Setzt Links per envsubst beim Container-Start
  html/index.html               Homepage-Inhalt
```
