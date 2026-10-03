# Changelog

## 2026-10-03

### Changed: Spigot 1.21.11 → 26.3, GraalVM JDK 21 → 25, cavecompass added

**`spigot/Dockerfile`**
- `MC_VERSION=26.3` (new ARG), passed to the entrypoint as `SPIGOT_VERSION`.
- Runtime GraalVM Community JDK `21.0.2` → `25.0.2`. Spigot 26.x needs Java 25.
- Plugins are no longer compiled in builder stages but downloaded as release
  JARs, with their versions as ARGs (`JSMN_VERSION`, `CAVECOMPASS_VERSION`,
  `GEOMAPTOOLS_VERSION`, `PROMETHEUS_EXPORTER_VERSION`). script4kids and
  cavecompass publish one release per Minecraft version
  (`v<version>-mc<MC_VERSION>`). The old builder stage would have broken
  anyway: script4kids' JAR is no longer called `jsmn-1.0-SNAPSHOT.jar`.
- New plugin: [cavecompass](https://github.com/cndrbrbr/cavecompass).

**`spigot/entrypoint.sh`**
- `SPIGOT_VERSION` comes from the image instead of being hard-coded.
- Before copying the plugin JARs to the volume, older `jsmn-*.jar` and
  `CaveCompass-*.jar` are removed. Their file names contain the version, so the
  old `jsmn-1.0-SNAPSHOT.jar` on existing volumes would otherwise load next to
  the new JAR.

**Upgrading an existing server:** back up the world first — it is converted to
26.3 on first start and cannot be opened by 1.21.11 afterwards. Players need a
26.3 client.

Tested: image build, and a first start on a volume holding a 1.21.11 world plus
the old `jsmn-1.0-SNAPSHOT.jar` (Spigot 26.3 built via BuildTools in the
container, all four plugins enabled, world converted, JavaScript test script
run on GraalVM 25.0.2).

---

## 2026-08-19

### Fixed: `docker compose build webscriptcraft` could silently serve stale content

**`webscriptcraft/Dockerfile`**

The image is built by `git clone`-ing `cndrbrbr/webscriptcraft` inside a `RUN` step. Docker caches `RUN`
layers by instruction text, and `git clone --depth=1 <url>` never changes text-wise — so a plain
`docker compose build webscriptcraft` (the documented update command, no `--no-cache`) can reuse a clone from
whenever that layer was first built, even after new commits landed on GitHub. Caught this live: after pushing
the legacy-PHP cleanup, a fresh `docker compose build` + `up -d` still served the old pre-cleanup hub page
until rebuilt with `--no-cache`.

Added `ADD https://api.github.com/repos/cndrbrbr/webscriptcraft/commits/main /tmp/webscriptcraft-head.json`
before the clone step. Docker re-fetches `ADD <url>` content on every build and only invalidates the cache
below it when the fetched body actually changed — so the clone step now re-runs exactly when there's a new
commit on `main`, and still hits cache otherwise. Verified both directions: a build after this change served
current content without `--no-cache`, and a second identical build hit cache on both the `ADD` and the clone
step since nothing upstream had changed.

### Fixed: documented whitelist hot-reload command doesn't work

**README.md** — Whitelist section

`docker compose exec spigot bash -c 'echo "whitelist add X" >> /proc/1/fd/0'` was documented as a way to add a
player without restarting. It doesn't work: `spigot` runs with `tty: true` (added for interactive console
access), so `fd 0` is a PTY *slave*. Writing to it goes out the PTY *master* side — which is what `docker logs`
reads — instead of reaching the Java process's own input. The command text shows up in the log looking like it
ran, but the server never executes it. Confirmed live: a player was rejected by the whitelist both before and
after sending the echo, with no change in behavior.

