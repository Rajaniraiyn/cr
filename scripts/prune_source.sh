#!/usr/bin/env bash
# Remove directories that are not needed for a headless-only build.
# Run AFTER gclient sync, BEFORE gn gen.  Saves ~8-10 GB.
# Usage: prune_source.sh <chromium_src_dir>
set -euo pipefail

SRC="${1:?chromium src dir required}"

echo "=== Pruning unneeded source directories ==="
df -h /

remove() {
  local d="$SRC/$1"
  if [ -e "$d" ]; then
    rm -rf "$d"
    echo "  removed $1"
  fi
}

# Tests & benchmarks
remove chrome/test/data
remove content/test/data
remove net/data/ssl/certificates
remove third_party/hunspell_dictionaries
remove third_party/catapult

# Android / iOS / ChromeOS toolchains
remove third_party/android_sdk
remove third_party/android_tools
remove third_party/android_deps
remove third_party/chromite
remove third_party/cros_system_api

# Large media test vectors
remove media/test/data

# Internal tooling
remove tools/perf
remove tools/memory
remove tools/traffic_annotation

# Unnecessary codecs (we set proprietary_codecs=false)
remove third_party/openh264
remove third_party/libvpx/source/libvpx/test

# Docs & localisation (build doesn't need them)
remove docs
remove chrome/app/resources

echo "=== After prune ==="
df -h /
