#!/usr/bin/env bash
#
# sync-flutter-public.sh
# ----------------------
# One-way mirror: extract ONLY the Flutter app from the private monorepo
# (htoo-choon-full) into the standalone public repo, so the public repo can run
# free/unlimited GitHub Actions build minutes.
#
# Source of truth is the private repo's trunk branch (default: rust). Whenever the
# Flutter code changes on that branch, re-run this script and the public repo is
# updated to match. Backend, rust backend, live-stream backend, exam-guardian and
# the marketing/html sites are NEVER copied.
#
# It does NOT commit or push — you review the diff in the public repo and commit
# yourself. It touches ONLY the public repo working tree; the private repo is
# read from at a git ref (uncommitted junk in the private working tree is ignored).
#
# Usage:
#   tools/sync-flutter-public.sh [REF] [DEST_DIR]
#     REF       git ref in the private repo to mirror   (default: rust)
#     DEST_DIR  public repo path                         (default: /data/projects/htoochoon-flutter)
#
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # private repo root (this repo)
REF="${1:-rust}"
DST="${2:-/data/projects/htoochoon-flutter}"

# Top-level entries that are NOT part of the Flutter app — never mirror these.
EXCLUDE_DIRS=(
  htoo-chon-backend
  backend-rust
  live_stream_backend
  exam-guardian
  html-pages
  html-v2
  html-v3
  htoo-choon-land
  htoo-choon-land-next
  htoo-choon-new-uiux
  lib_backup_20260624_120536
)
EXCLUDE_FILES=(
  .gitlab-ci.yml   # private GitLab CI; public repo uses .github/workflows/flutter.yaml
)

command -v rsync >/dev/null || { echo "rsync required"; exit 1; }
git -C "$SRC" rev-parse --verify "$REF" >/dev/null 2>&1 || { echo "ref '$REF' not found in $SRC"; exit 1; }

echo ">> mirroring Flutter app from $SRC @ $REF  ->  $DST"
mkdir -p "$DST"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Export the tracked tree at REF (tracked files only — gitignored secrets/apks
# never appear here), then strip the non-Flutter parts.
git -C "$SRC" archive "$REF" | tar -x -C "$TMP"
for d in "${EXCLUDE_DIRS[@]}"; do rm -rf "${TMP:?}/$d"; done
for f in "${EXCLUDE_FILES[@]}"; do rm -f  "${TMP:?}/$f"; done

# Mirror into the public repo. --delete makes it an exact copy of the Flutter
# subset; .git (and anything you keep only in the public repo's .git) is preserved.
rsync -a --delete --exclude='.git/' "$TMP"/ "$DST"/

# Public-facing README (overwrites the monorepo one so the public repo reads right).
cat > "$DST/README.md" <<'EOF'
# HtooChoon — Flutter App

Cross-platform (Android / iOS / desktop) client for the HtooChoon learning
platform. This repository is a **read-only mirror of the Flutter app**, split out
from the private monorepo so builds run on free public GitHub Actions minutes.

- Source of truth: the private monorepo. Do not push app changes here directly —
  they are overwritten on the next sync.
- Backend, real-time services and admin tooling live in the private repo.
- CI: `.github/workflows/flutter.yaml`.

## Build
```bash
flutter pub get
flutter build apk        # Android
flutter build linux      # Linux desktop
```
EOF

echo ">> done. Review + commit in $DST (nothing committed/pushed by this script)."
git -C "$DST" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  && git -C "$DST" -c color.ui=always status -s | head -30 || true
