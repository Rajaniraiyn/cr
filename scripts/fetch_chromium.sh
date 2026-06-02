#!/usr/bin/env bash
# Fetch a minimal Chromium source tree.
# Usage: fetch_chromium.sh <version> <depot_tools_dir> <out_dir>
#   e.g. fetch_chromium.sh 124.0.6367.155 /opt/depot_tools /mnt/chromium
set -euo pipefail

CHROMIUM_VERSION="${1:?version required}"
DEPOT_TOOLS="${2:?depot_tools dir required}"
OUT_DIR="${3:?output dir required}"

export PATH="$DEPOT_TOOLS:$PATH"
# Allow depot_tools to bootstrap its Python virtualenv (cipd + httplib2 etc.)
# on first use. Once bootstrapped we freeze further network updates.
export DEPOT_TOOLS_UPDATE=1
export PYTHONDONTWRITEBYTECODE=1

# Bootstrap depot_tools' managed Python environment before any gclient call.
# This installs httplib2 and other deps into depot_tools' own virtualenv.
if [ -f "$DEPOT_TOOLS/ensure_bootstrap" ]; then
  "$DEPOT_TOOLS/ensure_bootstrap"
fi

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

echo "=== Fetching Chromium $CHROMIUM_VERSION ==="

# Write .gclient with custom_vars to skip large optional deps
cat > .gclient <<'GCLIENT'
solutions = [
  {
    "name"        : "src",
    "url"         : "https://chromium.googlesource.com/chromium/src.git",
    "managed"     : False,
    "custom_deps" : {
      # Skip test data, internal tools, and unneeded third-party libs
      "src/chrome/test/data/perf/canvas_bench"         : None,
      "src/chrome/test/data/perf/sunspider"            : None,
      "src/third_party/hunspell_dictionaries"          : None,
      "src/third_party/android_tools"                  : None,
      "src/third_party/catapult"                       : None,
    },
    "custom_vars" : {
      "checkout_android"                : False,
      "checkout_android_native_support" : False,
      "checkout_ios"                    : False,
      # checkout_nacl removed in Chromium 136 — NaCl is fully gone
      "checkout_oculus_sdk"             : False,
      "checkout_openxr"                 : False,
      "checkout_pgo_profiles"           : False,
      "checkout_src_internal"           : False,
      "checkout_rust"                   : False,  # skip Rust toolchain (~500 MB)
      "checkout_reclient"               : False,  # remote execution client
    },
  },
]
GCLIENT

# Shallow fetch of the main repo
if [ ! -d src/.git ]; then
  git clone \
    --depth=1 \
    --branch "$CHROMIUM_VERSION" \
    https://chromium.googlesource.com/chromium/src.git \
    src
fi

# Sync only what the build needs (no history, no tests, 4 parallel jobs)
gclient sync \
  --no-history \
  --shallow \
  --nohooks \
  --delete_unversioned_trees \
  --jobs=4 \
  --with_branch_heads

echo "=== Source sync complete ==="
df -h /
