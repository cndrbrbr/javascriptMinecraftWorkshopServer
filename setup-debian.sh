#!/bin/bash
# ============================================================
# setup-debian.sh
# Sets up a fresh Debian system for the JavaScript Minecraft
# Workshop Server: Docker, Docker Compose, Git, gh CLI.
#
# Run as root:
#   bash setup-debian.sh [username]
#
# The optional username is added to the docker group so the
# user can run Docker without sudo.
# ============================================================
set -e

INSTALL_USER="${1:-}"

echo "=== Updating system ==="
apt-get update && apt-get upgrade -y

echo "=== Installing prerequisites ==="
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git

# ── Docker ──────────────────────────────────────────────────
echo "=== Installing Docker ==="
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

systemctl enable docker
systemctl start docker
echo "Docker $(docker --version) installed."

# ── GitHub CLI ──────────────────────────────────────────────
echo "=== Installing GitHub CLI ==="
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
  https://cli.github.com/packages stable main" \
  | tee /etc/apt/sources.list.d/github-cli.list > /dev/null

apt-get update
apt-get install -y gh
echo "gh $(gh --version | head -1) installed."

# ── Docker group ────────────────────────────────────────────
if [ -n "$INSTALL_USER" ]; then
    usermod -aG docker "$INSTALL_USER"
    echo "User '$INSTALL_USER' added to the docker group."
    echo "Log out and back in for the group change to take effect."
fi

# ── Done ────────────────────────────────────────────────────
echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Authenticate with GitHub:       gh auth login"
echo "  2. Clone the project:"
echo "       gh repo clone cndrbrbr/javascriptMinecraftWorkshopServer"
echo "  3. Enter the project directory:"
echo "       cd javascriptMinecraftWorkshopServer"
echo "  4. Add players to the whitelist:   edit spigot/whitelist.json"
echo "  5. Start everything:               docker compose up -d --build"
echo "  6. Open the IDE at:                https://meckminecraft.de"
echo "     Upload scripts at:              https://upload.meckminecraft.de"
