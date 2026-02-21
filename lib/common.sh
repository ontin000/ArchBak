#!/usr/bin/env bash
set -euo pipefail


HOST="$(hostname -s | tr '[:upper:]' '[:lower:]')"


# ---- ArchBak layout ----
# Resolve ArchBak root safely under sudo
USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"

if [[ -z "$USER_HOME" || "$USER_HOME" == "/root" ]]; then
  echo "ERROR: Invalid REAL_HOME='$USER_HOME'" >&2
  exit 1
fi

ROOT="$USER_HOME/ArchBak"
BACKUPS="$ROOT/BackUps"

STATE_DIR="$ROOT/state"
mkdir -p "$STATE_DIR" "$BACKUPS"

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


# ---- Identity ----
if [[ -n "${SUDO_USER:-}" ]]; then
  REAL_USER="$SUDO_USER"
else
  REAL_USER="$(id -un)"
fi

REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

readonly REAL_USER REAL_HOME HOST ROOT BACKUPS STATE
