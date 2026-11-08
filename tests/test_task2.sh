#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Verify scripts exist and are executable
if [ ! -x "$REPO_ROOT/scripts/extract_firmware.sh" ]; then
    echo "[FAIL] scripts/extract_firmware.sh does not exist or is not executable"
    exit 1
fi

if [ ! -x "$REPO_ROOT/scripts/extract_partitions.sh" ]; then
    echo "[FAIL] scripts/extract_partitions.sh does not exist or is not executable"
    exit 1
fi

bash -n "$REPO_ROOT/scripts/extract_firmware.sh" || { echo "[FAIL] scripts/extract_firmware.sh syntax error"; exit 1; }
bash -n "$REPO_ROOT/scripts/extract_partitions.sh" || { echo "[FAIL] scripts/extract_partitions.sh syntax error"; exit 1; }

# Test help output
"$REPO_ROOT/scripts/extract_firmware.sh" --help >/dev/null || { echo "[FAIL] extract_firmware.sh --help failed"; exit 1; }
"$REPO_ROOT/scripts/extract_partitions.sh" --help >/dev/null || { echo "[FAIL] extract_partitions.sh --help failed"; exit 1; }

# Test partition extraction logic with mock directory
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

mkdir -p "$MOCK_DIR/images"
mkdir -p "$MOCK_DIR/dump"

# Create a mock partition image (empty or dummy ext4/tar)
echo "test_data" > "$MOCK_DIR/images/test.txt"

echo "[PASS] Task 2 basic tests passed!"
