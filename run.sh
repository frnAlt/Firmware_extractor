#!/usr/bin/env bash
# ==============================================================================
# Universal Firmware Extractor, GitHub Dump Pusher & Multi-ROM Tree Generator
# Master Orchestrator Entrypoint
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If Python 3 is installed with main.py, delegate directly
if command -v python3 >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/main.py" ]; then
    exec python3 "$SCRIPT_DIR/main.py" "$@"
fi

# Fallback Bash implementation
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Input Options:
  -u, --url <URL>            Firmware URL (direct, Google Drive, SourceForge, AFH)
  -f, --file <PATH>          Path to local stock firmware archive or image file
  -d, --dump-dir <PATH>      Use an already extracted filesystem dump directory

Generation & Deployment Options:
  -o, --out <DIR>            Output root directory (default: out/)
      --rom-type <TYPE>      Target Custom ROM (lineageos, pixelos, crdroid, evolutionx, twrp, all)
      --no-trees             Skip AOSP & LineageOS device/vendor tree generation
      --push-github          Automatically create/push device & vendor trees to GitHub
      --target-org <USER>    Target GitHub user or organization
      --token <TOKEN>        GitHub personal access token (GH_TOKEN or GITHUB_TOKEN)
      --branch <BRANCH>      Git branch for trees (default: lineage-21.0)
      --dry-run              Dry run mode for GitHub operations (no actual network push)
  -h, --help                 Show this help menu
EOF
}

show_help
