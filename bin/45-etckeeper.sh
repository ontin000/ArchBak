#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"
# shellcheck source=../lib/common.sh

# ----------------------------
# ArchBak: etckeeper subsystem
# ----------------------------

#USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
#ROOT="$USER_HOME/ArchBak"
DST="$ROOT/BackUps/etc-git"
STATE_FILE="$ROOT/state/etc.hash"

ACTION="${1:-}"

die() {
  echo "etckeeper: ERROR: $*" >&2
  exit 1
}

need_root() {
  [[ "$EUID" -eq 0 ]] || die "must be run as root"
}

case "$ACTION" in
  backup)
    need_root

    if [[ ! -d /etc/.git ]]; then
      echo "etckeeper: NOT INITIALIZED (nothing to back up)"
      exit 0
    fi

    mkdir -p "$DST" "$(dirname "$STATE_FILE")"

    new_hash="$(hash_tree /etc/.git)"
    old_hash="$(cat "$STATE_FILE" 2>/dev/null || true)"

    if [[ "$new_hash" != "$old_hash" ]]; then
      rsync -a --delete /etc/.git/ "$DST/"
      echo "$new_hash" > "$STATE_FILE"
      echo "etckeeper: backed up /etc/.git"
    else
      echo "etckeeper: no changes"
    fi
    ;;

  restore)
    need_root

    pacman -S --needed --noconfirm etckeeper git

    if [[ ! -d /etc/.git ]]; then
      echo "etckeeper: initializing /etc repository"
      etckeeper init
    fi

    if [[ -d "$DST" ]]; then
      echo "etckeeper: restoring /etc from backup"
      rsync -a --delete "$DST/" /etc/.git/
      git -C /etc reset --hard
    else
      echo "etckeeper: WARN no backup found, leaving /etc as-is"
    fi
    ;;

  status)
    if [[ ! -d /etc/.git ]]; then
      echo "etckeeper: NOT INITIALIZED"
      exit 0
    fi

    if [[ ! -f "$STATE_FILE" ]]; then
      echo "etckeeper: NO BASELINE"
      exit 0
    fi

    current_hash="$(hash_tree /etc/.git)"
    saved_hash="$(cat "$STATE_FILE")"

    if [[ "$current_hash" == "$saved_hash" ]]; then
      echo "etckeeper: OK"
    else
      echo "etckeeper: CHANGED"
    fi
    ;;

  *)
    echo "Usage: $(basename "$0") {backup|restore|status}"
    exit 1
    ;;
esac
