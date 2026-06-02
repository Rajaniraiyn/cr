#!/usr/bin/env bash
# Copy cr_api sources into the Chromium tree and generate the GN build.
# Usage: setup_build.sh <chromium_src_dir> [depot_tools_dir]
set -euo pipefail

SRC="${1:?chromium src dir required}"
DEPOT_TOOLS="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
OUT="$SRC/out/Minimal"

if [ -n "$DEPOT_TOOLS" ]; then
  export PATH="$DEPOT_TOOLS:$PATH"
fi

# ── Copy our sources into the Chromium tree ──────────────────────────────────
echo "=== Installing cr_api sources ==="
mkdir -p "$SRC/cr_api/src" "$SRC/cr_api/include"

cp -r "$REPO_ROOT/src/"*    "$SRC/cr_api/src/"
cp -r "$REPO_ROOT/include/"* "$SRC/cr_api/include/"

# Wire our BUILD.gn into a top-level wrapper so `gn gen` picks it up.
# We add a minimal BUILD.gn at //cr_api/BUILD.gn.
cat > "$SRC/cr_api/BUILD.gn" <<'EOF'
import("//cr_api/src/BUILD.gn")
EOF

# ── Run gclient hooks (generates clang toolchain etc.) ──────────────────────
echo "=== Running gclient hooks ==="
(cd "$(dirname "$SRC")" && gclient runhooks)

# ── Generate the build ───────────────────────────────────────────────────────
echo "=== Running gn gen ==="
mkdir -p "$OUT"

# Merge minimal.gni with any ccache wrapper
CCACHE_BIN="$(command -v ccache 2>/dev/null || true)"
EXTRA_ARGS=""
if [ -n "$CCACHE_BIN" ]; then
  EXTRA_ARGS='cc_wrapper="ccache"'
fi

# Build the args string from our .gni file (strip comments/blanks)
GN_ARGS="$(grep -v '^\s*#' "$REPO_ROOT/gn_args/minimal.gni" \
           | grep -v '^\s*$' \
           | tr '\n' ' ')"

GN_ARGS="$GN_ARGS $EXTRA_ARGS"

gn gen "$OUT" \
  --root="$SRC" \
  --args="$GN_ARGS" \
  --ide=json \
  --export-compile-commands

echo "=== GN configured: $OUT ==="
gn args "$OUT" --list --short 2>/dev/null | head -40 || true
