# JavaScript Minecraft Workshop Server

A complete, self-contained server stack for teaching JavaScript programming
through Minecraft. One `docker compose up` starts everything.

## What's included

| Container | What it does |
|---|---|
| **caddy** | HTTPS reverse proxy, auto-obtains TLS cert from Let's Encrypt |
| **spigot** | PaperMC 1.21.1 with the [script4kids](https://github.com/cndrbrbr/script4kids) plugin |
| **webscriptcraft** | [Web IDE](https://github.com/cndrbrbr/webscriptcraft) for writing and visualising scripts |

URLs after deployment:

| URL | Service |
|---|---|
| `https://javascript.meckminecraft.de` | Web IDE |
| `https://upload.meckminecraft.de` | Script upload page |
| `meckminecraft.de:25565` | Minecraft server |

---

## Fresh Debian setup

On a new Debian server, run as root:

```bash
bash setup-debian.sh <your-username>
```

This installs Docker, Docker Compose, Git, and the GitHub CLI (`gh`), and adds
your user to the `docker` group. Log out and back in after it completes.

---

## Deploying

```bash
# Authenticate with GitHub (once)
gh auth login

# Clone this repo
gh repo clone cndrbrbr/javascriptMinecraftWorkshopServer
cd javascriptMinecraftWorkshopServer

# Edit the whitelist before first start
# Add one Minecraft username per line (see Whitelist section below)

# Build images and start everything
docker compose up -d --build
```

The first build takes a few minutes — it compiles the script4kids plugin from
source and downloads PaperMC.

---

## Whitelist

The server runs with `white-list=true`. Add players before the workshop:

```bash
# Attach to the server console
docker compose exec spigot bash
# Inside the container:
cd /server
# Edit whitelist.json manually, then reload:
# The server will pick up changes on restart or via the console
```

Or send commands directly to the running server:

```bash
docker compose exec spigot bash -c \
  'echo "whitelist add Steve" >> /proc/1/fd/0'
```

The simplest approach: stop the stack, edit the whitelist file in the
`minecraft_data` volume, then restart.

---

## Updating the plugin

When script4kids is updated on GitHub, rebuild the spigot image:

```bash
docker compose build spigot
docker compose up -d spigot
```

World data and player scripts are stored in the `minecraft_data` volume and
are not affected by rebuilds.

## Updating the web IDE

```bash
docker compose build webscriptcraft
docker compose up -d webscriptcraft
```

---

## Workshop setup (for participants)

1. Start the stack: `docker compose up -d`
2. All participants connect their devices to the internet.
3. Everyone joins the Minecraft server at `meckminecraft.de`.
3. Open `https://javascript.meckminecraft.de` in a browser for the web IDE.
4. Open `https://upload.meckminecraft.de` to upload scripts.
5. Enter your Minecraft username, pick your `.js` script file, click Upload.
6. Switch to Minecraft and run it: `/runscript <name>`
7. View all scripts with `/listscripts`.

The upload page verifies that the player is currently logged in before
accepting the file — no API key required for whitelisted workshop participants.

---

## DNS records required

Point these at your server's IP address:

```
javascript.meckminecraft.de  A   <server-ip>
upload.meckminecraft.de      A   <server-ip>
```

Caddy handles TLS automatically once the DNS records resolve.

---

## Project structure

```
docker-compose.yml          Orchestration
Caddyfile                   HTTPS proxy config (meckminecraft.de)
setup-debian.sh             Fresh OS setup script
spigot/
  Dockerfile                Multi-stage: build plugin + PaperMC runtime
  entrypoint.sh             Startup script (initialises data volume)
  server.properties         Minecraft server config
  eula.txt                  EULA acceptance
webscriptcraft/
  Dockerfile                nginx serving the web IDE
```
