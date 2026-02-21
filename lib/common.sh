#!/usr/bin/env bash
set -euo pipefail

# Resolve ArchBak root safely under sudo
USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
ROOT="$USER_HOME/ArchBak"

STATE_DIR="$ROOT/state"
mkdir -p "$STATE_DIR"

hash_tree() {
  find "$@" -type f -exec sha256sum {} + 2>/dev/null |
    sort |
    sha256sum |
    awk '{print $1}' || true
}

collect_existing_paths() {
  local out=()
  for p in "$@"; do
    [[ -e "$p" ]] && out+=("$p")
  done
  printf '%s\n' "${out[@]}"
}
