#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Verify scripts exist and are executable
if [ ! -f "$REPO_ROOT/scripts/prop_parser.py" ]; then
    echo "[FAIL] scripts/prop_parser.py does not exist"
    exit 1
fi

if [ ! -x "$REPO_ROOT/scripts/generate_trees.sh" ]; then
    echo "[FAIL] scripts/generate_trees.sh does not exist or is not executable"
    exit 1
fi

python3 -m py_compile "$REPO_ROOT/scripts/prop_parser.py" || { echo "[FAIL] prop_parser.py syntax error"; exit 1; }
bash -n "$REPO_ROOT/scripts/generate_trees.sh" || { echo "[FAIL] generate_trees.sh syntax error"; exit 1; }

# Mock test for prop_parser.py
MOCK_DUMP=$(mktemp -d)
trap 'rm -rf "$MOCK_DUMP"' EXIT

mkdir -p "$MOCK_DUMP/vendor"
mkdir -p "$MOCK_DUMP/system/system"

cat <<EOF > "$MOCK_DUMP/vendor/build.prop"
ro.product.vendor.brand=Google
ro.product.vendor.device=lynx
ro.product.vendor.model=Pixel 7a
ro.board.platform=gs201
ro.build.version.release=14
ro.build.version.security_patch=2024-05-05
ro.build.fingerprint=google/lynx/lynx:14/AP2A.240505.004/11598925:user/release-keys
EOF

PARSED_OUTPUT=$(python3 "$REPO_ROOT/scripts/prop_parser.py" "$MOCK_DUMP")
echo "$PARSED_OUTPUT" | grep -q "lynx" || { echo "[FAIL] Codename lynx not parsed"; exit 1; }
echo "$PARSED_OUTPUT" | grep -q "google" || { echo "[FAIL] Brand google not parsed"; exit 1; }

# Mock test for generate_trees.sh
MOCK_OUT=$(mktemp -d)
trap 'rm -rf "$MOCK_DUMP" "$MOCK_OUT"' EXIT

"$REPO_ROOT/scripts/generate_trees.sh" "$MOCK_DUMP" "$MOCK_OUT" || { echo "[FAIL] generate_trees.sh execution failed"; exit 1; }

# Assert generated files exist in device tree
DEVICE_TREE="$MOCK_OUT/device/google/lynx"
[ -f "$DEVICE_TREE/AndroidProducts.mk" ] || { echo "[FAIL] AndroidProducts.mk missing"; exit 1; }
[ -f "$DEVICE_TREE/BoardConfig.mk" ] || { echo "[FAIL] BoardConfig.mk missing"; exit 1; }
[ -f "$DEVICE_TREE/device.mk" ] || { echo "[FAIL] device.mk missing"; exit 1; }
[ -f "$DEVICE_TREE/lineage_lynx.mk" ] || { echo "[FAIL] lineage_lynx.mk missing"; exit 1; }
[ -f "$DEVICE_TREE/proprietary-files.txt" ] || { echo "[FAIL] proprietary-files.txt missing"; exit 1; }

# Assert vendor tree exists
VENDOR_TREE="$MOCK_OUT/vendor/google/lynx"
[ -f "$VENDOR_TREE/Android.mk" ] || { echo "[FAIL] vendor Android.mk missing"; exit 1; }
[ -f "$VENDOR_TREE/lynx-vendor.mk" ] || { echo "[FAIL] lynx-vendor.mk missing"; exit 1; }

echo "[PASS] Task 3 device & vendor tree generation tests passed!"
