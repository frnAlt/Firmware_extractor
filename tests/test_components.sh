#!/usr/bin/env bash
# ==============================================================================
# Comprehensive Integration Test Suite
# Validates all 4 modules: extractor, github_pusher, tree_generator, manifest_builder
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "================================================================================"
echo " Running Universal Firmware Extractor 4-Module Test Suite"
echo "================================================================================"

PASSED=0
TOTAL=0

run_test() {
    local cmd="$1"
    local desc="$2"
    TOTAL=$((TOTAL + 1))
    echo ""
    echo "--- Test $TOTAL: $desc ---"
    if eval "$cmd"; then
        echo "[PASS] $desc"
        PASSED=$((PASSED + 1))
    else
        echo "[FAIL] $desc"
        exit 1
    fi
}

run_test "bash '$SCRIPT_DIR/test_task1.sh'" "Environment & Toolchain Setup"
run_test "bash '$SCRIPT_DIR/test_task2.sh'" "Firmware Extractor & Partition Unpacker"
run_test "bash '$SCRIPT_DIR/test_task3.sh'" "Device & Vendor Tree Generator"
run_test "bash '$SCRIPT_DIR/test_task4.sh'" "GitHub Uploader Engine"
run_test "bash '$SCRIPT_DIR/test_task5.sh'" "Master CLI run.sh Integration"
run_test "bash '$SCRIPT_DIR/test_task6.sh'" "GitHub Actions CI/CD Workflow"
run_test "bash '$SCRIPT_DIR/test_task7.sh'" "Documentation & Repository Metadata"
run_test "python3 '$SCRIPT_DIR/test_module1.py'" "Module 1: Extractor & Metadata Parser"
run_test "python3 '$SCRIPT_DIR/test_module2.py'" "Module 2: GitHub Dump Pusher & Git LFS"
run_test "python3 '$SCRIPT_DIR/test_module3.py'" "Module 3: Multi-ROM Tree & Overlays"
run_test "python3 '$SCRIPT_DIR/test_module4.py'" "Module 4: Roomservice Local Manifest Builder"

echo ""
echo "================================================================================"
echo " Full Test Suite Summary: $PASSED / $TOTAL Tests Passed Successfully!"
echo "================================================================================"
