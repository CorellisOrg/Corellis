#!/usr/bin/env bash
# search.sh — Parallel multi-keyword search (using Brave API)
# Usage: search.sh "keyword1" "keyword2" "keyword3" ...
# Output: JSON array of search results
# Requires: BRAVE_API_KEY env var

set -euo pipefail

if [[ -z "${BRAVE_API_KEY:-}" ]]; then
  echo "Error: BRAVE_API_KEY not set" >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  echo "Usage: search.sh <keyword1> [keyword2] [keyword3] ..." >&2
  exit 1
fi

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Search all keywords in parallel
PIDS=()
IDX=0
for QUERY in "$@"; do
  (
    ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))")
    curl -s "https://api.search.brave.com/res/v1/web/search?q=${ENCODED}&count=8" \
      -H "Accept: application/json" \
      -H "X-Subscription-Token: ${BRAVE_API_KEY}" \
      --max-time 15 \
      > "${TMPDIR}/result_${IDX}.json" 2>/dev/null || true
  ) &
  PIDS+=($!)
  IDX=$((IDX + 1))
done

# Wait for all searches to complete
for PID in "${PIDS[@]}"; do
  wait "$PID" 2>/dev/null || true
done

# Merge results, extract title+URL+summary, deduplicate
python3 << 'PYEOF'
import json, glob, os

results = []
seen_urls = set()

for f in sorted(glob.glob(os.path.join(os.environ.get("TMPDIR", "/tmp"), "result_*.json"))):
    try:
        with open(f) as fh:
            data = json.load(fh)
        for item in data.get("web", {}).get("results", []):
            url = item.get("url", "")
            if url and url not in seen_urls:
                seen_urls.add(url)
                results.append({
                    "title": item.get("title", ""),
                    "url": url,
                    "description": item.get("description", ""),
                    "age": item.get("age", "")
                })
    except:
        pass

print(json.dumps(results, ensure_ascii=False, indent=2))
PYEOF