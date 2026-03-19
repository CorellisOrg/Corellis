#!/bin/bash
# 🦞 Lobster Farm Log Patrol
# Scans recent logs for errors/warnings across all lobsters
# Usage:
#   ./scripts/log-patrol.sh                # Last 30min, errors only
#   ./scripts/log-patrol.sh --since 1h     # Last 1 hour
#   ./scripts/log-patrol.sh --verbose      # Show all matched lines
#   ./scripts/log-patrol.sh --json         # JSON output

set -euo pipefail

SINCE="30m"
NOTIFY_OWNER=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERBOSE=false
JSON_OUTPUT=false
MAX_LINES=5  # per lobster per pattern

while [[ $# -gt 0 ]]; do
    case $1 in
        --since|-s)  SINCE="$2"; shift 2 ;;
        --verbose|-v) VERBOSE=true; MAX_LINES=20; shift ;;
        --notify-owner|-n) NOTIFY_OWNER=true; shift ;;
        --json|-j)   JSON_OUTPUT=true; shift ;;
        *)           shift ;;
    esac
done

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

# Error patterns to scan (case-insensitive grep)
CRITICAL_PATTERNS="FATAL|OOMKilled|out of memory|SIGKILL|unhandledRejection|Cannot find module"
ERROR_PATTERNS="Error:|ERR!|ECONNREFUSED|ETIMEDOUT|rate.limit|429 Too Many|503 Service|socket hang up|EPERM|EACCES"
WARNING_PATTERNS="WARN|deprecated|retry|timeout|reconnect"

LOBSTERS=$(docker ps --filter 'name=lobster-' --format '{{.Names}}' 2>/dev/null | sort)
TOTAL=$(echo "$LOBSTERS" | wc -l)
CLEAN=0
ISSUES=()
JSON_RESULTS=()

for container in $LOBSTERS; do
    name="${container#lobster-}"
    
    # Get recent logs
    logs=$(docker logs '$container' --since '$SINCE' 2>&1 || echo "")
    
    if [ -z "$logs" ]; then
        CLEAN=$((CLEAN + 1))
        continue
    fi
    
    # Count matches
    critical=$(echo "$logs" | grep -ciE "$CRITICAL_PATTERNS" || true)
    critical=${critical//[^0-9]/}; critical=${critical:-0}
    errors=$(echo "$logs" | grep -ciE "$ERROR_PATTERNS" || true)
    errors=${errors//[^0-9]/}; errors=${errors:-0}
    warnings=$(echo "$logs" | grep -ciE "$WARNING_PATTERNS" || true)
    warnings=${warnings//[^0-9]/}; warnings=${warnings:-0}
    
    if [ "$critical" -gt 0 ] || [ "$errors" -gt 0 ]; then
        level="error"
        if [ "$critical" -gt 0 ]; then
            level="critical"
        fi
        
        summary="${critical} critical, ${errors} errors, ${warnings} warnings"
        ISSUES+=("$name|$level|$summary")
        
        if $VERBOSE && ! $JSON_OUTPUT; then
            echo -e "\n${RED}🔴 $name${NC} ($summary):"
            if [ "$critical" -gt 0 ]; then
                echo -e "  ${RED}Critical:${NC}"
                echo "$logs" | grep -iE "$CRITICAL_PATTERNS" | tail -$MAX_LINES | sed 's/^/    /'
            fi
            if [ "$errors" -gt 0 ]; then
                echo -e "  ${YELLOW}Errors:${NC}"
                echo "$logs" | grep -iE "$ERROR_PATTERNS" | tail -$MAX_LINES | sed 's/^/    /'
            fi
        fi
        
        JSON_RESULTS+=("{\"name\":\"$name\",\"level\":\"$level\",\"critical\":$critical,\"errors\":$errors,\"warnings\":$warnings}")
    elif [ "$warnings" -gt 5 ]; then
        ISSUES+=("$name|warning|$warnings warnings")
        JSON_RESULTS+=("{\"name\":\"$name\",\"level\":\"warning\",\"critical\":0,\"errors\":0,\"warnings\":$warnings}")
        
        if $VERBOSE && ! $JSON_OUTPUT; then
            echo -e "\n${YELLOW}⚠️  $name${NC} ($warnings warnings):"
            echo "$logs" | grep -iE "$WARNING_PATTERNS" | tail -$MAX_LINES | sed 's/^/    /'
        fi
    else
        CLEAN=$((CLEAN + 1))
    fi
done

# Output
if $JSON_OUTPUT; then
    echo "{\"status\":\"$([ ${#ISSUES[@]} -eq 0 ] && echo 'clean' || echo 'issues')\",\"since\":\"$SINCE\",\"total\":$TOTAL,\"clean\":$CLEAN,\"issues\":${#ISSUES[@]},\"timestamp\":\"$(date -u +%FT%TZ)\",\"lobsters\":[$(IFS=,; echo "${JSON_RESULTS[*]}")]}"
else
    echo ""
    if [ ${#ISSUES[@]} -eq 0 ]; then
        echo -e "${GREEN}🦞 All $TOTAL lobsters clean (last $SINCE)${NC}"
    else
        echo -e "${RED}🦞 ${#ISSUES[@]}/$TOTAL lobsters have log issues (last $SINCE):${NC}"
        for issue in "${ISSUES[@]}"; do
            IFS='|' read -r iname ilevel isummary <<< "$issue"
            case $ilevel in
                critical) echo -e "  ${RED}🔴 $iname${NC}: $isummary" ;;
                error)    echo -e "  ${YELLOW}🟡 $iname${NC}: $isummary" ;;
                warning)  echo -e "  ${CYAN}⚠️  $iname${NC}: $isummary" ;;
            esac
        done
    fi
    echo -e "${CYAN}  ($CLEAN clean / $TOTAL total)${NC}"
fi

exit $([ ${#ISSUES[@]} -eq 0 ] && echo 0 || echo 1)

# Notify individual lobster owners if --notify-owner is set
if $NOTIFY_OWNER && [ ${#ISSUES[@]} -gt 0 ]; then
    for issue in "${ISSUES[@]}"; do
        IFS='|' read -r iname ilevel isummary <<< "$issue"
        # Only notify on errors/critical, not warnings
        if [ "$ilevel" = "critical" ] || [ "$ilevel" = "error" ]; then
            MSG="🦞 Log patrol alert: your lobster detected ${isummary}. Please check if action is needed. Contact admin if you need help."
            "$SCRIPT_DIR/notify-lobster-owner.sh" "$iname" "$MSG" 2>/dev/null || true
        fi
    done
fi
