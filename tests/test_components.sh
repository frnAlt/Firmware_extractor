#!/usr/bin/env bash
# ==============================================================================
# Comprehensive Integration Test Suite
# Validates all components: setup, extraction, parsing, tree gen, GitHub upload, workflow
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "================================================================================"
echo " Running Universal Firmware Extractor Test Suite"
echo "================================================================================"

PASSED=0
TOTAL=0

run_test() {
    local test_script="$1"
    local desc="$2"
    TOTAL=$((TOTAL + 1))
    echo ""
    echo "--- Test $TOTAL: $desc ---"
    if bash "$test_script"; then
        echo "[PASS] $desc"
        PASSED=$((PASSED + 1))
    else
        echo "[FAIL] $desc"
        exit 1
    fi
}

run_test "$SCRIPT_DIR/test_task1.sh" "Environment & Dependency Toolchain Setup"
run_test "$SCRIPT_DIR/test_task2.sh" "Firmware Extractor & Partition Unpacker"
run_test "$SCRIPT_DIR/test_task3.sh" "AOSP & LineageOS Tree Generator"
run_test "$SCRIPT_DIR/test_task4.sh" "GitHub Uploader & Git Automation"
run_test "$SCRIPT_DIR/test_task5.sh" "Master Orchestrator CLI (run.sh)"
run_test "$SCRIPT_DIR/test_task6.sh" "GitHub Actions CI/CD Workflow"
run_test "$SCRIPT_DIR/test_task7.sh" "Documentation & Metadata Validation"

echo ""
echo "================================================================================"
echo " Test Suite Summary: $PASSED / $TOTAL Tests Passed Successfully!"
echo "================================================================================"
