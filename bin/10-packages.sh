#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

NAME="packages"

DST="$ROOT/BackUps/packages"
STATE_FILE="$ROOT/state/packages.hash"

PKG_EXPLICIT="$DST/packages-explicit.txt"   # pacman -Qqe
PKG_FOREIGN="$DST/packages-foreign.txt"     # pacman -Qqm
PKG_MANIFEST="$DST/packages-manifest.txt"   # pacman -Qq

ACTION="${1:-}"

case "$ACTION" in
  backup)
    mkdir -p "$DST" "$(dirname "$STATE_FILE")"

    # Generate normalized package lists
    pacman -Qqen | sort > "$PKG_EXPLICIT"
    pacman -Qqme | sort > "$PKG_FOREIGN"
    pacman -Qq   | sort > "$PKG_MANIFEST"

    # Snapshot hash (entire directory)
    new_hash=$(hash_tree "$DST")
    old_hash=$(cat "$STATE_FILE" 2>/dev/null || true)

    if [[ "$new_hash" != "$old_hash" ]]; then
      echo "$new_hash" > "$STATE_FILE"
    fi
    ;;

  status)
    if [[ ! -f "$STATE_FILE" ]]; then
      echo "$NAME: NO BASELINE"
      exit 0
    fi

    if [[ ! -d "$DST" ]]; then
      echo "$NAME: MISSING"
      exit 1
    fi

    new_hash=$(hash_tree "$DST")
    old_hash=$(cat "$STATE_FILE")

    if [[ "$new_hash" == "$old_hash" ]]; then
      echo "$NAME: OK"
    else
      echo "$NAME: CHANGED"
    fi
    ;;

  restore)
    if [[ ! -f "$PKG_EXPLICIT" ]]; then
      echo "[FAIL] No package backup found"
      exit 1
    fi

    echo "==> Restoring pacman packages"

    # Ensure keyring & databases are sane
    pacman -Syy --noconfirm
    pacman -Sy --noconfirm archlinux-keyring
    

    # Install repo packages
    pacman -S --needed --noconfirm \
      --overwrite='*' \
      $(<"$PKG_EXPLICIT")

    # Install AUR packages if present
    if [[ -s "$PKG_FOREIGN" ]]; then
      if ! command -v yay >/dev/null 2>&1; then
        echo "[FAIL] yay not installed (required for AUR restore)"
        exit 1
      fi

      yay -S --needed --noconfirm \
        --overwrite='*' \
        --answerclean All \
        --answerdiff None \
        $(<"$PKG_FOREIGN")
    fi
    ;;

  *)
    echo "Usage: $0 {backup|status|restore}"
    exit 1
    ;;
esac