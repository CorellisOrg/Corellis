#!/bin/bash
# 🦞 Lobster Farm Health Check
# Usage:
#   ./scripts/health-check.sh              # Check all, report issues
#   ./scripts/health-check.sh --verbose    # Show all lobsters
#   ./scripts/health-check.sh --auto-fix   # Auto-restart unhealthy ones
#   ./scripts/health-check.sh --json       # Output JSON (for cron/monitoring)

set -euo pipefail

FARM_DIR="${LOBSTER_FARM_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
VERBOSE=false
AUTO_FIX=false
JSON_OUTPUT=false
NOTIFY_SLACK=false

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)   VERBOSE=true; shift ;;
        --auto-fix|-f)  AUTO_FIX=true; shift ;;
        --json|-j)      JSON_OUTPUT=true; shift ;;
        --notify|-n)    NOTIFY_SLACK=true; shift ;;
        *)              shift ;;
    esac
done

# Colors (skip in JSON mode)
if $JSON_OUTPUT; then
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
fi

HEALTHY=0
UNHEALTHY=0
RESTARTED=0
ISSUES=()
RESULTS=()

# Get all lobster containers
LOBSTERS=$(docker ps -a --filter 'name=lobster-' --format '{{.Names}}' 2>/dev/null | sort)

if [ -z "$LOBSTERS" ]; then
    if $JSON_OUTPUT; then
        echo '{"status":"error","message":"No lobster containers found","timestamp":"'$(date -u +%FT%TZ)'"}'
    else
        echo -e "${YELLOW}⚠️  No lobster containers found${NC}"
    fi
    exit 1
fi

TOTAL=$(echo "$LOBSTERS" | wc -l)

for container in $LOBSTERS; do
    name="${container#lobster-}"
    status="healthy"
    details=""

    # Check 1: Container running?
    state=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "missing")
    if [ "$state" != "running" ]; then
        status="down"
        details="container $state"
        UNHEALTHY=$((UNHEALTHY + 1))
        ISSUES+=("❌ $name: container $state")

        if $AUTO_FIX; then
            docker start "$container" &>/dev/null && {
                RESTARTED=$((RESTARTED + 1))
                details="$details → restarted"
                ISSUES[-1]="🔄 $name: was $state → restarted"
            }
        fi

        RESULTS+=("{\"name\":\"$name\",\"status\":\"$status\",\"details\":\"$details\"}")
        continue
    fi

    # Check 2: HTTP response via host-mapped port (more reliable than docker exec)
    host_port=$(docker inspect -f '{{(index (index .NetworkSettings.Ports "18789/tcp") 0).HostPort}}' "$container" 2>/dev/null) || true
    if [ -n "$host_port" ]; then
        http_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://localhost:$host_port/" 2>/dev/null) || true
    else
        http_code=$(docker exec "$container" curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:18789/ 2>/dev/null) || true
    fi
    http_code=${http_code:-000}
    if [ "$http_code" != "200" ]; then
        status="unhealthy"
        details="HTTP $http_code"
        UNHEALTHY=$((UNHEALTHY + 1))
        ISSUES+=("⚠️  $name: HTTP $http_code (gateway not responding)")

        if $AUTO_FIX; then
            # Skip restart if container started < 3 min ago (gateway needs startup time)
            started_at=$(docker inspect -f '{{.State.StartedAt}}' "$container" 2>/dev/null)
            started_ts=$(date -d "$started_at" +%s 2>/dev/null || echo 0)
            now_ts=$(date +%s)
            uptime_secs=$(( now_ts - started_ts ))
            if [ "$uptime_secs" -lt 1800 ]; then
                details="$details (starting up, ${uptime_secs}s ago)"
                ISSUES[-1]="⏳ $name: HTTP $http_code (starting up, ${uptime_secs}s uptime — skipping restart)"
            else
                docker restart "$container" &>/dev/null && {
                    RESTARTED=$((RESTARTED + 1))
                    details="$details → restarted"
                    ISSUES[-1]="🔄 $name: HTTP $http_code → restarted"
                }
            fi
        fi

        RESULTS+=("{\"name\":\"$name\",\"status\":\"$status\",\"details\":\"$details\"}")
        continue
    fi

    # Check 3: noVNC desktop health (xfwm4 + VNC)
    vnc_ok=true
    xfwm_running=$(docker exec "$container" ps aux 2>/dev/null | grep -c '[x]fwm4' || true)
    vnc_running=$(docker exec "$container" ps aux 2>/dev/null | grep -c '[X]tigervnc' || true)
    websockify_count=$(docker exec "$container" ps aux 2>/dev/null | grep -c '[w]ebsockify' || true)
    xfwm_running=${xfwm_running:-0}; vnc_running=${vnc_running:-0}; websockify_count=${websockify_count:-0}

    if [ "${vnc_running:-0}" -gt 0 ] && [ "${xfwm_running:-0}" -eq 0 ]; then
        vnc_ok=false
        if [ "$status" = "healthy" ]; then status="warning"; fi
        details="${details:+$details, }xfwm4 not running (black screen)"
        ISSUES+=("⚠️  $name: xfwm4 not running — noVNC shows black screen")

        if $AUTO_FIX; then
            # Fix common cause: .config owned by root
            docker exec "$container" chown lobster:lobster /home/lobster/.config 2>/dev/null || true
            docker restart "$container" &>/dev/null && {
                RESTARTED=$((RESTARTED + 1))
                details="${details} → restarted"
                ISSUES[-1]="🔄 $name: xfwm4 dead → fixed permissions + restarted"
            }
        fi
    fi

    if [ "${websockify_count:-0}" -gt 5 ]; then
        if [ "$status" = "healthy" ]; then status="warning"; fi
        details="${details:+$details, }websockify leak (${websockify_count} processes)"
        ISSUES+=("⚠️  $name: websockify leak — ${websockify_count} processes")

        if $AUTO_FIX; then
            docker restart "$container" &>/dev/null && {
                RESTARTED=$((RESTARTED + 1))
                details="${details} → restarted"
                ISSUES[-1]="🔄 $name: websockify leak (${websockify_count}) → restarted"
            }
        fi
    fi

    # Check 4: Memory usage
    mem_usage=$(docker stats --no-stream --format '{{.MemPerc}}' "$container" 2>/dev/null | tr -d '%' || echo "0")
    mem_int=${mem_usage%.*}
    if [ "${mem_int:-0}" -gt 90 ]; then
        status="warning"
        details="memory ${mem_usage}%"
        ISSUES+=("⚠️  $name: high memory (${mem_usage}%)")
    fi

    # Check 5: Uptime (recently restarted = suspicious)
    started=$(docker inspect -f '{{.State.StartedAt}}' "$container" 2>/dev/null)
    uptime_sec=$(( $(date +%s) - $(date -d "$started" +%s 2>/dev/null || echo $(date +%s)) ))
    if [ "$uptime_sec" -lt 300 ] && [ "$uptime_sec" -gt 0 ]; then
        if [ "$status" = "healthy" ]; then
            status="warning"
        fi
        details="${details:+$details, }uptime ${uptime_sec}s (recently restarted)"
        ISSUES+=("⚠️  $name: recently restarted (${uptime_sec}s ago)")
    fi

    if [ "$status" = "healthy" ]; then
        HEALTHY=$((HEALTHY + 1))
        details="OK"
    fi

    RESULTS+=("{\"name\":\"$name\",\"status\":\"$status\",\"details\":\"$details\"}")

    if $VERBOSE && ! $JSON_OUTPUT; then
        case $status in
            healthy) echo -e "  ${GREEN}✅ $name${NC}: $details" ;;
            warning) echo -e "  ${YELLOW}⚠️  $name${NC}: $details" ;;
            *)       echo -e "  ${RED}❌ $name${NC}: $details" ;;
        esac
    fi
