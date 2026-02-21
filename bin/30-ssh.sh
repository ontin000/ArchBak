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

DST="$ROOT/BackUps/ssh"
STATE_FILE="$ROOT/state/ssh.hash"

SSH_DIR="/etc/ssh"
KEY_GLOB="$SSH_DIR/ssh_host_*_key*"

hash_tree() {
  find "$@" -type f -print0 2>/dev/null |
    sort -z |
    xargs -0 sha256sum |
    sha256sum |
    awk '{print $1}'
}

case "$ACTION" in
  backup)
    mkdir -p "$DST"

    # No host keys yet? (e.g., minimal container)
    if ! ls $KEY_GLOB >/dev/null 2>&1; then
      echo "ssh: no host keys present, skipping"
      exit 0
    fi

    new_hash=$(hash_tree $KEY_GLOB)
    old_hash=$(cat "$STATE_FILE" 2>/dev/null || true)

    if [[ "$new_hash" != "$old_hash" ]]; then
      tar -czf "$DST/ssh-host-keys.tar.gz" $KEY_GLOB
      echo "$new_hash" > "$STATE_FILE"
    fi
    ;;

  restore)
    if [[ ! -f "$DST/ssh-host-keys.tar.gz" ]]; then
      echo "ssh: no backup archive found" >&2
      exit 1
    fi

    # Safety: refuse if host keys already exist
    if ls $KEY_GLOB >/dev/null 2>&1; then
      echo "ssh: host keys already exist; refusing restore" >&2
      echo "Remove existing keys if you really intend to restore." >&2
      exit 1
    fi

    tar -xzf "$DST/ssh-host-keys.tar.gz" -C /

    # Enforce correct permissions (sshd is picky)
    chmod 600 /etc/ssh/ssh_host_*_key
    chmod 644 /etc/ssh/ssh_host_*_key.pub

    # Ensure ownership
    chown root:root /etc/ssh/ssh_host_*_key*
    ;;

  status)
    if ! ls $KEY_GLOB >/dev/null 2>&1; then
      echo "ssh: MISSING"
      exit 0
    fi

    new_hash=$(hash_tree $KEY_GLOB)
    old_hash=$(cat "$STATE_FILE" 2>/dev/null || true)

    if [[ "$new_hash" != "$old_hash" ]]; then
      echo "ssh: CHANGED"
    else
      echo "ssh: OK"
    fi
    ;;

  *)
    echo "Usage: $0 {backup|restore|status}" >&2
    exit 1
    ;;
esac
