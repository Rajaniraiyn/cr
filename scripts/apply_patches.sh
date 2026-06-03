#!/usr/bin/env bash
# Apply ungoogled-chromium de-Googling patches, then our own cr_api patches.
# Usage: apply_patches.sh <chromium_src_dir> [patch_series_override]
set -euo pipefail

SRC="${1:?chromium src dir required}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PATCHES_DIR="$REPO_ROOT/patches"

UNGOOGLED_VERSION="${UNGOOGLED_VERSION:-124.0.6367.155-1}"

# Ungoogled patches partially apply (some succeed, some fail) and can leave
# the tree in a broken GN state.  Skip them until the core build is confirmed.
# Set APPLY_UNGOOGLED=1 to re-enable.
if [ "${APPLY_UNGOOGLED:-0}" = "1" ]; then
  echo "=== Fetching ungoogled-chromium patches ($UNGOOGLED_VERSION) ==="

  UG_DIR="$(mktemp -d)"
  trap 'rm -rf "$UG_DIR"' EXIT

  git clone \
    --depth=1 \
    --branch "$UNGOOGLED_VERSION" \
    https://github.com/ungoogled-software/ungoogled-chromium.git \
    "$UG_DIR" 2>/dev/null \
    || git clone --depth=1 \
         https://github.com/ungoogled-software/ungoogled-chromium.git \
         "$UG_DIR"

  echo "=== Applying ungoogled-chromium patches ==="
  SERIES="$UG_DIR/patches/series"
  if [ -f "$SERIES" ]; then
    while IFS= read -r patch; do
      [[ "$patch" =~ ^#.*$ || -z "$patch" ]] && continue
      pfile="$UG_DIR/patches/$patch"
      if [ -f "$pfile" ]; then
        echo "  applying $patch"
        patch -d "$SRC" -p1 --forward --reject-file=/dev/null < "$pfile" || {
          echo "  WARN: patch $patch had conflicts — skipping"
        }
      fi
    done < "$SERIES"
  fi
else
  echo "=== Skipping ungoogled-chromium patches (APPLY_UNGOOGLED not set) ==="
fi

# ── Apply our own cr_api patches ─────────────────────────────────────────────
CR_SERIES="$PATCHES_DIR/series"
if [ -f "$CR_SERIES" ]; then
  echo "=== Applying cr patches ==="
  while IFS= read -r patch; do
    [[ "$patch" =~ ^#.*$ || -z "$patch" ]] && continue
    pfile="$PATCHES_DIR/$patch"
    if [ -f "$pfile" ]; then
      echo "  applying $patch"
      patch -d "$SRC" -p1 < "$pfile"
    fi
  done < "$CR_SERIES"
fi

echo "=== Patch application complete ==="
