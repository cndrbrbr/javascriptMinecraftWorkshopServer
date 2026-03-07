# JavaScript Minecraft Workshop Server

Ein vollständiger, selbst enthaltener Server-Stack zum Lehren von JavaScript-Programmierung durch Minecraft. Ein `docker compose up` startet alles.

## Was enthalten ist

| Container | Aufgabe |
|---|---|
| **caddy** | HTTPS-Reverse-Proxy, holt TLS-Zertifikat automatisch von Let's Encrypt |
| **spigot** | Spigot 1.21.1 mit dem [script4kids](https://github.com/cndrbrbr/script4kids)-Plugin |
| **webscriptcraft** | [Web-IDE](https://github.com/cndrbrbr/webscriptcraft) zum Schreiben und Visualisieren von Skripten |
| **homepage** | Workshop-Homepage, ausgeliefert per nginx |

---

## Lokal testen

Kein Domain-Name, kein TLS nötig. Die Datei `docker-compose.override.yml` ist bereits im Repo enthalten und wird von Docker automatisch mitgeladen.

```bash
git clone https://github.com/cndrbrbr/javascriptMinecraftWorkshopServer
cd javascriptMinecraftWorkshopServer

docker compose up --build
```

Beim **ersten Start** baut Spigot sich selbst via BuildTools (~5–10 Min). Danach liegt der JAR auf dem Volume und der Start dauert nur Sekunden.

| Adresse | Service |
|---|---|
| http://localhost:8080 | Workshop-Homepage |
| http://localhost:8081 | Web-IDE |
| http://localhost:8082 | Script-Upload |
| localhost:25565 | Minecraft-Server |

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

In `docker-compose.yml` die Domain anpassen (einmalig, eine Zeile):

```yaml
caddy:
  environment:
    SERVER_DOMAIN: meckminecraft.de   # ← hier eigene Domain eintragen
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

Wichtige Einstellungen können in `docker-compose.yml` unter `environment` geändert werden, ohne das Image neu zu bauen:

| Variable | Standard | Bedeutung |
|---|---|---|
| `SERVER_DOMAIN` | `meckminecraft.de` | Domain für Caddy (Homepage, Web-IDE, Upload) |
| `MC_LEVELNAME` | `world` | Name der Welt |
| `MC_MAXPLAYERS` | `30` | Maximale Spielerzahl |
| `MC_PORT` | `25565` | Minecraft-Port |
| `MC_MEM_MIN` | `512M` | Minimaler RAM |
| `MC_MEM_MAX` | `2G` | Maximaler RAM |
| `FORCE_BUILD` | `false` | `true` → Spigot neu bauen, auch wenn JAR schon auf Volume liegt |

Spigot startet bei einem Absturz automatisch neu. Bei `/stop` im Server-Console stoppt er sauber ohne Neustart.

---

## Whitelist

Der Server läuft mit `white-list=true`. Spieler vor dem Workshop hinzufügen:

```bash
# Serverkonsole öffnen
docker compose exec spigot bash
# Im Container:
cd /server
# whitelist.json bearbeiten, dann Server neu starten
```

Oder direkt per Befehl:

```bash
docker compose exec spigot bash -c 'echo "whitelist add Steve" >> /proc/1/fd/0'
```

---

## Updates

### Plugin (script4kids) aktualisieren

```bash
docker compose build spigot
docker compose up -d spigot
```

### Web-IDE aktualisieren

```bash
docker compose build webscriptcraft
docker compose up -d webscriptcraft
```

Weltdaten und Spielerskripte liegen im `minecraft_data`-Volume und werden von Rebuilds nicht berührt.

---

## Workshop-Ablauf (für Teilnehmer)

1. Stack starten: `docker compose up -d`
2. Alle Geräte mit dem Internet verbinden.
3. Minecraft-Server beitreten: `meckminecraft.de` (oder `localhost` beim lokalen Test).
4. Web-IDE im Browser öffnen.
5. Script-Upload öffnen: Minecraft-Benutzernamen eingeben, `.js`-Datei auswählen, hochladen.
6. In Minecraft ausführen: `/runscript <name>`
7. Alle Skripte anzeigen: `/listscripts`

Die Upload-Seite prüft, ob der Spieler gerade eingeloggt ist — kein API-Key nötig für Teilnehmer auf der Whitelist.

---

## Projektstruktur

```
docker-compose.yml              Orchestration (Produktion + Lokal)
docker-compose.override.yml     Lokaler Test: kein Caddy, direkte Ports
Caddyfile                       HTTPS-Proxy-Konfiguration (meckminecraft.de)
setup-debian.sh                 OS-Setup für neuen Debian-Server
spigot/
  Dockerfile                    Plugin-Build (Maven) + Runtime-Image (JDK + BuildTools)
  entrypoint.sh                 Start: Spigot bauen (1. Start), Crash-Restart-Loop
  watch_copy.sh                 Hilfsskript: Datei per inotify auf Volume synchronisieren
  server.properties             Minecraft-Serverkonfiguration
  eula.txt                      EULA-Akzeptanz
spigot/data/ (Volume)
  cfg/                          server.properties, bukkit.yml, spigot.yml, ...
  plugins/                      Plugin-JARs und Plugin-Daten
  worlds/                       Weltdaten
webscriptcraft/
  Dockerfile                    nginx mit Web-IDE (webscriptcraft)
homepage/
  Dockerfile                    nginx mit Workshop-Homepage
  html/
    index.html                  Homepage (hier Inhalte anpassen)
```
