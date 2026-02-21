#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"

FAIL=0

ok()   { echo "[ OK ] $*"; }
warn() { echo "[WARN] $*"; }
fail() { echo "[FAIL] $*"; FAIL=1; }

echo "=== ArchBak verification ==="

# ------------------------------------------------------------
# Packages
# ------------------------------------------------------------
PKG_DIR="$ROOT/BackUps/packages"

if [[ -f "$PKG_DIR/pacman-explicit.txt" ]]; then
  missing=$(comm -23 \
    <(sort "$PKG_DIR/pacman-explicit.txt") \
    <(pacman -Qnq | sort) || true)

  if [[ -n "$missing" ]]; then
    fail "Missing repo packages:"
    echo "$missing" | sed 's/^/  - /'
  else
    ok "Repo packages match"
  fi
else
  warn "No package manifest found"
fi

if [[ -f "$PKG_DIR/pacman-foreign.txt" ]]; then
  missing=$(comm -23 \
    <(sort "$PKG_DIR/pacman-foreign.txt") \
    <(pacman -Qmq | sort) || true)

  if [[ -n "$missing" ]]; then
    warn "Missing foreign/AUR packages:"
    echo "$missing" | sed 's/^/  - /'
  else
    ok "Foreign packages match"
  fi
fi

# ------------------------------------------------------------
# Users
# ------------------------------------------------------------
if getent passwd | awk -F: '$3 >= 1000' | grep -q .; then
  ok "Non-system users present"
else
  fail "No non-system users found"
fi

# ------------------------------------------------------------
# SSH
# ------------------------------------------------------------
if ls /etc/ssh/ssh_host_*_key >/dev/null 2>&1; then
  ok "SSH host keys present"
else
  fail "SSH host keys missing"
fi

# ------------------------------------------------------------
# systemd enablement
# ------------------------------------------------------------
if [[ -d /etc/systemd/system ]]; then
  ok "systemd admin directory present"
else
  fail "/etc/systemd/system missing"
fi

# ------------------------------------------------------------
# cron
# ------------------------------------------------------------
if [[ -f /etc/crontab || -d /var/spool/cron ]]; then
  ok "Cron configuration present"
else
  warn "Cron configuration missing"
fi

# ------------------------------------------------------------
# netctl
# ------------------------------------------------------------
if [[ -d /etc/netctl ]]; then
  profiles=$(ls /etc/netctl 2>/dev/null | wc -l)
  if [[ "$profiles" -gt 0 ]]; then
    ok "Netctl profiles present ($profiles)"
  else
    warn "Netctl installed but no profiles found"
  fi
else
  warn "Netctl directory missing"
fi

# ------------------------------------------------------------
# NordVPN
# ------------------------------------------------------------
if [[ -d /var/lib/nordvpn ]]; then
  ok "NordVPN state present"
else
  warn "NordVPN state missing"
fi

# ------------------------------------------------------------
# Final status
# ------------------------------------------------------------
echo
if [[ "$FAIL" -eq 0 ]]; then
  ok "System verification PASSED"
  exit 0
else
  fail "System verification FAILED"
  exit 1
fi
