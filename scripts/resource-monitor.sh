#!/bin/bash
# 🦞 Lobster Farm Resource Monitor
# Reports CPU/memory usage, flags high consumers
# Usage:
#   ./scripts/resource-monitor.sh              # Show top consumers
#   ./scripts/resource-monitor.sh --all        # Show all lobsters
#   ./scripts/resource-monitor.sh --json       # JSON output
#   ./scripts/resource-monitor.sh --threshold 80  # Alert above 80% mem

set -euo pipefail

SHOW_ALL=false
JSON_OUTPUT=false
MEM_THRESHOLD=85
CPU_THRESHOLD=100  # percent of one core

while [[ $# -gt 0 ]]; do
    case $1 in
        --all|-a)        SHOW_ALL=true; shift ;;
        --json|-j)       JSON_OUTPUT=true; shift ;;
        --threshold|-t)  MEM_THRESHOLD="$2"; shift 2 ;;
        *)               shift ;;
    esac
done

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

# Get stats for all lobsters in one call
STATS=$(docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.PIDs}}' $(docker ps --filter 'name=lobster-' --format '{{.Names}}' | tr '\n' ' ') 2>/dev/null | sort)

TOTAL=0
ALERTS=()
JSON_RESULTS=()

# Host totals
HOST_MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
HOST_MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
HOST_MEM_PCT=$((HOST_MEM_USED * 100 / HOST_MEM_TOTAL))
HOST_CPU=$(nproc)
LOAD=$(cat /proc/loadavg | cut -d' ' -f1-3)

while IFS='|' read -r name cpu mem_usage mem_pct pids; do
    [ -z "$name" ] && continue
    TOTAL=$((TOTAL + 1))
    
    short="${name#lobster-}"
    cpu_num=${cpu//%/}
    mem_num=${mem_pct//%/}
    cpu_int=${cpu_num%.*}
    mem_int=${mem_num%.*}
    
    level="ok"
    if [ "${mem_int:-0}" -ge "$MEM_THRESHOLD" ]; then
        level="high-mem"
        ALERTS+=("⚠️  $short: memory ${mem_pct} ($mem_usage)")
    fi
    if [ "${cpu_int:-0}" -ge "$CPU_THRESHOLD" ]; then
        level="high-cpu"
        ALERTS+=("⚠️  $short: CPU ${cpu}")
    fi
    
    if $SHOW_ALL && ! $JSON_OUTPUT; then
        if [ "$level" != "ok" ]; then
            echo -e "  ${YELLOW}⚠️  $short${NC}\tCPU: $cpu\tMem: $mem_pct ($mem_usage)\tPIDs: $pids"
        else
            echo -e "  ${GREEN}✅ $short${NC}\tCPU: $cpu\tMem: $mem_pct ($mem_usage)\tPIDs: $pids"
        fi
    fi
    
    JSON_RESULTS+=("{\"name\":\"$short\",\"cpu\":\"$cpu\",\"mem_pct\":\"$mem_pct\",\"mem_usage\":\"$mem_usage\",\"pids\":$pids,\"level\":\"$level\"}")
done <<< "$STATS"

if $JSON_OUTPUT; then
    echo "{\"total\":$TOTAL,\"alerts\":${#ALERTS[@]},\"host\":{\"mem_total_mb\":$HOST_MEM_TOTAL,\"mem_used_mb\":$HOST_MEM_USED,\"mem_pct\":$HOST_MEM_PCT,\"cpus\":$HOST_CPU,\"load\":\"$LOAD\"},\"timestamp\":\"$(date -u +%FT%TZ)\",\"lobsters\":[$(IFS=,; echo "${JSON_RESULTS[*]}")]}"
else
    echo ""
    echo -e "${CYAN}🖥️  Host: ${HOST_MEM_USED}MB / ${HOST_MEM_TOTAL}MB RAM (${HOST_MEM_PCT}%) | ${HOST_CPU} CPUs | Load: ${LOAD}${NC}"
    echo -e "${CYAN}🦞 $TOTAL lobsters | Threshold: ${MEM_THRESHOLD}% mem, ${CPU_THRESHOLD}% CPU${NC}"
    echo ""
    
    if [ ${#ALERTS[@]} -eq 0 ]; then
        echo -e "${GREEN}All lobsters within resource limits.${NC}"
    else
        echo -e "${YELLOW}${#ALERTS[@]} lobster(s) above threshold:${NC}"
        for a in "${ALERTS[@]}"; do echo "  $a"; done
    fi
fi
