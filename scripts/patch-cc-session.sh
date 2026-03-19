#!/bin/bash
# patch-cc-session.sh — Allow ACP sessions with mode="session" under Slack
#
# Problem: mode="session" requires thread=true, but Slack has no SessionBindingAdapter,
#          so Slack users cannot create persistent ACP sessions (CC creates a new session every time)
#
# Effect: Removes the hard requirement of thread=true for mode="session"
#         After patching, lobsters can use sessions_spawn(runtime="acp", mode="session") to create persistent CC sessions,
#         then use sessions_send to send follow-up messages reusing the same CC session
#
# Use cases:
#   1. After controller OpenClaw upgrade: bash patch-cc-session.sh
#   2. During lobster image build: RUN bash patch-cc-session.sh in Dockerfile
#   3. In lobster entrypoint: auto-check and apply patch on startup
#
# How it works: Comments out the thread=true check for mode="session"
#   Before: if (spawnMode === "session" && !requestThreadBinding) return { status: "error", error: "mode=\"session\" requires thread=true ..." }
#   After:  if (false && spawnMode === "session" && !requestThreadBinding) return { ... }  // patched: allow session without thread

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

# Pattern to patch (exact match for ACP + subagent locations)
PATTERN='if (spawnMode === "session" && !requestThreadBinding) return {'
PATCH_MARKER='PATCHED_CC_SESSION'

patched=0
skipped=0
failed=0

# Search for files containing this pattern
for file in $(grep -rl 'spawnMode === "session" && !requestThreadBinding' "$OPENCLAW_DIST" --include="*.js" 2>/dev/null || true); do
    basename_f=$(basename "$file")

    # Skip already patched files
    if grep -q "$PATCH_MARKER" "$file" 2>/dev/null; then
        echo "  SKIP $basename_f (already patched)"
        skipped=$((skipped + 1))
        continue
    fi

    # Backup
    cp "$file" "$file.bak.cc-session" 2>/dev/null || true

    # Apply patch: prepend false && to the condition so it never triggers
    # Also add a comment marker for detection
    if sed -i \
        's/if (spawnMode === "session" \&\& !requestThreadBinding) return {/if (false \&\& spawnMode === "session" \&\& !requestThreadBinding) return { \/\/ PATCHED_CC_SESSION/g' \
        "$file" 2>/dev/null; then
        # Verify patch succeeded
        if grep -q "$PATCH_MARKER" "$file" 2>/dev/null; then
            count=$(grep -c "$PATCH_MARKER" "$file")
            echo "  ✅ $basename_f (patched $count locations)"
            patched=$((patched + 1))
        else
            echo "  ❌ $basename_f (sed ran but pattern not found)"
            # Restore backup
            cp "$file.bak.cc-session" "$file" 2>/dev/null || true
            failed=$((failed + 1))
        fi
    else
        echo "  ❌ $basename_f (sed failed)"
        failed=$((failed + 1))
    fi
done

if [ $patched -eq 0 ] && [ $skipped -eq 0 ]; then
    echo "⚠️  No files matched the pattern. OpenClaw version may have changed."
    echo "   Search for: spawnMode === \"session\" && !requestThreadBinding"
    exit 1
fi

echo ""
echo "=== CC Session Patch Complete ==="
echo "✅ Patched: $patched"
echo "⏭️  Skipped: $skipped"
echo "❌ Failed:  $failed"
