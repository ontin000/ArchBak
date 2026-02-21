#!/usr/bin/env bash
set -euo pipefail

# -------- argument parsing --------
if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") backup|restore|status" >&2
  exit 1
fi

ACTION="$1"

case "$ACTION" in
  backup|restore|status) ;;
  *)
    echo "Invalid action: $ACTION" >&2
    echo "Usage: $(basename "$0") backup|restore|status" >&2
    exit 1
    ;;
esac

# -------- user/root resolution --------
USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
ROOT="$USER_HOME/ArchBak"

# -------- common helpers --------
hash_tree() {
  find "$@" -type f -exec sha256sum {} + 2>/dev/null |
    sort |
    sha256sum |
    awk '{print $1}'
}
