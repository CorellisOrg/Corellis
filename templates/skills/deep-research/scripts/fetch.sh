#!/usr/bin/env bash
# fetch.sh — Batch fetch URL content
# Usage: fetch.sh <url1> [url2] [url3] ...
# Output: JSON array of {url, title, content}
# Extract up to 6000 characters per URL

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: fetch.sh <url1> [url2] ..." >&2
  exit 1
fi

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Parallel fetching
PIDS=()
IDX=0
for URL in "$@"; do
  (
    # Use readability-like extraction: first curl to get HTML, then python to strip tags
    curl -sL --max-time 15 -A "Mozilla/5.0" "$URL" 2>/dev/null | \
    python3 -c "
import sys, re, json

html = sys.stdin.read()[:200000]
# Remove scripts, styles
html = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL|re.IGNORECASE)
html = re.sub(r'<style[^>]*>.*?</style>', '', html, flags=re.DOTALL|re.IGNORECASE)
# Extract title
title_match = re.search(r'<title[^>]*>(.*?)</title>', html, re.IGNORECASE|re.DOTALL)
title = title_match.group(1).strip() if title_match else ''
# Strip tags
text = re.sub(r'<[^>]+>', ' ', html)
text = re.sub(r'\s+', ' ', text).strip()[:6000]

json.dump({'url': '$URL', 'title': title, 'content': text}, sys.stdout, ensure_ascii=False)
" > "${TMPDIR}/fetch_${IDX}.json" 2>/dev/null || echo '{"url":"'$URL'","title":"","content":"[fetch failed]"}' > "${TMPDIR}/fetch_${IDX}.json"
  ) &
  PIDS+=($!)
  IDX=$((IDX + 1))
done

for PID in "${PIDS[@]}"; do
  wait "$PID" 2>/dev/null || true
done

# Merge
python3 << 'PYEOF'
import json, glob, os

results = []
for f in sorted(glob.glob(os.path.join(os.environ.get("TMPDIR", "/tmp"), "fetch_*.json"))):
    try:
        with open(f) as fh:
            results.append(json.load(fh))
    except:
        pass

print(json.dumps(results, ensure_ascii=False, indent=2))
PYEOF