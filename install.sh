#!/bin/bash
# 🦞 Lobster Farm - One-Click Installer
# Usage: curl -sSL https://raw.githubusercontent.com/CorellisOrg/corellis/main/install.sh | bash
#
# What this does:
#   1. Checks Docker & Docker Compose
#   2. Clones the repo
#   3. Builds the Docker image (~3-5 min)
#   4. Creates directory structure
#   5. Prepares .env for you to fill in

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}[corellis]${NC} $*"; }
ok()   { echo -e "${GREEN}✅ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
fail() { echo -e "${RED}❌ $*${NC}"; exit 1; }

INSTALL_DIR="${LOBSTER_FARM_DIR:-$HOME/corellis}"
REPO_URL="${LOBSTER_FARM_REPO:-https://github.com/CorellisOrg/corellis.git}"
IMAGE_NAME="lobster-openclaw:latest"

echo ""
echo -e "${CYAN}🦞 Lobster Farm Installer${NC}"
echo "================================"
echo ""

# ── Step 1: Check prerequisites ──
log "Checking prerequisites..."

if ! command -v docker &>/dev/null; then
    fail "Docker not found. Install it first: https://docs.docker.com/get-docker/"
fi

if ! docker compose version &>/dev/null 2>&1; then
    if ! docker-compose version &>/dev/null 2>&1; then
        fail "Docker Compose not found. Install it first: https://docs.docker.com/compose/install/"
    fi
fi

if ! docker info &>/dev/null 2>&1; then
    fail "Docker daemon not running, or you don't have permission. Try: sudo usermod -aG docker \$USER"
fi

ok "Docker & Compose ready"

# ── Step 2: Clone repo ──
if [ -d "$INSTALL_DIR" ]; then
    warn "$INSTALL_DIR already exists. Updating..."
    cd "$INSTALL_DIR" && git pull --ff-only 2>/dev/null || true
else
    log "Cloning Corellis..."
    git clone "$REPO_URL" "$INSTALL_DIR" 2>/dev/null || {
        # If git clone fails (repo not public yet), create manually
        warn "Git clone failed. Creating directory structure manually..."
        mkdir -p "$INSTALL_DIR"/{scripts,configs,company-memory,company-skills,backups}
    }
fi

cd "$INSTALL_DIR"
ok "Repository ready at $INSTALL_DIR"

# ── Step 3: Build Docker image ──
if docker image inspect "$IMAGE_NAME" &>/dev/null; then
    warn "Image $IMAGE_NAME already exists. Skipping build."
    warn "To rebuild: docker build -f docker/Dockerfile.lite -t $IMAGE_NAME ."
else
    if [ -f Dockerfile ]; then
        log "Building Docker image (this takes 3-5 minutes)..."
        docker build -f docker/Dockerfile.lite -t "$IMAGE_NAME" . 2>&1 | tail -5
        ok "Image built: $IMAGE_NAME"
    else
        warn "No Dockerfile found. You'll need to build the image manually."
    fi
fi

# ── Step 4: Create directory structure ──
log "Setting up directories..."
mkdir -p configs company-memory company-skills backups
ok "Directories ready"

# ── Step 5: Prepare .env ──
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        ok ".env created from template"
    else
        warn "No .env.example found. Create .env manually with your API keys."
    fi
else
    ok ".env already exists"
fi

# ── Step 6: Prepare docker-compose.yml ──
if [ ! -f docker-compose.yml ]; then
    if [ -f docker-compose.base.yml ]; then
        cp docker-compose.base.yml docker-compose.yml
        ok "docker-compose.yml created from template"
    fi
else
    ok "docker-compose.yml already exists"
fi

# ── Done ──
echo ""
echo "================================"
ok "Lobster Farm is ready!"
echo ""
echo -e "📝 ${YELLOW}Next steps:${NC}"
echo ""
echo "  1. Edit your API keys:"
echo -e "     ${CYAN}nano $INSTALL_DIR/.env${NC}"
echo ""
echo "  2. Spawn your first lobster:"
echo -e "     ${CYAN}cd $INSTALL_DIR${NC}"
echo -e "     ${CYAN}./scripts/spawn-lobster.sh alice <SLACK_USER_ID> <BOT_TOKEN> <APP_TOKEN>${NC}"
echo ""
echo "  3. Or if you have OpenClaw with the corellis skill:"
echo -e "     ${CYAN}Just say: \"spawn lobster alice\"${NC}"
echo ""
echo -e "📖 Full guide: ${CYAN}https://github.com/CorellisOrg/corellis${NC}"
echo ""
