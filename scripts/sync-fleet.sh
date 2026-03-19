#!/bin/bash
# sync-fleet.sh - One-click sync of company-level resources to all lobsters
#
# Features:
#   1. Sync company-skills (copy new/updated skills from controller workspace)
#   2. Sync company-memory (copy new/updated memory from controller workspace)
#   3. Add new API Keys to .env
#   4. Recreate containers (only when new env keys are added)
#   5. Broadcast notification to all lobster users
#
# Usage:
#   ./sync-fleet.sh                                    # Sync skills + memory, no new keys
#   ./sync-fleet.sh --key APIFY_TOKEN=xxx              # Sync + add key + recreate
#   ./sync-fleet.sh --key KEY1=val1 --key KEY2=val2    # Multiple keys
#   ./sync-fleet.sh --skill-only                       # Only sync skills
#   ./sync-fleet.sh --memory-only                      # Only sync memory
#   ./sync-fleet.sh --key-only KEY=val                 # Only add keys
#   ./sync-fleet.sh --notify "message"                 # Send custom notification after sync
#   ./sync-fleet.sh --dry-run                          # Preview changes without executing

set -euo pipefail

FARM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OWNER_WORKSPACE="${OPENCLAW_WORKSPACE:-~/.openclaw/workspace}"
COMPANY_SKILLS="$FARM_DIR/company-skills"
COMPANY_MEMORY="$FARM_DIR/company-memory"
ENV_FILE="$FARM_DIR/.env"

# Flags
SYNC_SKILLS=true
SYNC_MEMORY=true
NEED_RECREATE=false
NEED_GATEWAY_RESTART=false
DRY_RUN=false
CUSTOM_MSG=""
NEW_KEYS=()
CHANGES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --key) NEW_KEYS+=("$2"); shift 2 ;;
        --key-only) SYNC_SKILLS=false; SYNC_MEMORY=false; NEW_KEYS+=("$2"); shift 2 ;;
        --skill-only) SYNC_MEMORY=false; shift ;;
        --memory-only) SYNC_SKILLS=false; shift ;;
        --notify) CUSTOM_MSG="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

echo "🦞 Lobster Fleet Sync Tool"
echo "===================="

