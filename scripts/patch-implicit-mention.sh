#!/bin/bash
# patch-implicit-mention.sh — Disable Slack thread implicit mentions
# 
# Effect: When env var OPENCLAW_THREAD_IMPLICIT_MENTION=false is set,
#         messages in threads without explicit @bot will not trigger LLM calls (zero input tokens)
#
# Use cases:
#   1. After controller OpenClaw upgrade: bash patch-implicit-mention.sh
#   2. During lobster image build: RUN bash patch-implicit-mention.sh in Dockerfile
#   3. In lobster entrypoint: auto-check and apply patch on startup
#
# How it works: Adds a process.env check before implicitMention computation
#   Before: const implicitMention = Boolean(!isDirectMessage && ctx.botUserId && message.thread_ts && ...
#   After:  const implicitMention = (process.env.OPENCLAW_THREAD_IMPLICIT_MENTION !== "false") && Boolean(!isDirectMessage && ctx.botUserId && message.thread_ts && ...

set -euo pipefail

# Auto-detect OpenClaw installation path
OPENCLAW_DIST=""
for candidate in \
    "$HOME/.npm-global/lib/node_modules/openclaw/dist" \
    "$OPENCLAW_DIST" \
    "/home/lobster/.npm-global/lib/node_modules/openclaw/dist" \
    "/usr/local/lib/node_modules/openclaw/dist" \
    "/usr/lib/node_modules/openclaw/dist"; do
    if [ -d "$candidate" ]; then
        OPENCLAW_DIST="$candidate"
        break
    fi
done

if [ -z "$OPENCLAW_DIST" ]; then
    echo "ERROR: OpenClaw dist directory not found"
    exit 1
fi

echo "📁 OpenClaw dist: $OPENCLAW_DIST"

# Pattern to patch (original code)
PATTERN='const implicitMention=Boolean(!isDirectMessage&&ctx.botUserId&&message.thread_ts'
# Also match spaced version
PATTERN_SPACED='const implicitMention = Boolean(!isDirectMessage && ctx.botUserId && message.thread_ts'

# Patch prefix
PATCH_PREFIX='(process.env.OPENCLAW_THREAD_IMPLICIT_MENTION!=="false")&&'
PATCH_PREFIX_SPACED='(process.env.OPENCLAW_THREAD_IMPLICIT_MENTION !== "false") && '

# Already-patched marker
PATCH_MARKER='OPENCLAW_THREAD_IMPLICIT_MENTION'

patched=0
skipped=0
failed=0

for file in $(grep -rl "const implicitMention" "$OPENCLAW_DIST" 2>/dev/null || true); do
    # Skip already patched files
    if grep -q "$PATCH_MARKER" "$file" 2>/dev/null; then
        echo "  SKIP $(basename "$file") (already patched)"
        skipped=$((skipped + 1))
        continue
    fi

    # Check if file contains the target Slack implicit mention pattern
    if grep -q "implicitMention.*isDirectMessage.*thread_ts.*hasSlackThreadParticipation" "$file" 2>/dev/null; then
        # Try minified version
        if grep -q "const implicitMention=Boolean(!isDirectMessage" "$file"; then
            sed -i "s|const implicitMention=Boolean(!isDirectMessage|const implicitMention=(process.env.OPENCLAW_THREAD_IMPLICIT_MENTION!==\"false\")\&\&Boolean(!isDirectMessage|g" "$file"
        # Try spaced version
        elif grep -q "const implicitMention = Boolean(!isDirectMessage" "$file"; then
            sed -i "s|const implicitMention = Boolean(!isDirectMessage|const implicitMention = (process.env.OPENCLAW_THREAD_IMPLICIT_MENTION !== \"false\") \&\& Boolean(!isDirectMessage|g" "$file"
        else
            echo "  WARN $(basename "$file") — pattern not matched, manual check needed"
            failed=$((failed + 1))
            continue
        fi

        # Verify
        if grep -q "$PATCH_MARKER" "$file"; then
            echo "  ✅ $(basename "$file")"
            patched=$((patched + 1))
        else
            echo "  ❌ $(basename "$file") — patch verification failed"
            failed=$((failed + 1))
        fi
    fi
done

echo ""
echo "Done: ✅ patched=$patched  ⏭ skipped=$skipped  ❌ failed=$failed"

if [ $failed -gt 0 ]; then
    exit 1
fi
