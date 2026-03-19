#!/bin/bash
# patch-all.sh — Unified entry point, runs all OpenClaw patches in one call
#
# Use cases:
#   1. After controller OpenClaw upgrade: bash scripts/patch-all.sh
#   2. During lobster image build: RUN bash patch-all.sh in Dockerfile
#   3. In lobster entrypoint: run on startup
#
# All patch scripts are idempotent — re-running will automatically SKIP already-patched files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🔧 Running all OpenClaw patches..."
echo ""

echo "=== 1/2: Implicit Mention Patch ==="
bash "$SCRIPT_DIR/patch-implicit-mention.sh"
echo ""

echo "=== 2/2: CC Session Patch ==="
bash "$SCRIPT_DIR/patch-cc-session.sh"
echo ""

echo "🎉 All patches applied."
