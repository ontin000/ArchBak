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

DST="$ROOT/BackUps/users"
STATE_FILE="$ROOT/state/users.hash"

FILES=(
  /etc/passwd
  /etc/group
  /etc/shadow
  /etc/gshadow
  /etc/subuid
  /etc/subgid
)

SUDOERS_DIR="/etc/sudoers.d"

hash_tree() {
  find "$@" -type f -print0 2>/dev/null |
    sort -z |
    xargs -0 sha256sum |
    sha256sum |
    awk '{print $1}'
}

case "$ACTION" in
  backup)
    mapfile -t USERS < <(awk -F: '$3 >= 1000 {print $1}' /etc/passwd)

    if [[ ${#USERS[@]} -eq 0 ]]; then
      echo "$EMPTY_HASH" > "$STATE_FILE"
      exit 0
    fi

    mkdir -p "$DST"

    new_hash=$(hash_tree "${FILES[@]}" "$SUDOERS_DIR")
    old_hash=$(cat "$STATE_FILE" 2>/dev/null || true)

    if [[ "$new_hash" != "$old_hash" ]]; then
      tar -czf "$DST/users.tar.gz" \
        "${FILES[@]}" \
        "$SUDOERS_DIR"
      echo "$new_hash" > "$STATE_FILE"
    fi
    ;;

  restore)
    if [[ ! -f "$DST/users.tar.gz" ]]; then
      echo "users: no backup archive found" >&2
      exit 1
    fi

    # Sanity checks before overwrite
    if [[ -n "$(getent passwd | awk -F: '$3 >= 1000 {print $1}')" ]]; then
      echo "users: non-system users already exist; refusing restore" >&2
      echo "Run on a fresh system only." >&2
      exit 1
    fi

    tar -xzf "$DST/users.tar.gz" -C /

    # Ensure sudo permissions are sane
    chmod 0440 /etc/sudoers.d/* 2>/dev/null || true
    ;;

  status)
    new_hash=$(hash_tree "${FILES[@]}" "$SUDOERS_DIR")
    old_hash=$(cat "$STATE_FILE" 2>/dev/null || true)

    if [[ "$new_hash" != "$old_hash" ]]; then
      echo "users: CHANGED"
    else
      echo "users: OK"
    fi
    ;;

  *)
    echo "Usage: $0 {backup|restore|status}" >&2
    exit 1
    ;;
esac
