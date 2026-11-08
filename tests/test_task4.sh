#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Verify scripts exist and are executable
if [ ! -x "$REPO_ROOT/scripts/upload_github.sh" ]; then
    echo "[FAIL] scripts/upload_github.sh does not exist or is not executable"
    exit 1
fi

bash -n "$REPO_ROOT/scripts/upload_github.sh" || { echo "[FAIL] upload_github.sh syntax error"; exit 1; }

# Test --help output
"$REPO_ROOT/scripts/upload_github.sh" --help >/dev/null || { echo "[FAIL] upload_github.sh --help failed"; exit 1; }

# Dry-run test with mock trees
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

mkdir -p "$MOCK_DIR/device/google/lynx"
mkdir -p "$MOCK_DIR/vendor/google/lynx"
echo "test device tree" > "$MOCK_DIR/device/google/lynx/Android.mk"
echo "test vendor tree" > "$MOCK_DIR/vendor/google/lynx/Android.mk"

# Run dry run
DRY_RUN_OUTPUT=$("$REPO_ROOT/scripts/upload_github.sh" --trees-dir "$MOCK_DIR" --target-org "testuser" --dry-run)

echo "$DRY_RUN_OUTPUT" | grep -q "device_google_lynx" || { echo "[FAIL] device repo name missing in dry run"; exit 1; }
echo "$DRY_RUN_OUTPUT" | grep -q "vendor_google_lynx" || { echo "[FAIL] vendor repo name missing in dry run"; exit 1; }

echo "[PASS] Task 4 upload_github.sh tests passed!"
