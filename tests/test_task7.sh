#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Verify documentation and metadata files exist
[ -f "$REPO_ROOT/README.md" ] || { echo "[FAIL] README.md missing"; exit 1; }
[ -f "$REPO_ROOT/GUIDE.md" ] || { echo "[FAIL] GUIDE.md missing"; exit 1; }
[ -f "$REPO_ROOT/.github/repository-metadata.json" ] || { echo "[FAIL] repository-metadata.json missing"; exit 1; }

# Verify README has updated content
grep -q "run.sh" "$REPO_ROOT/README.md" || { echo "[FAIL] run.sh not documented in README.md"; exit 1; }
grep -q "GitHub Actions" "$REPO_ROOT/README.md" || { echo "[FAIL] GitHub Actions not documented in README.md"; exit 1; }

# Verify GUIDE covers bringup & troubleshooting
grep -q "SELinux" "$REPO_ROOT/GUIDE.md" || { echo "[FAIL] SELinux troubleshooting missing in GUIDE.md"; exit 1; }
grep -q "Dynamic Partitions" "$REPO_ROOT/GUIDE.md" || { echo "[FAIL] Dynamic Partitions missing in GUIDE.md"; exit 1; }
grep -q "fstab" "$REPO_ROOT/GUIDE.md" || { echo "[FAIL] fstab guidance missing in GUIDE.md"; exit 1; }

# Verify repository-metadata.json contains topics
grep -q "topics" "$REPO_ROOT/.github/repository-metadata.json" || { echo "[FAIL] topics missing in repository-metadata.json"; exit 1; }
grep -q "lineageos" "$REPO_ROOT/.github/repository-metadata.json" || { echo "[FAIL] lineageos topic missing"; exit 1; }

echo "[PASS] Task 7 documentation tests passed!"
