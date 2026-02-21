#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

ACTION="${1:-}"

case "$ACTION" in
  backup|restore|status) ;;
  *)
    echo "Usage: $(basename "$0") {backup|restore|status}" >&2
    exit 1
    ;;
esac

DST="$ROOT/BackUps/systemd"
STATE_FILE="$ROOT/state/systemd.hash"

SYSTEMD_ETC="/etc/systemd/system"

hash_tree() {
  find "$1" -type f -print0 2>/dev/null |
    sort -z |
    xargs -0 sha256sum |
    sha256sum |
    awk '{print $1}'
}

case "$ACTION" in
  backup)
    mkdir -p "$DST"

    # Nothing to back up?
    if [[ ! -d "$SYSTEMD_ETC" ]]; then
      echo "systemd: no /etc/systemd/system directory"
      exit 0
    fi

    new_hash=$(hash_tree "$SYSTEMD_ETC")
    old_hash=$(cat "$STATE_FILE" 2>/dev/null || true)

    if [[ "$new_hash" != "$old_hash" ]]; then
      tar -czf "$DST/systemd-etc.tar.gz" "$SYSTEMD_ETC"
      echo "$new_hash" > "$STATE_FILE"
    fi
    ;;

  restore)
    if [[ ! -f "$DST/systemd-etc.tar.gz" ]]; then
      echo "systemd: no backup archive found" >&2
      exit 1
    fi

    # Safety: restore only on fresh systemd state
    if [[ -n "$(find "$SYSTEMD_ETC" -mindepth 1 -type f 2>/dev/null)" ]]; then
      echo "systemd: /etc/systemd/system is not empty; refusing restore" >&2
      echo "Run on a fresh system or clean the directory first." >&2
      exit 1
    fi

    tar -xzf "$DST/systemd-etc.tar.gz" -C /

    # Reload unit files
    systemctl daemon-reexec
    systemctl daemon-reload
    ;;

  status)
    if [[ ! -d "$SYSTEMD_ETC" ]]; then
      echo "systemd: MISSING"
      exit 0
    fi

    new_hash=$(hash_tree "$SYSTEMD_ETC")
    old_hash=$(cat "$STATE_FILE" 2>/dev/null || true)

    if [[ "$new_hash" != "$old_hash" ]]; then
      echo "systemd: CHANGED"
    else
      echo "systemd: OK"
    fi
    ;;

  *)
    echo "Usage: $0 {backup|restore|status}" >&2
    exit 1
    ;;
esac
