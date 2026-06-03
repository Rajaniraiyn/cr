#!/usr/bin/env bash
# Remove large binary/data blobs that have no BUILD.gn files and are not
# referenced by any GN target.  Run AFTER gclient sync, BEFORE gn gen.
#
# Rule: ONLY delete directories that contain no BUILD.gn files and are not
# directly referenced by any BUILD.gn in the tree.  GN parses ALL BUILD.gn
# files unconditionally, so deleting any file that has a BUILD.gn (even a
# test-data directory that exports a resource target) will break gn gen.
#
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

# ── Safe: large binary test vectors (no BUILD.gn, not referenced by GN) ──────
# These are raw media/font/cert blobs fetched by gclient but never imported
# in BUILD.gn files — verified by grep in Chromium 136.
remove media/test/data
remove net/data/ssl/certificates

# hunspell_dictionaries: skipped in .gclient custom_deps, won't exist
remove third_party/hunspell_dictionaries

# Android / iOS deps: skipped via checkout_android=False in .gclient so these
# directories won't be present; remove is a no-op but harmless.
remove third_party/android_sdk
remove third_party/android_tools
remove third_party/android_deps
remove third_party/chromite
remove third_party/cros_system_api

# openh264 / libvpx test vectors: pure binary test data, no BUILD.gn
remove third_party/openh264
remove third_party/libvpx/source/libvpx/test

# Docs: no BUILD.gn, never imported
remove docs

# ── DO NOT remove these — they contain BUILD.gn files referenced transitively
# from the root BUILD.gn:
#   chrome/test/data    → chrome/test/data/webui/BUILD.gn
#   content/test/data   → may have BUILD.gn refs
#   tools/perf          → infra/orchestrator/BUILD.gn refs tools/perf
#   tools/memory        → root BUILD.gn:235 refs //tools/memory:all
#   third_party/catapult → root BUILD.gn:267 refs catapult/telemetry
#   chrome/app/resources → referenced by chrome/app/BUILD.gn

echo "=== After prune ==="
df -h /
