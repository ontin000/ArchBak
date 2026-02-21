#!/usr/bin/env bash
set -euo pipefail

# Ensure required commands exist
for cmd in pacman find comm sort sudo; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Error: required command '$cmd' not found" >&2
    exit 1
  }
done

# Common prune paths (system-safe)
PRUNE_PATHS=(
  /dev
  /sys
  /run
  /tmp
  /mnt
  /srv
  /proc
  /boot
  /home
  /root
  /media
  /usr/share/mime
  /usr/lib
  /var/lib/pacman
  /var/lib/upower
  /var/lib/texmf
  /var/lib/bluetooth
  /var/lib/nordvpn
  /var/lib/systemd/timers
  /var/spool/cron
  /var/cache
  /var/tmp
  /var/run
  /var/log
)

# Build find prune expression
build_prune_expr() {
  local expr=()
  for p in "${PRUNE_PATHS[@]}"; do
    expr+=( -path "$p" -o )
  done
  unset 'expr[-1]'
  printf '%s\n' "${expr[@]}"
}

# List all pacman-owned files
pacman_owned() {
  pacman -Qlq | sort -u
}

# List disowned directories
pacman_disowned_dirs() {
  comm -23 \
    <(
      sudo find / \
        \( $(build_prune_expr) \) -prune -o \
        -type d -print |
        sed 's|\([^/]\)$|\1/|' |
        sort -u
    ) \
    <(pacman_owned)
}

# List disowned files
pacman_disowned_files() {
  comm -23 \
    <(
      sudo find / \
        \( $(build_prune_expr) \) -prune -o \
        -type f -print |
        sort -u
    ) \
    <(pacman_owned)
}

# Allow script execution
if [[ "${1:-}" == "dirs" ]]; then
  pacman_disowned_dirs
elif [[ "${1:-}" == "files" ]]; then
  pacman_disowned_files
elif [[ "${1:-}" == "all" ]]; then
  pacman_disowned_dirs
  pacman_disowned_files
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [dirs|files|all]" >&2
  exit 1
fi
