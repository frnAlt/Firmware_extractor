#!/usr/bin/env bash
# ==============================================================================
# Automated GitHub Uploader & Git Repository Creator
# Initializes git repos, commits AOSP/Lineage trees, and pushes to GitHub
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -t, --trees-dir <DIR>      Directory containing generated device & vendor trees (default: out/trees).
  -u, --target-org <USER>    GitHub user or organization to create/push repositories to.
  -k, --token <TOKEN>        GitHub Personal Access Token (defaults to GH_TOKEN or GITHUB_TOKEN).
  -b, --branch <BRANCH>      Git branch name (default: lineage-21.0 or master).
  -r, --release-dump <FILE>  Upload compressed dump archive to a GitHub release.
  -d, --dry-run              Simulate git operations and repo creation without pushing.
  -h, --help                 Show this help message.

Examples:
  $0 --trees-dir out/trees --target-org myuser
  $0 --dry-run --target-org myorg
EOF
}

TREES_DIR="$REPO_ROOT/out/trees"
TARGET_ORG="${GITHUB_ACTOR:-}"
AUTH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
BRANCH="lineage-21.0"
RELEASE_DUMP=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--trees-dir)
            TREES_DIR="$2"
            shift 2
            ;;
        -u|--target-org|--user)
            TARGET_ORG="$2"
            shift 2
            ;;
        -k|--token)
            AUTH_TOKEN="$2"
            shift 2
            ;;
        -b|--branch)
            BRANCH="$2"
            shift 2
            ;;
        -r|--release-dump)
            RELEASE_DUMP="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [ ! -d "$TREES_DIR" ]; then
    echo "[ERROR] Trees directory does not exist: $TREES_DIR"
    exit 1
fi

if [ -z "$TARGET_ORG" ]; then
    if [ "$DRY_RUN" = true ]; then
        TARGET_ORG="example_user"
    else
        echo "[ERROR] GitHub username or organization not specified. Use --target-org <NAME> or set GITHUB_ACTOR."
        exit 1
    fi
fi

echo "=== [1/3] Preparing GitHub Tree Deployment ==="
echo "[INFO] Target Account: $TARGET_ORG"
echo "[INFO] Trees Source:   $TREES_DIR"
echo "[INFO] Target Branch:  $BRANCH"
echo "[INFO] Dry Run Mode:   $DRY_RUN"

# Locate device and vendor trees
upload_tree() {
    local tree_type="$1" # "device" or "vendor"
    local brand="$2"
    local codename="$3"
    local path="$4"
    local repo_name="${tree_type}_${brand}_${codename}"

    echo ""
    echo "=== Processing $tree_type tree: $brand/$codename -> $TARGET_ORG/$repo_name ==="

    (
        cd "$path"

        # Initialize git if needed
        if [ ! -d .git ]; then
            git init -b "$BRANCH"
        fi

        git config user.name "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.github.com"

        git add -A

        # Construct commit message
        local commit_msg="[$tree_type]: $brand $codename: Initial tree for LineageOS / AOSP"
        commit_msg="$commit_msg"$'\n\n'"Generated automatically by Universal Firmware Extractor"
        commit_msg="$commit_msg"$'\n'"Target: $brand/$codename"
        commit_msg="$commit_msg"$'\n'"Date: $(date -u)"

        if git diff --cached --quiet 2>/dev/null; then
            echo "[INFO] Working tree clean; nothing new to commit."
        else
            git commit -m "$commit_msg"
        fi

        if [ "$DRY_RUN" = true ]; then
            echo "[DRY-RUN] Target Repository: https://github.com/$TARGET_ORG/$repo_name"
            echo "[DRY-RUN] Branch:            $BRANCH"
            echo "[DRY-RUN] Commit:            $(git rev-parse HEAD 2>/dev/null || echo 'initial')"
            return 0
        fi

        # Remote push logic
        if [ -z "$AUTH_TOKEN" ]; then
            echo "[WARN] No GitHub Token supplied; cannot push to remote."
            return 0
        fi

        REMOTE_URL="https://x-access-token:${AUTH_TOKEN}@github.com/${TARGET_ORG}/${repo_name}.git"

        # If gh CLI is available, check or create repo
        if command -v gh >/dev/null 2>&1; then
            export GH_TOKEN="$AUTH_TOKEN"
            if ! gh repo view "$TARGET_ORG/$repo_name" >/dev/null 2>&1; then
                echo "[INFO] Creating GitHub repository: $TARGET_ORG/$repo_name..."
                gh repo create "$TARGET_ORG/$repo_name" --public --confirm || true
            fi
        else
            # Try GitHub REST API to create repository if it does not exist
            echo "[INFO] Checking/Creating repository via GitHub API..."
            curl -s -H "Authorization: token $AUTH_TOKEN" \
                 -d "{\"name\": \"$repo_name\", \"private\": false}" \
                 "https://api.github.com/user/repos" >/dev/null 2>&1 || true
        fi

        git remote remove origin 2>/dev/null || true
        git remote add origin "$REMOTE_URL"

        echo "[INFO] Pushing $BRANCH to https://github.com/$TARGET_ORG/$repo_name..."
        git push -u origin "$BRANCH" --force || {
            echo "[ERROR] Failed pushing to $TARGET_ORG/$repo_name"
            return 1
        }
        echo "[SUCCESS] Pushed $repo_name successfully!"
    )
}

# Scan device trees
if [ -d "$TREES_DIR/device" ]; then
    for brand_dir in "$TREES_DIR/device"/*; do
        [ -d "$brand_dir" ] || continue
        brand=$(basename "$brand_dir")
        for code_dir in "$brand_dir"/*; do
            [ -d "$code_dir" ] || continue
            codename=$(basename "$code_dir")
            upload_tree "device" "$brand" "$codename" "$code_dir"
        done
    done
fi

# Scan vendor trees
if [ -d "$TREES_DIR/vendor" ]; then
    for brand_dir in "$TREES_DIR/vendor"/*; do
        [ -d "$brand_dir" ] || continue
        brand=$(basename "$brand_dir")
        for code_dir in "$brand_dir"/*; do
            [ -d "$code_dir" ] || continue
            codename=$(basename "$code_dir")
            upload_tree "vendor" "$brand" "$codename" "$code_dir"
        done
    done
fi

# Handle dump release upload if specified
if [ -n "$RELEASE_DUMP" ] && [ -f "$RELEASE_DUMP" ]; then
    echo ""
    echo "=== [3/3] Uploading Firmware Dump Release ==="
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Release file: $RELEASE_DUMP"
    elif command -v gh >/dev/null 2>&1 && [ -n "$AUTH_TOKEN" ]; then
        TAG_NAME="dump-$(date +%Y%m%d-%H%M)"
        gh release create "$TAG_NAME" "$RELEASE_DUMP" --title "Firmware Dump $TAG_NAME" --notes "Extracted firmware partitions and assets." || true
    fi
fi

echo "=== GitHub Upload Process Finished! ==="