Also discovered while debugging: the offline-mode server checks the whitelist strictly by UUID (the
deterministic `MD5("OfflinePlayer:<name>")` offline UUID), not by name — a `whitelist.json` entry with the
right name but a stale/wrong UUID rejects the player exactly as if they weren't listed at all, with no
indication in the rejection message that the UUID is the problem.

Replaced the doc with the method that was actually verified working end-to-end (a player connecting
successfully): compute or read off the correct offline UUID, edit `whitelist.json` directly, then
`docker compose restart spigot`. Documented `docker attach` (which does reach the real console, since it
connects to the PTY master) as the option for live commands without a restart.

### Moved the Blockly-Kurs and JavaScript-Kurs from `webscriptcraft` into `homepage`

The two courses (`kurs/`, `kurs-js/`) had been built inside the `webscriptcraft`
repo alongside the IDE, so `KURS_BLOCKLY_URL`/`KURS_JS_URL` pointed across to
the IDE subdomain (`javascript.$DOMAIN/kurs/...`) to reach content that
belongs to the workshop server, not the IDE. `webscriptcraft` had also grown
its own redundant landing-hub page (`openb3/index.html`) duplicating
`homepage`'s job, with an upload link still hardcoded to the old
`upload.codefield.de` domain.

Moved `kurs/` and `kurs-js/` into `homepage/html/`, so `homepage` is now the
single owner of both the landing page and the course content; `webscriptcraft`
is IDE-only again. Course pages that linked to the IDE via relative paths
(`../ide.html`, `../../ide.html`) now use `${IDE_URL}`, substituted by
`homepage/entrypoint.sh` at container start — same mechanism `index.html`
already used.

### Replaced the homepage design with the webscriptcraft hub's card layout

`homepage/html/index.html` is now the dark-theme icon-card grid (IDE / Upload
/ Blockly-Kurs / JavaScript-Kurs + hero image) that used to live at
`webscriptcraft`'s root, rather than the old blue/navy design with intro text,
photo gallery, schedule, and commands table — those sections are gone. The
Upload card now uses `${UPLOAD_URL}` instead of the hardcoded
`upload.codefield.de` link the original hub carried; `kurs/`/`kurs-js/` are
linked with plain relative paths since they're served from this same
container now, so `KURS_BLOCKLY_URL`/`KURS_JS_URL` were removed from
`docker-compose.yml`, `docker-compose.local.yml`, `start_production.sh`, and
`homepage/entrypoint.sh` — nothing referenced them anymore.

## 2026-04-12

### Fixed: Script upload page not reachable (`upload.codefield.de`)

**`spigot/Dockerfile`** — Switch stage-2 runtime from `openjdk-21-jdk` to GraalVM Community JDK 21

The jsmn plugin (script4kids) uses the GraalVM Polyglot/Truffle API to execute
JavaScript. The plugin's `pom.xml` shades the required GraalVM libraries
(`org.graalvm.polyglot`, Truffle runtime, JS engine) into its JAR via
`maven-shade-plugin`. However the Docker build cache had preserved a stale
plugin JAR (45 KB) that was built before the shade step was added to the
`pom.xml` — so none of the GraalVM classes were present at runtime.

When jsmn tried to load, it immediately threw
`NoClassDefFoundError: org/graalvm/polyglot/PolyglotException` and never
started its HTTP upload server on port 25580. Caddy's
`reverse_proxy spigot:25580` therefore had nothing to connect to, causing every
request to `upload.codefield.de` to fail.

Fix: rebuild the plugin-builder stage without cache (`--no-cache`) so Maven
downloads and shades all GraalVM transitive JARs into the fresh 35 MB fat JAR.
The runtime is switched to GraalVM Community JDK 21 (downloaded from the
official GitHub release tarball) so JVMCI is available, which the shaded
Truffle runtime uses for optimised JavaScript compilation.

**`spigot/watch_copy.sh`** — Replace `inotifywait` with a polling loop

`inotify-tools` is not available in the new image. The script now uses
`stat -c "%Y"` to check the file's modification timestamp every 5 seconds and
copies on change. Behaviour is identical; no new dependency required.

