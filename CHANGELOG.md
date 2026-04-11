# Changelog

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