done

# Output
if $JSON_OUTPUT; then
    echo "{\"status\":\"$([ $UNHEALTHY -eq 0 ] && echo 'ok' || echo 'issues')\",\"total\":$TOTAL,\"healthy\":$HEALTHY,\"unhealthy\":$UNHEALTHY,\"restarted\":$RESTARTED,\"timestamp\":\"$(date -u +%FT%TZ)\",\"lobsters\":[$(IFS=,; echo "${RESULTS[*]}")]}"
else
    echo ""
    if [ $UNHEALTHY -eq 0 ]; then
        echo -e "${GREEN}🦞 All $TOTAL lobsters healthy!${NC}"
    else
        echo -e "${RED}🦞 $UNHEALTHY/$TOTAL lobsters have issues:${NC}"
        for issue in "${ISSUES[@]}"; do
            echo -e "  $issue"
        done
        if $AUTO_FIX && [ $RESTARTED -gt 0 ]; then
            echo -e "\n${CYAN}🔄 Auto-restarted $RESTARTED lobsters. Re-check in 90s.${NC}"
        fi
    fi
    echo -e "${CYAN}  ($HEALTHY healthy / $TOTAL total)${NC}"
fi

# Slack notification for issues
if $NOTIFY_SLACK && [ $UNHEALTHY -gt 0 ]; then
    # Read the master bot token from openclaw.json
    BOT_TOKEN=$(python3 -c "import json; print(json.load(open('$HOME/.openclaw/openclaw.json'))['channels']['slack']['botToken'])" 2>/dev/null || true)
    OWNER_ID=$(python3 -c "import json; c=json.load(open('$HOME/.openclaw/openclaw.json')); print(c['channels']['slack'].get('owner',''))" 2>/dev/null || true)

    if [ -n "$BOT_TOKEN" ] && [ -n "$OWNER_ID" ]; then
        MSG="🚨 *Lobster Health Alert*\n$UNHEALTHY/$TOTAL lobsters unhealthy"
        for issue in "${ISSUES[@]}"; do
            MSG="$MSG\n$issue"
        done
        if [ $RESTARTED -gt 0 ]; then
            MSG="$MSG\n\n🔄 Auto-restarted $RESTARTED lobsters"
        fi

        curl -s -X POST https://slack.com/api/chat.postMessage \
            -H "Authorization: Bearer $BOT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"channel\":\"$OWNER_ID\",\"text\":\"$MSG\"}" &>/dev/null || true
    fi
fi

exit $([ $UNHEALTHY -eq 0 ] && echo 0 || echo 1)
