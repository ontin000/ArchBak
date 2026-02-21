#!/usr/bin/env bash
set -euo pipefail

# ---- argument handling ----------------------------------------------------
if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") backup|restore|status" >&2
  exit 1
fi

ACTION="$1"
case "$ACTION" in
  backup|restore|status) ;;
  *)
    echo "Invalid action: $ACTION" >&2
    exit 1
    ;;
esac

# ---- shared library -------------------------------------------------------
source "$(dirname "$0")/../lib/common.sh"

# ---- paths ---------------------------------------------------------------
DST="$ROOT/BackUps/cron"
STATE="$STATE_DIR/cron.hash"

# Cron locations are optional on many systems
CRON_PATHS=(
  /etc/crontab
  /etc/cron.hourly
  /etc/cron.daily
  /etc/cron.weekly
  /etc/cron.monthly
)

CRON_SPOOL="/var/spool/cron"

# ---- helpers -------------------------------------------------------------
collect_existing_paths() {
  local out=()
  for p in "$@"; do
    [[ -e "$p" ]] && out+=("$p")
  done
  printf '%s\n' "${out[@]}"
}

# ---- main ----------------------------------------------------------------
case "$ACTION" in
  backup)
    mkdir -p "$DST"

    mapfile -t ETC_INPUTS < <(collect_existing_paths "${CRON_PATHS[@]}")
    ARCHIVE_INPUTS=("${ETC_INPUTS[@]}")

    [[ -d "$CRON_SPOOL" ]] && ARCHIVE_INPUTS+=("$CRON_SPOOL")

    # Compute hash over whatever exists (may be empty)
    new_hash=$(hash_tree "${ARCHIVE_INPUTS[@]}")
    old_hash=$(cat "$STATE" 2>/dev/null || true)

    # SHA256 of empty input (nothing meaningful to back up)
    EMPTY_HASH="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    # Nothing meaningful present → record state and succeed
    if [[ "$new_hash" == "$EMPTY_HASH" ]]; then
      echo "$new_hash" > "$STATE"
      exit 0
    fi

    # No change since last backup → succeed quietly
    if [[ "$new_hash" == "$old_hash" ]]; then
      exit 0
    fi

    # Real cron content changed → archive and record
    tar -czf "$DST/cron.tar.gz" "${ARCHIVE_INPUTS[@]}"
    echo "$new_hash" > "$STATE"
    exit 0
    ;;
  restore)
    if [[ ! -f "$DST/cron.tar.gz" ]]; then
      echo "cron: no backup to restore"
      exit 0
    fi

    tar -xzf "$DST/cron.tar.gz" -C /
    ;;

  status)
    mapfile -t ETC_INPUTS < <(collect_existing_paths "${CRON_PATHS[@]}")
    CHECK_INPUTS=("${ETC_INPUTS[@]}")

    [[ -d "$CRON_SPOOL" ]] && CHECK_INPUTS+=("$CRON_SPOOL")

    if [[ ! -f "$STATE" ]]; then
      echo "cron: NO BASELINE"
      exit 0
    fi

    if [[ ${#CHECK_INPUTS[@]} -eq 0 ]]; then
      new_hash="EMPTY"
    else
      new_hash=$(hash_tree "${CHECK_INPUTS[@]}")
    fi

    old_hash=$(cat "$STATE")

    if [[ "$new_hash" != "$old_hash" ]]; then
      echo "cron: CHANGED"
    else
      echo "cron: OK"
    fi
    ;;
esac
