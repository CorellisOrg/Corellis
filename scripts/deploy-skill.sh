#!/usr/bin/env bash
# =============================================================================
# deploy-skill.sh — Deploy an approved skill to all lobsters
# =============================================================================
#
# Copies a reviewed skill from skill-submissions/ to company-skills/,
# registers it in manifest.json, and syncs to all running lobsters.
#
# Usage:
#   bash scripts/deploy-skill.sh <skill-name> [--tier base|restricted]
#
# Example:
#   bash scripts/deploy-skill.sh my-cool-skill
#   bash scripts/deploy-skill.sh finance-tool --tier restricted
#
# Prerequisites:
#   - Skill must pass review: bash scripts/review-skill-submission.sh <name>
#   - company-skills/ directory must exist
#   - manifest.json must exist in company-skills/
#
# =============================================================================

set -euo pipefail

LOG_PREFIX="[skill-deploy]"
SUBMISSIONS_DIR="${SKILL_SUBMISSIONS_DIR:-/shared/skill-submissions}"
SKILLS_DIR="${COMPANY_SKILLS_DIR:-company-skills}"
MANIFEST="$SKILLS_DIR/manifest.json"

# Parse arguments
SKILL_NAME="${1:-}"
TIER="base"

shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --tier) TIER="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$SKILL_NAME" ]; then
  echo "Usage: $0 <skill-name> [--tier base|restricted]"
  exit 1
fi

# Validate tier
if [[ "$TIER" != "base" && "$TIER" != "restricted" && "$TIER" != "controller" ]]; then
  echo "$LOG_PREFIX ❌ Invalid tier: $TIER (must be base, restricted, or controller)"
  exit 1
fi

SOURCE_DIR="$SUBMISSIONS_DIR/$SKILL_NAME"
TARGET_DIR="$SKILLS_DIR/$SKILL_NAME"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

if [ ! -d "$SOURCE_DIR" ]; then
  echo "$LOG_PREFIX ❌ Submission not found: $SOURCE_DIR"
  exit 1
fi

if [ ! -f "$SOURCE_DIR/SKILL.md" ]; then
  echo "$LOG_PREFIX ❌ No SKILL.md in submission. Run review first."
  exit 1
fi

if [ ! -f "$MANIFEST" ]; then
  echo "$LOG_PREFIX ❌ Manifest not found: $MANIFEST"
  echo "$LOG_PREFIX Create it first: echo '{\"skills\":{}}' > $MANIFEST"
  exit 1
fi

if [ -d "$TARGET_DIR" ]; then
  echo "$LOG_PREFIX ⚠️  Skill '$SKILL_NAME' already exists in $SKILLS_DIR."
  echo "$LOG_PREFIX Updating (overwrite)..."
  rm -rf "$TARGET_DIR"
fi

# ---------------------------------------------------------------------------
# Deploy
# ---------------------------------------------------------------------------

echo "$LOG_PREFIX Deploying '$SKILL_NAME' (tier: $TIER)..."

# 1. Copy skill to company-skills/
cp -r "$SOURCE_DIR" "$TARGET_DIR"
echo "$LOG_PREFIX ✅ Copied to $TARGET_DIR"

# 2. Extract description from SKILL.md
DESCRIPTION=$(grep -m1 '^description:' "$TARGET_DIR/SKILL.md" 2>/dev/null | sed 's/^description: *//' | tr -d '"' || echo "No description")

# 3. Update manifest.json
# Uses a temp file to avoid corruption
TMP_MANIFEST=$(mktemp)
if command -v jq &>/dev/null; then
  jq --arg name "$SKILL_NAME" \
     --arg tier "$TIER" \
     --arg desc "$DESCRIPTION" \
     --arg path "$SKILL_NAME/SKILL.md" \
     '.skills[$name] = {"tier": $tier, "description": $desc, "path": $path}' \
     "$MANIFEST" > "$TMP_MANIFEST" && mv "$TMP_MANIFEST" "$MANIFEST"
  echo "$LOG_PREFIX ✅ Updated manifest.json"
else
  echo "$LOG_PREFIX ⚠️  jq not found — please update manifest.json manually"
  rm -f "$TMP_MANIFEST"
fi

# 4. Mark as seen in poll state
STATE_FILE="state/skill-submissions-seen.json"
if [ -f "$STATE_FILE" ] && command -v jq &>/dev/null; then
  TMP_STATE=$(mktemp)
  jq --arg name "$SKILL_NAME" '.seen += [$name] | .seen |= unique' \
     "$STATE_FILE" > "$TMP_STATE" && mv "$TMP_STATE" "$STATE_FILE"
fi

# 5. Sync to running lobsters via docker cp
echo "$LOG_PREFIX Syncing to running lobsters..."
LOBSTERS=$(docker ps --filter "name=lobster-" --format '{{.Names}}' 2>/dev/null || true)

if [ -z "$LOBSTERS" ]; then
  echo "$LOG_PREFIX No running lobsters found. They'll pick it up on next restart."
else
  SYNCED=0
  for LOBSTER in $LOBSTERS; do
    CONTAINER_SKILLS_PATH="/home/lobster/.openclaw/workspace/company-skills"
    if docker cp "$TARGET_DIR" "$LOBSTER:$CONTAINER_SKILLS_PATH/$SKILL_NAME" 2>/dev/null; then
      ((SYNCED++))
    else
      echo "$LOG_PREFIX ⚠️  Failed to sync to $LOBSTER"
    fi
  done
  echo "$LOG_PREFIX ✅ Synced to $SYNCED lobster(s)"
fi

echo ""
echo "$LOG_PREFIX ✅ Deployment complete!"
echo "  Skill:    $SKILL_NAME"
echo "  Tier:     $TIER"
echo "  Location: $TARGET_DIR"
echo "  Manifest: $MANIFEST"