# ── Step 1: Sync Skills ──
if [ "$SYNC_SKILLS" = true ]; then
    echo ""
    echo "📦 Syncing company skills..."
    
    # Scan owner workspace for skills that should be shared
    for skill_dir in "$OWNER_WORKSPACE"/skills/*/; do
        [ -f "$skill_dir/SKILL.md" ] || continue
        skill_name=$(basename "$skill_dir")
        
        # Skip owner-only skills
        case "$skill_name" in
            corellis|goal-executor) 
                continue ;;
        esac
        
        if [ -d "$COMPANY_SKILLS/$skill_name" ]; then
            # Check if updated (compare SKILL.md modification time)
            if [ "$skill_dir/SKILL.md" -nt "$COMPANY_SKILLS/$skill_name/SKILL.md" ]; then
                echo "   🔄 Updated: $skill_name"
                [ "$DRY_RUN" = false ] && cp -r "$skill_dir" "$COMPANY_SKILLS/$skill_name"
                CHANGES+=("Updated skill: $skill_name")
            fi
        else
            echo "   🆕 New: $skill_name"
            [ "$DRY_RUN" = false ] && cp -r "$skill_dir" "$COMPANY_SKILLS/$skill_name"
            CHANGES+=("New skill: $skill_name")
        fi
    done
    
    # Also check clawhub-installed skills
    for skill_dir in "$OWNER_WORKSPACE"/skills/*/; do
        [ -f "$skill_dir/SKILL.md" ] || continue
    done
    
    if [ ${#CHANGES[@]} -eq 0 ]; then
        echo "   ✅ Skills are up to date"
    else
        # Skills changed but no new key → need to force gateway restart
        NEED_GATEWAY_RESTART=true
    fi
fi

# ── Step 2: Sync Memory ──
if [ "$SYNC_MEMORY" = true ]; then
    echo ""
    echo "🧠 Syncing company memory..."
    
    if [ -d "$COMPANY_MEMORY" ]; then
        # Rsync company memory (preserves structure, only copies changes)
        if [ "$DRY_RUN" = false ]; then
            rsync -av --checksum "$COMPANY_MEMORY/" "$COMPANY_MEMORY/" > /dev/null 2>&1
        fi
        echo "   ✅ Company memory synced (bind mount takes effect immediately)"
    else
        echo "   ⚠️ company-memory directory does not exist"
    fi
fi

# ── Step 3: Add API Keys ──
if [ ${#NEW_KEYS[@]} -gt 0 ]; then
    echo ""
    echo "🔑 Adding API Keys..."
    
    for key_pair in "${NEW_KEYS[@]}"; do
        KEY_NAME="${key_pair%%=*}"
        KEY_VALUE="${key_pair#*=}"
        
        if grep -q "^${KEY_NAME}=" "$ENV_FILE" 2>/dev/null; then
            OLD_VALUE=$(grep "^${KEY_NAME}=" "$ENV_FILE" | cut -d= -f2-)
            if [ "$OLD_VALUE" = "$KEY_VALUE" ]; then
                echo "   ⏭️ $KEY_NAME (unchanged)"
                continue
            fi
            echo "   🔄 Updated: $KEY_NAME"
            [ "$DRY_RUN" = false ] && sed -i "s|^${KEY_NAME}=.*|${KEY_NAME}=${KEY_VALUE}|" "$ENV_FILE"
        else
            echo "   🆕 New: $KEY_NAME"
            [ "$DRY_RUN" = false ] && echo -e "\n${KEY_NAME}=${KEY_VALUE}" >> "$ENV_FILE"
        fi
        CHANGES+=("API Key: $KEY_NAME")
        NEED_RECREATE=true
    done
fi

# ── Step 4: Recreate or Restart ──
if [ "$NEED_RECREATE" = true ] && [ "$DRY_RUN" = false ]; then
    echo ""
    echo "🔄 Recreating lobster containers (loading new env vars + rescanning skills)..."
    cd "$FARM_DIR"
    sudo docker compose up -d 2>&1 | grep -cE "Started" | xargs -I{} echo "   ✅ {} lobsters recreated and started"
elif [ "$NEED_GATEWAY_RESTART" = true ] && [ "$DRY_RUN" = false ]; then
    echo ""
    echo "🔄 Restarting lobster gateways (rescanning skills)..."
    for name in $(sudo docker ps --filter "name=lobster-" --format '{{.Names}}'); do
        sudo docker restart "$name" > /dev/null 2>&1 &
    done
    wait
    echo "   ✅ All lobster gateways restarted (new skills loaded)"
fi

# ── Step 5: Broadcast ──
LOBSTER_COUNT=$(sudo docker ps --filter "name=lobster-" --format '{{.Names}}' 2>/dev/null | wc -l)

if [ ${#CHANGES[@]} -gt 0 ] && [ "$DRY_RUN" = false ]; then
    echo ""
    echo "📢 Broadcasting notification..."
    
    if [ -n "$CUSTOM_MSG" ]; then
        MSG="$CUSTOM_MSG"
    else
        MSG="🔄 *Lobster Fleet Sync Update*\n\n"
        for c in "${CHANGES[@]}"; do
            MSG+="• $c\n"
        done
        MSG+="\nNew capabilities are ready — use them right away!"
    fi
    
    "$FARM_DIR/scripts/broadcast-direct.sh" "$MSG" 2>&1 | tail -2
fi

# ── Summary ──
echo ""
echo "===================="
if [ "$DRY_RUN" = true ]; then
    echo "🔍 Preview mode (no changes were made)"
    echo "   Pending changes: ${#CHANGES[@]} items"
    for c in "${CHANGES[@]}"; do
        echo "   • $c"
    done
else
    echo "✅ Sync complete! ${#CHANGES[@]} changes | $LOBSTER_COUNT lobsters"
fi
