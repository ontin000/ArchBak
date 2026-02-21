#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

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

BIN="$ROOT/bin"

RCLONE_REMOTE="MJB-B2"
RCLONE_ROOT="BackUps-${HOST}"
RCLONE_PATH="${RCLONE_ROOT}/ArchBak"

LOCAL_BACKUPS="$USER_HOME/ArchBak/BackUps"

echo "=== ArchBak runner: host=${HOST} action=${ACTION} ==="

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

if [[ "$ACTION" == "backup" ]]; then
  echo "==> Syncing backups to rclone"
  echo "    Source: ${LOCAL_BACKUPS}"
  echo "    Dest:   ${RCLONE_REMOTE}:${RCLONE_PATH}"

  if [[ ! -d "$LOCAL_BACKUPS" ]]; then
    echo "ERROR: Local backup directory missing: $LOCAL_BACKUPS"
    exit 1
  fi
 # rclone sync \
 #   "${LOCAL_BACKUPS}" \
 #   "${RCLONE_REMOTE}:${RCLONE_PATH}"
fi

echo "=== ArchBak runner completed: action=$ACTION ==="
