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

cp -r "$REPO_ROOT/src/."    "$SRC/cr_api/src/"
cp -r "$REPO_ROOT/include/." "$SRC/cr_api/include/"

cat > "$SRC/cr_api/BUILD.gn" <<'EOF'
import("//cr_api/src/BUILD.gn")
EOF

# ── Run gclient hooks ────────────────────────────────────────────────────────
echo "=== Running gclient hooks ==="
python3 -m pip install --quiet --break-system-packages httplib2 colorama \
  || python3 -m pip install --quiet httplib2 colorama
(cd "$(dirname "$SRC")" && python3 "$DEPOT_TOOLS/gclient.py" runhooks)

# ── Locate gn ────────────────────────────────────────────────────────────────
# Prefer the gn binary downloaded by gclient sync into src/buildtools/.
# This avoids the depot_tools gn wrapper which requires python3_bin_reldir.txt
# (a file only created when depot_tools is initialised as a git repo).
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)  GN_BIN="$SRC/buildtools/linux64/gn" ;;
  Linux-aarch64) GN_BIN="$SRC/buildtools/linux64/gn" ;;  # same binary, arm runner
  Darwin-arm64)  GN_BIN="$SRC/buildtools/mac_arm64/gn" ;;
  Darwin-x86_64) GN_BIN="$SRC/buildtools/mac/gn" ;;
  *)             GN_BIN="gn" ;;  # fallback to PATH
esac

if [ ! -x "$GN_BIN" ]; then
  echo "WARN: $GN_BIN not found, falling back to PATH gn"
  GN_BIN="gn"
fi
echo "Using gn: $GN_BIN"

# ── Build GN args string ─────────────────────────────────────────────────────
BASE_ARGS="$(grep -v '^\s*#' "$REPO_ROOT/gn_args/minimal.gni" \
             | grep -v '^\s*$' \
             | tr '\n' ' ')"

# Per-platform overrides — note: use_ozone=true already in minimal.gni for linux,
# so do NOT add use_x11=true here (conflicts with ozone headless mode).
case "$TARGET_OS" in
  win)
    PLATFORM_ARGS='target_os="win" target_cpu="x64"'
    PLATFORM_ARGS="$PLATFORM_ARGS use_ozone=false use_gtk=false"
    ;;
  mac)
    PLATFORM_ARGS='target_os="mac" target_cpu="x64"'
    PLATFORM_ARGS="$PLATFORM_ARGS use_ozone=false use_gtk=false"
    ;;
  linux|*)
    # use_ozone=true + ozone_platform_headless=true already in minimal.gni
    PLATFORM_ARGS='target_os="linux" target_cpu="x64"'
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
mkdir -p "$OUT"

"$GN_BIN" gen "$OUT" \
  --root="$SRC" \
  --args="$GN_ARGS" \
  --export-compile-commands

echo "=== GN configured ==="
"$GN_BIN" args "$OUT" --list --short 2>/dev/null | head -40 || true
