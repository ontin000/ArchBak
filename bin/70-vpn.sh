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

DST="$ROOT/BackUps/network"
STATE_FILE="$ROOT/state/network.hash"

NETCTL_DIR="/etc/netctl"
SYSTEMD_NETCTL="/etc/systemd/system"

hash_tree() {
  find "$@" -type f -print0 2>/dev/null |
    sort -z |
    xargs -0 sha256sum |
    sha256sum |
    awk '{print $1}'
}

netctl_units() {
  find "$SYSTEMD_NETCTL" -maxdepth 1 \
    -type l \
    -name 'netctl@*.service' \
    -print
}

case "$ACTION" in
  backup)
    mkdir -p "$DST"

    if [[ ! -d "$NETCTL_DIR" ]]; then
      echo "network: netctl not present, skipping"
      exit 0
    fi

    new_hash=$(hash_tree "$NETCTL_DIR" $(netctl_units))
    old_hash=$(cat "$STATE_FILE" 2>/dev/null || true)

    if [[ "$new_hash" != "$old_hash" ]]; then
      tar -czf "$DST/netctl.tar.gz" \
        "$NETCTL_DIR" \
        $(netctl_units)
      echo "$new_hash" > "$STATE_FILE"
    fi
    ;;

  restore)
    if [[ ! -f "$DST/netctl.tar.gz" ]]; then
      echo "network: no netctl backup found" >&2
      exit 1
    fi

    # Safety: refuse restore if netctl profiles already exist
    if [[ -n "$(ls -A "$NETCTL_DIR" 2>/dev/null)" ]]; then
      echo "network: existing netctl profiles found; refusing restore" >&2
      echo "Run on a fresh system only." >&2
      exit 1
    fi

    tar -xzf "$DST/netctl.tar.gz" -C /

    # Reload systemd so enablement is visible
    systemctl daemon-reload
    ;;

  status)
    if [[ ! -d "$NETCTL_DIR" ]]; then
      echo "network: MISSING"
      exit 0
    fi

    new_hash=$(hash_tree "$NETCTL_DIR" $(netctl_units))
    old_hash=$(cat "$STATE_FILE" 2>/dev/null || true)

    if [[ "$new_hash" != "$old_hash" ]]; then
      echo "network: CHANGED"
    else
      echo "network: OK"
    fi
    ;;

  *)
    echo "Usage: $0 {backup|restore|status}" >&2
    exit 1
    ;;
esac
