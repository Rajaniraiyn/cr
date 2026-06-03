#!/usr/bin/env bash
# Fetch a minimal Chromium source tree.
# Usage: fetch_chromium.sh <version> <depot_tools_dir> <out_dir>
#   e.g. fetch_chromium.sh 136.0.7103.114 /opt/depot_tools /mnt/chromium
set -euo pipefail

CHROMIUM_VERSION="${1:?version required}"
DEPOT_TOOLS="${2:?depot_tools dir required}"
OUT_DIR="${3:?output dir required}"

export PATH="$DEPOT_TOOLS:$PATH"
# Deployed as a flat artifact (not a git clone) so self-update won't work.
export DEPOT_TOOLS_UPDATE=0
export PYTHONDONTWRITEBYTECODE=1

# Install Python deps that gclient needs.  We call gclient.py directly with
# system python3 (below) to avoid vpython3 creating a fresh virtualenv that
# doesn't have these packages.
python3 -m pip install --quiet --break-system-packages httplib2 colorama \
  || python3 -m pip install --quiet httplib2 colorama

# Convenience alias — calls gclient.py directly under system python3,
# bypassing the vpython3 wrapper in the depot_tools gclient shell script.
gclient_py() {
  python3 "$DEPOT_TOOLS/gclient.py" "$@"
}

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
      "src/chrome/test/data/perf/canvas_bench"  : None,
      "src/chrome/test/data/perf/sunspider"     : None,
      "src/third_party/hunspell_dictionaries"   : None,
      "src/third_party/android_tools"           : None,
      # catapult: keep — referenced by //BUILD.gn:267 (bitmaptools)
    },
    "custom_vars" : {
      "checkout_android"                : False,
      "checkout_android_native_support" : False,
      "checkout_ios"                    : False,
      "checkout_oculus_sdk"             : False,
      "checkout_openxr"                 : False,
      "checkout_pgo_profiles"           : False,
      "checkout_src_internal"           : False,
      "checkout_rust"                   : False,
      "checkout_reclient"               : False,
    },
  },
]
GCLIENT

# Shallow fetch of the main repo only
if [ ! -d src/.git ]; then
  git clone \
    --depth=1 \
    --branch "$CHROMIUM_VERSION" \
    https://chromium.googlesource.com/chromium/src.git \
    src
fi

# Sync dependencies — call gclient.py directly so system python3 is used
gclient_py sync \
  --no-history \
  --shallow \
  --nohooks \
  --delete_unversioned_trees \
  --jobs=4 \
  --with_branch_heads

echo "=== Source sync complete ==="
df -h /
