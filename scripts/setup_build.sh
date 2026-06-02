#!/usr/bin/env bash
# Copy cr_api sources into the Chromium tree and generate the GN build.
# Usage: setup_build.sh <chromium_src_dir> [depot_tools_dir]
#
# Env vars (set by build.yml matrix):
#   CR_TARGET_OS  — linux | win | mac   (default: linux)
#   CR_OUT_DIR    — out subdirectory    (default: Minimal)
set -euo pipefail

SRC="${1:?chromium src dir required}"
DEPOT_TOOLS="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

TARGET_OS="${CR_TARGET_OS:-linux}"
OUT_DIR_NAME="${CR_OUT_DIR:-Minimal}"
OUT="$SRC/out/$OUT_DIR_NAME"

if [ -n "$DEPOT_TOOLS" ]; then
  export PATH="$DEPOT_TOOLS:$PATH"
fi

# ── Copy our sources into the Chromium tree ──────────────────────────────────
echo "=== Installing cr_api sources (target=$TARGET_OS) ==="
mkdir -p "$SRC/cr_api/src" "$SRC/cr_api/include"

cp -r "$REPO_ROOT/src/."   "$SRC/cr_api/src/"
cp -r "$REPO_ROOT/include/." "$SRC/cr_api/include/"

cat > "$SRC/cr_api/BUILD.gn" <<'EOF'
import("//cr_api/src/BUILD.gn")
EOF

# ── Run gclient hooks ────────────────────────────────────────────────────────
echo "=== Running gclient hooks ==="
python3 -m pip install --quiet --break-system-packages httplib2 colorama \
  || python3 -m pip install --quiet httplib2 colorama
(cd "$(dirname "$SRC")" && python3 "$DEPOT_TOOLS/gclient.py" runhooks)

# ── Build GN args string ─────────────────────────────────────────────────────
BASE_ARGS="$(grep -v '^\s*#' "$REPO_ROOT/gn_args/minimal.gni" \
             | grep -v '^\s*$' \
             | tr '\n' ' ')"

# Per-platform overrides
case "$TARGET_OS" in
  win)
    PLATFORM_ARGS='target_os="win" target_cpu="x64" is_clang=true use_lld=true'
    # On Linux hosts building for Windows we must disable some Linux-only deps
    PLATFORM_ARGS="$PLATFORM_ARGS use_cups=false use_udev=false use_gtk=false use_x11=false use_ozone=false"
    ;;
  mac)
    PLATFORM_ARGS='target_os="mac" target_cpu="x64"'
    PLATFORM_ARGS="$PLATFORM_ARGS use_cups=false use_gtk=false use_x11=false"
    ;;
  linux|*)
    PLATFORM_ARGS='target_os="linux" target_cpu="x64" use_x11=true use_gtk=true'
    ;;
esac

# Inject ccache wrapper if available
CCACHE_BIN="$(command -v ccache 2>/dev/null || true)"
CCACHE_ARG=""
if [ -n "$CCACHE_BIN" ]; then
  CCACHE_ARG='cc_wrapper="ccache"'
fi

GN_ARGS="$BASE_ARGS $PLATFORM_ARGS $CCACHE_ARG"

# ── gn gen ───────────────────────────────────────────────────────────────────
echo "=== gn gen: $OUT ==="
echo "    args: $GN_ARGS"
mkdir -p "$OUT"

gn gen "$OUT" \
  --root="$SRC" \
  --args="$GN_ARGS" \
  --export-compile-commands

echo "=== GN configured ==="
gn args "$OUT" --list --short 2>/dev/null | head -30 || true
