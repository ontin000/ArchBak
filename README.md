ArchBak

ArchBak is a modular, reproducible backup and restore system for Arch Linux.

Its goal is simple:

Lose the machine, keep the system.

If your computer disappears tomorrow, ArchBak lets you rebuild a clean Arch install into a working, personalized system with minimal manual intervention.

Core Philosophy

ArchBak strictly separates three different questions that are often conflated:

Action	Question it answers	Compares
backup	“What is my snapshot?”	system → files
status	“Did my snapshot change?”	files → files
verify	“Is my system correct?”	system → files
restore	“Make the system match the snapshot”	files → system

This separation is what makes ArchBak reliable, non-flappy, and debuggable.

Directory Layout
ArchBak/
├── bin/                # Numbered backup modules
│   ├── 10-packages.sh
│   ├── 20-users.sh
│   ├── 30-ssh.sh
│   ├── 40-systemd.sh
│   ├── 45-etckeeper.sh
│   ├── 50-cron.sh
│   ├── 60-network.sh
│   ├── 70-vpn.sh
│   ├── 90-verify.sh
│   └── backup-runner.sh
│
├── lib/
│   └── common.sh       # Shared variables & helpers
│
├── BackUps/            # Immutable backup artifacts
│   ├── packages/
│   ├── users/
│   ├── ssh/
│   ├── systemd/
│   ├── etc-git/
│   └── …
│
├── state/              # Snapshot hash baselines
│   ├── packages.hash
│   ├── users.hash
│   ├── systemd.hash
│   └── …
│
├── restore/
│   └── bootstrap.sh    # Cold-start initialization
│
└── README.md
How Backups Work

Each numbered script (NN-name.sh) is responsible for one subsystem.

Every module follows the same contract:

backup

Reads live system state

Writes normalized, deterministic files into BackUps/

Computes a snapshot hash

Stores it in state/<name>.hash

status

Re-hashes the backup files

Compares against the stored hash

Reports:

OK

CHANGED

NO BASELINE

⚠ Status never reads live system state.
It only answers: “Did my snapshot change?”

Verification (90-verify.sh)

Verification answers a different question:

“Does the current system still match the backup?”

This is where live checks belong:

pacman vs saved package lists

users present

SSH host keys exist

systemd units present

network profiles exist

etc.

Verification failures are semantic, not snapshot drift.

Package Handling (Important)

Packages are split correctly to support restore:

File	Command	Purpose
packages-explicit.txt	pacman -Qneq	Explicit repo packages (restorable by pacman)
packages-foreign.txt	pacman -Qmeq	Explicit AUR packages
packages-manifest.txt	pacman -Qq	Full audit / reference
Why this matters

pacman cannot install AUR packages

yay should not install repo packages

Restore must be deterministic

Restore Flow

A clean restore looks like this:

Install Arch Linux from official media

Log in as your user

Clone ArchBak

Run bootstrap

Run restore

git clone https://github.com/ontin000/ArchBak.git
cd ArchBak
./restore/bootstrap.sh
sudo bin/backup-runner.sh restore
Bootstrap (restore/bootstrap.sh)

Bootstrap is intentionally minimal and idempotent.

It only ensures prerequisites exist:

git

rclone

base-devel

etckeeper

/etc under etckeeper control

Bootstrap:

does not restore data

does not commit state

can be safely re-run at any time

etckeeper Integration

/etc is versioned via etckeeper

ArchBak backs up /etc/.git itself

This captures:

config history

exact diffs

rollback capability

etckeeper commits are triggered separately from snapshot backups.

Remote Backups

ArchBak supports syncing backups via rclone.

Each host writes to its own remote path:

BackUps-<hostname>/ArchBak

Example:

BackUps-monster/ArchBak
BackUps-studiohead/ArchBak

This allows multiple machines to share one remote safely.

Safety Guarantees

ArchBak is designed to be:

Idempotent – safe to re-run

Deterministic – stable snapshots

Non-destructive – no silent overwrites

Explicit – no magic state

If something reports CHANGED, it means exactly that.

Common Commands
# Check snapshot drift
sudo bin/backup-runner.sh status

# Take a new snapshot
sudo bin/backup-runner.sh backup

# Restore from snapshot
sudo bin/backup-runner.sh restore

# Verify system correctness
sudo bin/backup-runner.sh status
Mental Model (TL;DR)

Backup defines truth

Status detects snapshot drift

Verify detects system drift

Restore enforces truth

If you remember nothing else, remember that.

Final Note

ArchBak is intentionally boring.

That’s a feature.

Backups should be:

predictable

explainable

repeatable

If you ever see unexpected output, it means ArchBak is doing its job — telling you the truth.
