#!/bin/bash
# rolling-upgrade.sh — Lobster rolling upgrade script
# Automatically upgrades all lobster containers in batches with health checks and auto-rollback
#
# Usage:
#   ./scripts/rolling-upgrade.sh                    # Upgrade all lobsters
#   ./scripts/rolling-upgrade.sh --canary alice     # Specify canary lobster
#   ./scripts/rolling-upgrade.sh --batch-size 5     # 5 per batch
#   ./scripts/rolling-upgrade.sh --dry-run          # Preview without executing
#   ./scripts/rolling-upgrade.sh --skip-canary      # Skip canary phase

set -euo pipefail

FARM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="/tmp/rolling-upgrade-$(date +%Y%m%d-%H%M%S).log"
STATE_FILE="/tmp/rolling-upgrade-state.json"

CANARY=""
BATCH_SIZE=3
HEALTH_WAIT=90
HEALTH_RETRIES=3
DRY_RUN=false
SKIP_CANARY=false

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m""

log() { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()  { log "${GREEN}✅ $*${NC}"; }
warn(){ log "${YELLOW}⚠️  $*${NC}"; }
fail(){ log "${RED}❌ $*${NC}"; }

while [[ $# -gt 0 ]]; do
    case $1 in
        --canary)      CANARY="$2"; shift 2 ;;
        --batch-size)  BATCH_SIZE="$2"; shift 2 ;;
        --dry-run)     DRY_RUN=true; shift ;;
        --skip-canary) SKIP_CANARY=true; shift ;;
        --help|-h)     echo "Usage: $0 [--canary NAME] [--batch-size N] [--dry-run] [--skip-canary]"; exit 0 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

get_lobsters() {
    docker ps --filter 'name=lobster-' --format '{{.Names}}' | sed 's/lobster-//' | sort
}

check_health() {
    local name="$1" container="lobster-${1}"
    for i in $(seq 1 $HEALTH_RETRIES); do
        local status
        status=$(docker inspect '$container' --format '{{.State.Status}}' 2>/dev/null || echo "missing")
        if [[ "$status" != "running" ]]; then
            [[ $i -lt $HEALTH_RETRIES ]] && sleep 10 && continue
            return 1
        fi
        local http_code
        http_code=$(docker exec '$container' curl -s -o /dev/null -w '%{http_code}' http://localhost:18789/ 2>/dev/null || echo "000")
        if [[ "$http_code" == "200" ]]; then
            return 0
        fi
        [[ $i -lt $HEALTH_RETRIES ]] && sleep 10
    done
    return 1
}

upgrade_one() {
    local name="$1" container="lobster-${1}"
    log "🔄 Upgrading ${name}..."
    if $DRY_RUN; then
        log "  [DRY RUN] would recreate $container"
        return 0
    fi
    cd "$FARM_DIR"
    docker compose up -d --force-recreate '$container' >> "$LOG_FILE" 2>&1
    log "  ⏳ Waiting ${HEALTH_WAIT}s for startup..."
    sleep "$HEALTH_WAIT"
    if check_health "$name"; then
        ok "${name} upgrade succeeded ✓"
        return 0
    else
        fail "${name} health check failed!"
        return 1
    fi
}

rollback_one() {
    local name="$1" container="lobster-${1}"
    warn "Rolling back ${name}..."
    cd "$FARM_DIR"
    docker compose restart '$container' >> "$LOG_FILE" 2>&1 || true
}

save_state() {
    local phase="$1"; shift
    echo "{\"phase\":\"$phase\",\"completed\":[$(printf '"%s",' "$@" | sed 's/,$//')],\"timestamp\":\"$(date -Iseconds)\"}" > "$STATE_FILE"
}

main() {
    log "🦞 Lobster rolling upgrade started"
    log "📝 Log: $LOG_FILE"
    echo ""

    local -a all_lobsters
    mapfile -t all_lobsters < <(get_lobsters)
    local total=${#all_lobsters[@]}

    if [[ $total -eq 0 ]]; then
        fail "No running lobster containers found"; exit 1
    fi

    log "📊 Total: ${total} lobsters, batch size: ${BATCH_SIZE}"
    $DRY_RUN && warn "DRY RUN mode — no changes will be made"
    echo ""

    # Phase 1: Canary
    if ! $SKIP_CANARY; then
        [[ -z "$CANARY" ]] && CANARY="${all_lobsters[0]}"
        log "━━━ Phase 1: Canary upgrade (${CANARY}) ━━━"
        if upgrade_one "$CANARY"; then
            ok "Canary ${CANARY} passed ✓"
        else
            fail "Canary ${CANARY} failed! Upgrade aborted."
            rollback_one "$CANARY"
            fail "Rolled back ${CANARY}. Check logs: $LOG_FILE"
            exit 1
        fi
        echo ""
        save_state "canary_done" "$CANARY"
    fi

    # Phase 2: Batch
    log "━━━ Phase 2: Batch upgrade ━━━"
    local -a remaining=() completed=() failed=()
    for l in "${all_lobsters[@]}"; do
        [[ "$l" == "$CANARY" ]] && continue
        remaining+=("$l")
    done

    local batch_num=0
    for ((i=0; i<${#remaining[@]}; i+=BATCH_SIZE)); do
        batch_num=$((batch_num + 1))
        local -a batch=("${remaining[@]:i:BATCH_SIZE}")
        log "── Batch ${batch_num}: ${batch[*]} ──"

        local batch_ok=true
        for name in "${batch[@]}"; do
            if upgrade_one "$name"; then
                completed+=("$name")
            else
                failed+=("$name")
                batch_ok=false
                rollback_one "$name"
                break
            fi
        done

        if ! $batch_ok; then
            warn "Batch ${batch_num} had failures, upgrade aborted."
            warn "Completed: ${completed[*]:-none}"
            warn "Failed: ${failed[*]}"
            save_state "partial" "${completed[@]}"
            exit 1
        fi
        save_state "batch_${batch_num}" "${completed[@]}"
        echo ""
    done

    # Summary
    echo ""
    log "━━━ Upgrade complete ━━━"
    local success_count=${#completed[@]}
    $SKIP_CANARY || success_count=$((success_count + 1))
    ok "Succeeded: ${success_count}/${total}"
    [[ ${#failed[@]} -gt 0 ]] && fail "Failed: ${failed[*]}"
    log "📝 Full log: $LOG_FILE"
    rm -f "$STATE_FILE"
}

main "$@"
