#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# Configuration (edit if needed)
# ----------------------------
ARCHBAK_DIR="$HOME/ArchBak"
BACKUPS_DIR="$ARCHBAK_DIR/BackUps"
STATE_DIR="$ARCHBAK_DIR/state"

GIT_REPO_URL="https://github.com/ontin000/ArchBak.git"

HOST="$(hostname -s | tr '[:upper:]' '[:lower:]')"

RCLONE_REMOTE="MJB-B2"
RCLONE_ROOT="BackUps-${HOST}"
RCLONE_PATH="${RCLONE_ROOT}/ArchBak"

#LOCAL_BACKUPS="$HOME/ArchBak/BackUps"#RCLONE_REMOTE="MJB-B2"
#RCLONE_PATH="BackUps-Studiohead/ArchBak"

# ----------------------------
# Helpers
# ----------------------------
die() {
  echo "ERROR: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

# ----------------------------
# Begin bootstrap
# ----------------------------
echo "==> ArchBak bootstrap starting"

# Must not be run as root
if [[ "$EUID" -eq 0 ]]; then
  die "Do not run bootstrap.sh as root"
fi

echo "==> Ensuring basic tooling"
sudo pacman -Syy
sudo pacman -S --needed --noconfirm git rclone base-devel

need_cmd git
need_cmd rclone

echo "==> Ensuring ArchBak directory structure"
mkdir -p "$ARCHBAK_DIR" "$BACKUPS_DIR" "$STATE_DIR"

echo "==> Fetching ArchBak scripts from Git"
if [[ ! -d "$ARCHBAK_DIR/.git" ]]; then
  git clone "$GIT_REPO_URL" "$ARCHBAK_DIR"
else
  echo "==> ArchBak repo already exists, updating"
  (cd "$ARCHBAK_DIR" && git pull)
fi

echo "==> Checking etckeeper availability"
sudo pacman -S --needed --noconfirm etckeeper git

if ! command -v etckeeper >/dev/null 2>&1; then
  die "etckeeper not installed"
fi

echo "==> etckeeper present"

echo "==> Ensuring Git identity for etckeeper (/etc)"
sudo git -C /etc config user.name "ArchBak etckeeper"
sudo git -C /etc config user.email "root@$(hostname)"
echo "==> Ensuring /etc is under etckeeper control"

if [[ ! -d /etc/.git ]]; then
  echo "    Initializing etckeeper for /etc"
  sudo etckeeper init
  sudo etckeeper commit "Initial /etc baseline (bootstrap)"
else
  echo "    /etc already under etckeeper control"
fi

echo "==> Verifying rclone remote: $RCLONE_REMOTE"
if ! rclone listremotes | grep -q "^${RCLONE_REMOTE}:"; then
  die "rclone remote '$RCLONE_REMOTE' not configured. Run: rclone config"
fi

echo "==> Syncing backups from rclone"
echo "    Source: ${RCLONE_REMOTE}:${RCLONE_PATH}"
echo "    Dest:   ${BACKUPS_DIR}"

#rclone sync \
#  "${RCLONE_REMOTE}:${RCLONE_PATH}" \
#  "$BACKUPS_DIR" \
#  --progress

echo
echo "==> Bootstrap complete"
echo
echo "Next steps:"
echo "  1. Review backups in: $BACKUPS_DIR"
echo "  2. When ready, run:"
echo "     sudo $ARCHBAK_DIR/bin/backup-runner.sh restore"
echo
echo "Bootstrap finished successfully."
