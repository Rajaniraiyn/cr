#!/usr/bin/env bash
# Aggressively free disk on a GitHub-hosted Ubuntu runner.
# Recovers ~20 GB — run as the first step of every job.
set -euo pipefail

echo "=== Disk before cleanup ==="
df -h /

# Large pre-installed toolchains we never use
sudo rm -rf \
  /usr/share/dotnet \
  /usr/local/lib/android \
  /opt/ghc \
  /usr/local/share/boost \
  /usr/lib/jvm \
  /usr/share/swift \
  /usr/share/az_* \
  /usr/local/go \
  /usr/lib/llvm-* \
  /opt/hostedtoolcache/CodeQL \
  /opt/hostedtoolcache/Ruby \
  /opt/hostedtoolcache/node \
  /opt/hostedtoolcache/PyPy \
  /usr/share/doc \
  /usr/share/man

# Docker images
sudo docker system prune -af 2>/dev/null || true

# APT packages we will never need
sudo apt-get remove -y --auto-remove \
  azure-cli \
  google-cloud-sdk \
  google-cloud-cli \
  'dotnet-sdk-*' \
  firefox \
  powershell \
  snapd \
  mono-devel \
  libmono-* \
  2>/dev/null || true

sudo apt-get autoremove -y
sudo apt-get autoclean

echo "=== Disk after cleanup ==="
df -h /
