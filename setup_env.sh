#!/usr/bin/env bash
# ==============================================================================
# Firmware Extractor & AOSP Tree Generator - Toolchain Setup Script
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/tools"

echo "=== [1/4] Checking System & Package Manager ==="
if [ -f /etc/debian_version ]; then
    echo "[INFO] Debian/Ubuntu detected."
    PKG_MGR="apt-get"
    PKGS=(
        p7zip-full p7zip-rar unrar zip unzip sharutils rar uudeview mpack arj cabextract
        rename liblzma-dev python3 python3-pip python3-dev brotli lz4
        protobuf-compiler git gawk aria2 curl wget file device-tree-compiler
        libbrotli-dev liblz4-tool erofs-utils
    )

    SUDO_CMD=""
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            SUDO_CMD="sudo"
        else
            echo "[WARN] Not running as root and sudo not found. Trying without sudo..."
        fi
    fi

    if [ "${SKIP_SYS_INSTALL:-0}" != "1" ]; then
        echo "[INFO] Updating repositories and installing package dependencies..."
        $SUDO_CMD $PKG_MGR update -y || true
        $SUDO_CMD $PKG_MGR install -y "${PKGS[@]}" || {
            echo "[WARN] Some system packages failed to install; continuing..."
        }
    fi
else
    echo "[WARN] Non-Debian system detected. Please ensure 7z, lz4, brotli, erofs-utils, and python3 are installed."
fi

echo "=== [2/4] Setting Permissions on Internal Tools ==="
if [ -d "$TOOLS_DIR" ]; then
    chmod -R +x "$TOOLS_DIR" 2>/dev/null || true
    echo "[INFO] Internal binaries in $TOOLS_DIR set to executable."
fi

echo "=== [3/4] Installing Python Toolchain ==="
PYTHON_BIN="python3"
if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
fi

if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
    echo "[INFO] Installing Python requirements via $PYTHON_BIN..."
    $PYTHON_BIN -m pip install --upgrade pip 2>/dev/null || true
    $PYTHON_BIN -m pip install -r "$SCRIPT_DIR/requirements.txt" --break-system-packages 2>/dev/null || \
    $PYTHON_BIN -m pip install -r "$SCRIPT_DIR/requirements.txt" || {
        echo "[WARN] Standard pip install encountered issues; attempting user install..."
        $PYTHON_BIN -m pip install --user -r "$SCRIPT_DIR/requirements.txt"
    }
fi

echo "=== [4/4] Verifying Toolchain Status ==="
CHECK_TOOLS=(python3 7z lz4 brotli)
ALL_OK=true
for tool in "${CHECK_TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "  [OK] $tool: $(command -v "$tool")"
    else
        echo "  [FAIL] $tool is missing"
        ALL_OK=false
    fi
done

if [ -f "$TOOLS_DIR/lpunpack" ]; then
    echo "  [OK] lpunpack present in tools"
fi
if [ -f "$TOOLS_DIR/payload-dumper-go" ]; then
    echo "  [OK] payload-dumper-go present in tools"
fi

if [ "$ALL_OK" = true ]; then
    echo "=== Environment Setup Complete! Ready to extract and generate trees. ==="
else
    echo "=== [WARN] Setup finished with some warnings. Please inspect above messages. ==="
fi
