#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Verify run.sh exists and is executable
if [ ! -x "$REPO_ROOT/run.sh" ]; then
    echo "[FAIL] run.sh does not exist or is not executable"
    exit 1
fi

bash -n "$REPO_ROOT/run.sh" || { echo "[FAIL] run.sh syntax error"; exit 1; }

# Test --help output
"$REPO_ROOT/run.sh" --help >/dev/null || { echo "[FAIL] run.sh --help failed"; exit 1; }

# Mock end-to-end execution test with fake dump
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

mkdir -p "$MOCK_DIR/fake_dump/vendor"
cat <<EOF > "$MOCK_DIR/fake_dump/vendor/build.prop"
ro.product.vendor.brand=Google
ro.product.vendor.device=lynx
ro.product.vendor.model=Pixel 7a
ro.board.platform=gs201
ro.build.version.release=14
EOF

# Test run.sh in trees-only mode with pre-existing dump
"$REPO_ROOT/run.sh" --dump-dir "$MOCK_DIR/fake_dump" --out "$MOCK_DIR/out" --dry-run || {
    echo "[FAIL] run.sh failed in trees-only mock mode"
    exit 1
}

[ -f "$MOCK_DIR/out/trees/device/google/lynx/AndroidProducts.mk" ] || { echo "[FAIL] Generated trees missing"; exit 1; }

echo "[PASS] Task 5 run.sh tests passed!"
