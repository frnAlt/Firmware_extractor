#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Verify requirements.txt exists and contains necessary tools
if [ ! -f "$REPO_ROOT/requirements.txt" ]; then
    echo "[FAIL] requirements.txt does not exist"
    exit 1
fi

grep -q "aospdtgen" "$REPO_ROOT/requirements.txt" || { echo "[FAIL] aospdtgen missing from requirements.txt"; exit 1; }
grep -q "twrpdtgen" "$REPO_ROOT/requirements.txt" || { echo "[FAIL] twrpdtgen missing from requirements.txt"; exit 1; }
grep -q "extract-dtb" "$REPO_ROOT/requirements.txt" || { echo "[FAIL] extract-dtb missing from requirements.txt"; exit 1; }

# Verify setup_env.sh exists, is executable, and contains proper syntax
if [ ! -x "$REPO_ROOT/setup_env.sh" ]; then
    echo "[FAIL] setup_env.sh does not exist or is not executable"
    exit 1
fi

bash -n "$REPO_ROOT/setup_env.sh" || { echo "[FAIL] setup_env.sh has syntax errors"; exit 1; }

# Verify .gitignore ignores generated directories
grep -q "out/" "$REPO_ROOT/.gitignore" || { echo "[FAIL] out/ not in .gitignore"; exit 1; }
grep -q ".superpowers/" "$REPO_ROOT/.gitignore" || { echo "[FAIL] .superpowers/ not in .gitignore"; exit 1; }

echo "[PASS] Task 1 tests passed!"
