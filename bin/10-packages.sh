#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Shared library
# -------------------------------------------------------------------
source "$(dirname "$0")/../lib/common.sh"

# -------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------
DST="$ROOT/BackUps/packages"
STATE_FILE="$STATE_DIR/packages.hash"

PKG_EXPLICIT="$DST/pacman-explicit.txt"   # pacman -Qqe (restore input)
PKG_FOREIGN="$DST/pacman-foreign.txt"     # pacman -Qqm (AUR)
PKG_MANIFEST="$DST/pacman-manifest.txt"   # pacman -Qq  (audit only)

ACTION="${1:-}"

case "$ACTION" in
  backup|restore|status) ;;
  *)
    echo "Usage: $(basename "$0") {backup|status|restore}" >&2
    exit 1
    ;;
esac

# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------
hash_packages() {
  sha256sum "$PKG_EXPLICIT" "$PKG_FOREIGN" 2>/dev/null \
    | sha256sum | awk '{print $1}'
}

# -------------------------------------------------------------------
# Main
# -------------------------------------------------------------------
case "$ACTION" in
  backup)
    mkdir -p "$DST"

    # Explicitly installed packages (restore truth)
    pacman -Qneq | sort > "$PKG_EXPLICIT"

    # Foreign / AUR packages
    pacman -Qmeq | sort > "$PKG_FOREIGN"

    # Full manifest (audit / diff only)
    pacman -Qq | sort > "$PKG_MANIFEST"

    new_hash=$(hash_packages)
    echo "$new_hash" > "$STATE_FILE"
    ;;

  status)
    if [[ ! -f "$PKG_EXPLICIT" ]]; then
      echo "packages: NO BASELINE"
      exit 0
    fi

    current_explicit_hash=$(pacman -Qneq | sort | sha256sum | awk '{print $1}')
    saved_explicit_hash=$(sha256sum "$PKG_EXPLICIT" | awk '{print $1}')

    if [[ "$current_explicit_hash" != "$saved_explicit_hash" ]]; then
      echo "packages: CHANGED"
    else
      echo "packages: OK"
    fi
    ;;

  restore)
    if [[ ! -f "$PKG_EXPLICIT" ]]; then
      echo "packages: no explicit package list to restore" >&2
      exit 1
    fi

    echo "==> Refreshing pacman databases"
    pacman -Syy --noconfirm

    echo "==> Ensuring keyring is up to date"
    pacman -S --noconfirm archlinux-keyring
    pacman-key --init
    pacman-key --populate archlinux

    echo "==> Restoring official packages"
    pacman -S --needed --noconfirm --overwrite '*' - < "$PKG_EXPLICIT"

    # AUR restore is optional but supported
    if [[ -s "$PKG_FOREIGN" ]]; then
      if ! command -v yay >/dev/null 2>&1; then
        echo "==> Installing yay (AUR helper)"
        pacman -S --needed --noconfirm base-devel git
        tmpdir=$(mktemp -d)
        git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
        (cd "$tmpdir/yay" && makepkg -si --noconfirm)
        rm -rf "$tmpdir"
      fi

      echo "==> Restoring AUR packages"
      yay -S --needed --noconfirm \
          --overwrite '*' \
          --answerclean all \
          --answerdiff none \
          - < "$PKG_FOREIGN"
    else
      echo "==> No AUR packages to restore"
    fi
    ;;
esac
