#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") backup|restore|status" >&2
  exit 1
fi

ACTION="$1"

SRC_ETC=()
SRC_VAR="/var/spool/cron"

for p in \
  /etc/crontab \
  /etc/cron.hourly \
  /etc/cron.daily \
  /etc/cron.weekly \
  /etc/cron.monthly
do
  [[ -e "$p" ]] && SRC_ETC+=("$p")
done

case "$ACTION" in
  backup|restore|status) ;;
  *)
    echo "Invalid action: $ACTION" >&2
    exit 1
    ;;
esac

source "$(dirname "$0")/../lib/common.sh"

DST="$ROOT/BackUps/cron"
STATE="$ROOT/state/cron.hash"

SRC_ETC=(
  /etc/crontab
  /etc/cron.hourly
  /etc/cron.daily
  /etc/cron.weekly
  /etc/cron.monthly
)
SRC_VAR="/var/spool/cron"

case "$ACTION" in
  backup)
    echo "cron: entered backup"
    mkdir -p "$DST"

    HASH_INPUTS=("${SRC_ETC[@]}")

    if [[ -d "$SRC_VAR" ]]; then
      HASH_INPUTS+=("$SRC_VAR")
    fi
 
#    echo "cron: before hash"
#    new_hash=$(hash_tree "${HASH_INPUTS[@]}")
#    echo "DEBUG hash: $new_hash"
#    echo "cron: after hash"
set +e
set +o pipefail

new_hash=$(hash_tree "${HASH_INPUTS[@]}")
hash_rc=$?

set -e
set -o pipefail

echo "DEBUG: hash_rc=$hash_rc"
echo "DEBUG: new_hash=$new_hash"
echo "cron: after hash"

    old_hash=$(cat "$STATE" 2>/dev/null || true)

    if [[ "$new_hash" != "$old_hash" ]]; then
      echo "cron: before tar"
      tar -czf "$DST/cron.tar.gz" "${HASH_INPUTS[@]}"
      echo "$new_hash" > "$STATE"
    fi
    ;;
  
  restore)
    if [[ ! -f "$DST/cron.tar.gz" ]]; then
      echo "cron: no backup archive found" >&2
      exit 1
    fi

    # Safety: refuse restore if user crontabs already exist
    if [[ -d "$SRC_VAR" ]]; then
      echo "cron: existing user crontabs found; refusing restore" >&2
      echo "Run on a fresh system only." >&2
      exit 1
    fi

    tar -xzf "$DST/cron.tar.gz" -C /

    # Ensure correct permissions (cron is picky)
    chmod 600 /var/spool/cron/* 2>/dev/null || true
    chown root:root /etc/crontab
    chown -R root:root /etc/cron.hourly /etc/cron.daily \
                     /etc/cron.weekly /etc/cron.monthly
    ;;

  status)
    if [[ ! -f "$STATE" ]]; then
      echo "cron: NO BASELINE"
      exit 0
    fi
    
    new_hash=$(hash_tree "${SRC_ETC[@]}" "$SRC_VAR")
    old_hash=$(cat "$STATE" 2>/dev/null || true)

    if [[ "$new_hash" != "$old_hash" ]]; then
      echo "cron: CHANGED"
    else
      echo "cron: OK"
    fi
    ;;

  *)
    echo "Usage: $0 {backup|restore|status}" >&2
    exit 1
    ;;
esac