---

## 2026-04-06

### Added: Prometheus metrics and geomaptools plugin

- **`docker-compose.yml`** — Expose port 9940 for Prometheus scraping; add
  `geomaptools` and `PrometheusExporter` to the plugin build pipeline.
- **`spigot/Dockerfile`** — Add stage 1b to build the
  [geomaptools](https://github.com/cndrbrbr/geomaptools) plugin from source;
  inject the SpigotMC Maven snapshot repository via a custom `settings.xml` to
  resolve the missing `spigot-api` dependency. Download the
  [minecraft-prometheus-exporter](https://github.com/sladkoff/minecraft-prometheus-exporter)
  v3.1.2 JAR and its config file into the image.
- **`spigot/prometheus-exporter-config.yml`** — Bind the Prometheus HTTP
  endpoint to `0.0.0.0` so an external Prometheus instance can scrape it
  (previously bound to `localhost` only).

---

## 2026-03-08

### Added: Convenience start scripts; domain-parameterised production start

- **`start_production.sh`** — Accepts the server domain as a positional
  argument (`./start_production.sh codefield.de`) and derives all service URLs
  (`IDE_URL`, `UPLOAD_URL`, `MC_ADDRESS`) automatically before calling
  `docker compose up`.
- **`start_localhost.sh`** — Reads `HOST_IP` from `.env` and starts the stack
  for local testing.
- **`docker-compose.yml`** — `IDE_URL`, `UPLOAD_URL`, and `MC_ADDRESS` are now
  passed as environment variables to the homepage container so the HTML buttons
  always point to the correct domain.

### Fixed: Whitelist UUID for offline-mode server

- **`spigot/whitelist.json`** — Corrected the UUID format required by Spigot
  when running in offline mode (`online-mode=false`).

---

## 2026-03-07

### Changed: Migrate all images to Debian Trixie

All Docker images switched from Ubuntu / Alpine / Debian Bookworm to
`debian:trixie-slim`. `openjdk-21-jdk` is available directly from the Trixie
repository without needing backports.

### Added: Interactive Spigot console

- **`docker-compose.yml`** — `stdin_open: true` and `tty: true` on the
  `spigot` service so `docker attach` gives a live Minecraft server console.

### Changed: Lazy Spigot build with structured volumes

- **`spigot/entrypoint.sh`** — Spigot is now compiled via BuildTools on the
  first container start and the resulting JAR is cached on the persistent
  `minecraft_data` volume. Subsequent restarts skip the build unless
  `FORCE_BUILD=true` is set.
- Plugins, world data, and config files are stored under `./data/` on the
  volume with a clear directory structure.

### Fixed: Homepage dynamic links for local testing

- **`homepage/entrypoint.sh`** — Uses `envsubst` to replace `${IDE_URL}`,
  `${UPLOAD_URL}`, and `${MC_ADDRESS}` placeholders in `index.html` at
  container start, replacing an earlier JavaScript-based approach.

### Fixed: online-mode disabled

- **`spigot/server.properties`** — `online-mode=false` because the VPS cannot
  reach Mojang's authentication servers.

---

## 2026-03-03

### Added: Homepage content

- **`homepage/html/index.html`** — Full workshop homepage with hero section,
  gallery, commands table, weekly schedule (every Friday, 13:00), and links to
  the Web IDE and script upload page.

---

## 2026-03-01 — 2026-03-02

### Added: Initial project

- Docker Compose stack with four services: `caddy` (HTTPS reverse proxy),
  `spigot` (Minecraft server + jsmn plugin), `homepage`, and `webscriptcraft`
  (Web IDE).
- Caddy routes `<domain>` → homepage, `javascript.<domain>` → Web IDE,
  `upload.<domain>` → Spigot upload server (port 25580).
- Automatic TLS certificate provisioning via Let's Encrypt.
