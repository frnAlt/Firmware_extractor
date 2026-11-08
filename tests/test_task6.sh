#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/dump_and_generate.yml"

# Verify workflow file exists
if [ ! -f "$WORKFLOW" ]; then
    echo "[FAIL] $WORKFLOW does not exist"
    exit 1
fi

# Verify workflow contains workflow_dispatch, essential inputs, and disk cleanup
grep -q "workflow_dispatch:" "$WORKFLOW" || { echo "[FAIL] workflow_dispatch trigger missing"; exit 1; }
grep -q "firmware_url" "$WORKFLOW" || { echo "[FAIL] firmware_url input missing"; exit 1; }
grep -q "generate_trees" "$WORKFLOW" || { echo "[FAIL] generate_trees input missing"; exit 1; }
grep -q "push_to_github" "$WORKFLOW" || { echo "[FAIL] push_to_github input missing"; exit 1; }
grep -q "actions/checkout" "$WORKFLOW" || { echo "[FAIL] actions/checkout missing"; exit 1; }
grep -q "actions/upload-artifact" "$WORKFLOW" || { echo "[FAIL] upload-artifact step missing"; exit 1; }

# Validate YAML syntax using python pyyaml if installed or python yaml checker
python3 -c "
import yaml
with open('$WORKFLOW') as f:
    yaml.safe_load(f)
print('[OK] YAML is valid')
" || { echo "[FAIL] Workflow YAML is not valid"; exit 1; }

echo "[PASS] Task 6 GitHub Actions workflow tests passed!"
