#!/usr/bin/env bash
# ==============================================================================
# Universal Firmware Extractor & AOSP Tree Generator - Master Orchestrator
# Automates: Firmware Download -> Extraction -> Partition Unpack -> Tree Gen -> GitHub Push
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$SCRIPT_DIR/scripts"

show_help() {
    cat <<EOF
================================================================================
Universal Firmware Extractor & AOSP/LineageOS Device Tree Generator
================================================================================
Usage: $0 [OPTIONS]

Input Options (Choose one):
  -u, --url <URL>            Direct firmware URL, Google Drive, SourceForge, AFH, etc.
  -f, --file <PATH>          Path to local stock firmware archive or image file.
  -d, --dump-dir <PATH>      Use an already extracted filesystem dump directory.

Generation & Deployment Options:
  -o, --out <DIR>            Output root directory (default: out/).
      --no-trees             Skip AOSP & LineageOS device/vendor tree generation.
      --push-github          Automatically create/push device & vendor trees to GitHub.
      --target-org <USER>    Target GitHub user or organization.
      --token <TOKEN>        GitHub personal access token (GH_TOKEN or GITHUB_TOKEN).
      --branch <BRANCH>      Git branch for trees (default: lineage-21.0).
      --dry-run              Dry run mode for GitHub operations (no actual network push).
  -h, --help                 Show this help menu.

Examples:
  1. Full pipeline from firmware URL:
     $0 --url "https://example.com/firmware.zip" --push-github --target-org "mygithub"

  2. Extract local firmware archive:
     $0 --file stock_firmware.tar.md5

  3. Generate trees from an existing dump:
     $0 --dump-dir out/dump --out out/
================================================================================
EOF
}

FIRMWARE_URL=""
FIRMWARE_FILE=""
DUMP_DIR=""
OUT_DIR="$SCRIPT_DIR/out"
GENERATE_TREES=true
PUSH_GITHUB=false
TARGET_ORG="${GITHUB_ACTOR:-}"
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
BRANCH="lineage-21.0"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--url)
            FIRMWARE_URL="$2"
            shift 2
            ;;
        -f|--file)
            FIRMWARE_FILE="$2"
            shift 2
            ;;
        -d|--dump-dir)
            DUMP_DIR="$2"
            shift 2
            ;;
        -o|--out)
            OUT_DIR="$2"
            shift 2
            ;;
        --no-trees)
            GENERATE_TREES=false
            shift
            ;;
        --push-github)
            PUSH_GITHUB=true
            shift
            ;;
        --target-org)
            TARGET_ORG="$2"
            shift 2
            ;;
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            if [ -z "$FIRMWARE_FILE" ] && [ -f "$1" ]; then
                FIRMWARE_FILE="$1"
            elif [ -z "$FIRMWARE_URL" ] && [[ "$1" =~ ^https?:// ]]; then
                FIRMWARE_URL="$1"
            fi
            shift
            ;;
    esac
done

# If no input provided, show help
if [ -z "$FIRMWARE_URL" ] && [ -z "$FIRMWARE_FILE" ] && [ -z "$DUMP_DIR" ]; then
    echo "[ERROR] No input specified. Please provide --url, --file, or --dump-dir."
    echo ""
    show_help
    exit 1
fi

IMAGES_DIR="$OUT_DIR/images"
TARGET_DUMP_DIR="${DUMP_DIR:-$OUT_DIR/dump}"
TREES_DIR="$OUT_DIR/trees"

echo "================================================================================"
echo "    Universal Firmware Extractor & AOSP Tree Generator Pipeline"
echo "================================================================================"
echo " Output Directory: $OUT_DIR"
echo " Mode:             Trees Enabled: $GENERATE_TREES | Push to GitHub: $PUSH_GITHUB"
echo "================================================================================"

# ------------------------------------------------------------------------------
# Stage 1: Extraction & Partition Unpacking
# ------------------------------------------------------------------------------
if [ -z "$DUMP_DIR" ]; then
    mkdir -p "$IMAGES_DIR"
    mkdir -p "$TARGET_DUMP_DIR"

    INPUT_TARGET="${FIRMWARE_FILE:-$FIRMWARE_URL}"
    echo ""
    echo ">>> [STAGE 1/3] Extracting Firmware Archives & Images..."
    "$SCRIPTS/extract_firmware.sh" "$INPUT_TARGET" "$IMAGES_DIR"

    echo ""
    echo ">>> [STAGE 2/3] Unpacking Partition Filesystems (EROFS/EXT4/Boot)..."
    "$SCRIPTS/extract_partitions.sh" "$IMAGES_DIR" "$TARGET_DUMP_DIR"
else
    echo "[INFO] Using existing filesystem dump directory: $TARGET_DUMP_DIR"
fi

# ------------------------------------------------------------------------------
# Stage 2: AOSP & LineageOS Tree Generation
# ------------------------------------------------------------------------------
if [ "$GENERATE_TREES" = true ]; then
    echo ""
    echo ">>> [STAGE 3/3] Generating AOSP & LineageOS Device and Vendor Trees..."
    "$SCRIPTS/generate_trees.sh" "$TARGET_DUMP_DIR" "$TREES_DIR"
fi

# ------------------------------------------------------------------------------
# Stage 3: GitHub Deployment
# ------------------------------------------------------------------------------
if [ "$PUSH_GITHUB" = true ] || [ "$DRY_RUN" = true ]; then
    echo ""
    echo ">>> [DEPLOYMENT] Uploading Generated Trees to GitHub..."
    UPLOAD_ARGS=(
        --trees-dir "$TREES_DIR"
        --target-org "$TARGET_ORG"
        --branch "$BRANCH"
    )
    if [ -n "$TOKEN" ]; then
        UPLOAD_ARGS+=(--token "$TOKEN")
    fi
    if [ "$DRY_RUN" = true ]; then
        UPLOAD_ARGS+=(--dry-run)
    fi

    "$SCRIPTS/upload_github.sh" "${UPLOAD_ARGS[@]}"
fi

echo ""
echo "================================================================================"
echo " Pipeline Complete!"
echo " Extracted Dump:   $TARGET_DUMP_DIR"
if [ "$GENERATE_TREES" = true ]; then
    echo " Generated Trees:  $TREES_DIR"
fi
echo "================================================================================"
