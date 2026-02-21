#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 backup|restore|status" >&2
  exit 1
fi

ACTION="$1"

case "$ACTION" in
  backup|restore|status)
    ;;
  *)
    echo "Invalid action: $ACTION" >&2
    echo "Usage: $0 backup|restore|status" >&2
    exit 1
    ;;
esac

USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
ROOT="$USER_HOME/ArchBak"
BIN="$ROOT/bin"

# Ensure expected layout exists
if [[ ! -d "$BIN" ]]; then
  echo "ArchBak bin directory not found: $BIN" >&2
  exit 1
fi

echo "=== ArchBak runner: action=$ACTION ==="
echo

# Run all numbered scripts in order
for script in "$BIN"/[0-9][0-9]-*.sh; do
  if [[ ! -x "$script" ]]; then
    echo "[SKIP] $script (not executable)"
    continue
  fi

  echo ">>> $(basename "$script") $ACTION"
  "$script" "$ACTION"
  echo
done

echo "=== ArchBak runner completed: action=$ACTION ==="
