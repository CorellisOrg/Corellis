#!/usr/bin/env bash
# apply-fleet-config.sh — Apply fleet-config.json patch to all lobsters
# Directly modifies configs/<name>/openclaw.json on host + SIGUSR1 hot reload
# Usage: ./apply-fleet-config.sh [lobster_name...]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FARM_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$FARM_DIR/fleet-config.json"
CONFIGS_DIR="$FARM_DIR/configs"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ fleet-config.json not found at $CONFIG_FILE"
  exit 1
fi

PATCH=$(cat "$CONFIG_FILE")

# Get target lobster list
if [[ $# -gt 0 ]]; then
  LOBSTERS=("$@")
else
  mapfile -t LOBSTERS < <(docker ps --format '{{.Names}}' | grep '^lobster-' | sed 's/^lobster-//' | sort)
fi

if [[ ${#LOBSTERS[@]} -eq 0 ]]; then
  echo "⚠️ No running lobster containers found"
  exit 0
fi

echo "📦 Applying fleet config to ${#LOBSTERS[@]} lobsters..."
echo ""

SUCCESS=0
FAIL=0

for name in "${LOBSTERS[@]}"; do
  container="lobster-$name"
  config_file="$CONFIGS_DIR/$name/openclaw.json"
  printf "  %-25s" "$name"

  if [[ ! -f "$config_file" ]]; then
    echo "❌ config not found"
    ((FAIL++))
    continue
  fi

  # Deep merge on host using node
  if node -e "
    const fs = require('fs');
    const patch = JSON.parse(process.argv[1]);
    const cfg = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
    function merge(t, s) {
      for (const k of Object.keys(s)) {
        if (s[k] && typeof s[k]==='object' && !Array.isArray(s[k])
            && t[k] && typeof t[k]==='object' && !Array.isArray(t[k])) {
          merge(t[k], s[k]);
        } else { t[k] = s[k]; }
      }
    }
    merge(cfg, patch);
    fs.writeFileSync(process.argv[2], JSON.stringify(cfg, null, 2) + '\n');
  " "$PATCH" "$config_file" 2>/dev/null; then
    # SIGUSR1 hot reload
    if docker exec "$container" kill -USR1 1 2>/dev/null; then
      echo "✅"
    else
      echo "⚠️ patched, reload failed"
    fi
    ((SUCCESS++))
  else
    echo "❌ merge failed"
    ((FAIL++))
  fi
done

echo ""
echo "Done: $SUCCESS ✅, $FAIL ❌ (total ${#LOBSTERS[@]})"
