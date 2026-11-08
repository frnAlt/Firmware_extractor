#!/usr/bin/env bash
# ==============================================================================
# Universal Firmware Extractor Engine
# Supports: payload.bin, super.img, TAR.MD5, OZIP, OFP, PAC, KDZ, RAW/Sparse images
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$REPO_ROOT/tools"

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] <FIRMWARE_FILE_OR_URL> [OUTPUT_DIR]

Options:
  -u, --url <URL>        Firmware direct URL, Google Drive, SourceForge, etc.
  -f, --file <FILE>      Path to local firmware archive or image file.
  -o, --out <DIR>        Output directory for extracted partition images (default: out/images).
  -w, --work <DIR>       Temporary working directory (default: work/).
  -k, --keep-work        Keep temporary files after extraction.
  -h, --help             Show this help message.

Examples:
  $0 https://example.com/firmware.zip out/images
  $0 -f stock_rom.tar.md5 -o out/images
  $0 payload.bin out/images
EOF
}

FIRMWARE_INPUT=""
OUTPUT_DIR="$REPO_ROOT/out/images"
WORK_DIR="$REPO_ROOT/work"
KEEP_WORK=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--url)
            FIRMWARE_INPUT="$2"
            shift 2
            ;;
        -f|--file)
            FIRMWARE_INPUT="$2"
            shift 2
            ;;
        -o|--out)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -w|--work)
            WORK_DIR="$2"
            shift 2
            ;;
        -k|--keep-work)
            KEEP_WORK=true
            shift
            ;;
        *)
            if [ -z "$FIRMWARE_INPUT" ]; then
                FIRMWARE_INPUT="$1"
            elif [ "$OUTPUT_DIR" = "$REPO_ROOT/out/images" ]; then
                OUTPUT_DIR="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$FIRMWARE_INPUT" ]; then
    echo "[ERROR] No firmware file or URL specified."
    show_help
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
mkdir -p "$WORK_DIR"

cleanup() {
    if [ "$KEEP_WORK" = false ] && [ -d "$WORK_DIR" ]; then
        echo "[INFO] Cleaning up working directory: $WORK_DIR"
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT

# ------------------------------------------------------------------------------
# 1. Download if Input is a URL
# ------------------------------------------------------------------------------
download_firmware() {
    local url="$1"
    local dest_dir="$2"
    local target_file=""

    echo "=== [Step 1/3] Downloading Firmware from URL ==="
    echo "[INFO] URL: $url"

    if [[ "$url" =~ drive\.google\.com ]]; then
        echo "[INFO] Google Drive link detected."
        local file_id=""
        if [[ "$url" =~ id=([a-zA-Z0-9_-]+) ]]; then
            file_id="${BASH_REMATCH[1]}"
        elif [[ "$url" =~ /d/([a-zA-Z0-9_-]+) ]]; then
            file_id="${BASH_REMATCH[1]}"
        fi

        target_file="$dest_dir/gdrive_firmware.zip"
        if command -v gdown >/dev/null 2>&1; then
            gdown "$url" -O "$target_file" || true
        else
            local confirm_token
            confirm_token=$(curl -sc /tmp/gcookie "https://drive.google.com/uc?export=download&id=${file_id}" | grep -o 'confirm=[^&]*' | sed 's/confirm=//' || true)
            if [ -n "$confirm_token" ]; then
                curl -Lb /tmp/gcookie "https://drive.google.com/uc?export=download&confirm=${confirm_token}&id=${file_id}" -o "$target_file"
            else
                curl -Lb /tmp/gcookie "https://drive.google.com/uc?export=download&id=${file_id}" -o "$target_file"
            fi
            rm -f /tmp/gcookie
        fi
    else
        target_file="$dest_dir/firmware_archive"
        if command -v aria2c >/dev/null 2>&1; then
            echo "[INFO] Using aria2c for accelerated download..."
            aria2c -x 16 -s 16 -j 4 -d "$dest_dir" -o "downloaded_firmware" "$url" || {
                echo "[WARN] aria2c download failed; falling back to curl..."
                curl -L -C - --retry 3 -o "$target_file" "$url"
            }
            if [ -f "$dest_dir/downloaded_firmware" ]; then
                target_file="$dest_dir/downloaded_firmware"
            fi
        else
            echo "[INFO] Using curl for download..."
            curl -L -C - --retry 3 -o "$target_file" "$url"
        fi
    fi

    echo "$target_file"
}

ARCHIVE_PATH="$FIRMWARE_INPUT"
if [[ "$FIRMWARE_INPUT" =~ ^https?:// ]] || [[ "$FIRMWARE_INPUT" =~ ^ftp:// ]]; then
    ARCHIVE_PATH=$(download_firmware "$FIRMWARE_INPUT" "$WORK_DIR")
fi

if [ ! -f "$ARCHIVE_PATH" ]; then
    echo "[ERROR] Firmware file does not exist: $ARCHIVE_PATH"
    exit 1
fi

echo "=== [Step 2/3] Analyzing Firmware Archive Type ==="
echo "[INFO] Input file: $ARCHIVE_PATH ($(du -h "$ARCHIVE_PATH" | cut -f1))"

# ------------------------------------------------------------------------------
# 2. Extract Archive Containers
# ------------------------------------------------------------------------------
extract_container() {
    local file="$1"
    local dest="$2"

    cd "$dest"

    # Direct payload.bin
    if [[ "$(basename "$file")" == "payload.bin" ]]; then
        echo "[INFO] Direct payload.bin detected."
        if [ -x "$TOOLS_DIR/payload-dumper-go" ]; then
            "$TOOLS_DIR/payload-dumper-go" -o "$dest" "$file"
        elif [ -x "$TOOLS_DIR/otadump" ]; then
            "$TOOLS_DIR/otadump" --output-dir "$dest" "$file"
        fi
        return 0
    fi

    # Check archive content with 7z listing
    local contents
    contents=$(7z l -ba "$file" 2>/dev/null || true)

    # 1. Archive containing payload.bin
    if echo "$contents" | grep -q "payload\.bin"; then
        echo "[INFO] payload.bin found inside archive."
        7z e -y "$file" "payload.bin" -o"$dest" >/dev/null 2>&1
        if [ -f "$dest/payload.bin" ]; then
            if [ -x "$TOOLS_DIR/payload-dumper-go" ]; then
                "$TOOLS_DIR/payload-dumper-go" -o "$dest" "$dest/payload.bin"
            elif [ -x "$TOOLS_DIR/otadump" ]; then
                "$TOOLS_DIR/otadump" --output-dir "$dest" "$dest/payload.bin"
            fi
            rm -f "$dest/payload.bin"
            return 0
        fi
    fi

    # 2. Samsung TAR.MD5 or TAR
    if [[ "$file" =~ \.tar\.md5$ ]] || [[ "$file" =~ \.tar$ ]] || echo "$contents" | grep -q "\.lz4"; then
        echo "[INFO] Samsung tar/lz4 container detected."
        tar -xf "$file" -C "$dest" 2>/dev/null || 7z x -y "$file" -o"$dest" >/dev/null 2>&1 || true
        for lz in "$dest"/*.lz4; do
            if [ -f "$lz" ]; then
                echo "[INFO] Decompressing $(basename "$lz")..."
                lz4 -dc "$lz" > "${lz%.lz4}" 2>/dev/null || true
                rm -f "$lz"
            fi
        done
        return 0
    fi

    # 3. Unisoc PAC
    if [[ "$file" =~ \.pac$ ]] || echo "$contents" | grep -q "\.pac$"; then
        echo "[INFO] Unisoc PAC container detected."
        local pac_file="$file"
        if echo "$contents" | grep -q "\.pac$"; then
            7z e -y "$file" "*.pac" -o"$dest" >/dev/null 2>&1
            pac_file=$(find "$dest" -name "*.pac" | head -n 1)
        fi
        if [ -f "$pac_file" ] && [ -f "$TOOLS_DIR/pacExtractor.py" ]; then
            python3 "$TOOLS_DIR/pacExtractor.py" "$pac_file" "$dest" || true
        fi
        return 0
    fi

    # 4. OPPO/Realme OZIP
    if [[ "$file" =~ \.ozip$ ]]; then
        echo "[INFO] OPPO/Realme OZIP detected."
        if [ -d "$TOOLS_DIR/keyfiles" ]; then
            python3 "$REPO_ROOT/extractor.sh" "$file" "$dest" || true
            return 0
        fi
    fi

    # 5. Generic 7z / ZIP / RAR / GZ extraction
    echo "[INFO] Performing generic multi-archive extraction..."
    7z x -y "$file" -o"$dest" >/dev/null 2>&1 || true

    # Check for inner zips or tarballs
    for inner in "$dest"/*.zip "$dest"/*.tar "$dest"/*.tar.md5 "$dest"/*.tgz; do
        if [ -f "$inner" ] && [ "$(stat -c%s "$inner" 2>/dev/null || stat -f%z "$inner")" -gt 50000000 ]; then
            echo "[INFO] Unpacking nested archive: $(basename "$inner")"
            extract_container "$inner" "$dest"
            rm -f "$inner"
        fi
    done
}

extract_container "$ARCHIVE_PATH" "$WORK_DIR"

# ------------------------------------------------------------------------------
# 3. Handle super.img and Dynamic Partitions
# ------------------------------------------------------------------------------
echo "=== [Step 3/3] Processing Partitions & Dynamic Images ==="

SUPER_IMG=$(find "$WORK_DIR" -maxdepth 2 -type f -name "super.img" | head -n 1)
if [ -n "$SUPER_IMG" ] && [ -f "$SUPER_IMG" ]; then
    echo "[INFO] Dynamic super.img partition detected at $SUPER_IMG"
    SUPER_RAW="$WORK_DIR/super.raw"

    # Check if sparse
    MAGIC=$(od -A n -X -j 0 -N 4 "$SUPER_IMG" 2>/dev/null | tr -d ' ' || true)
    if [ "$MAGIC" = "ed26ff3a" ]; then
        echo "[INFO] super.img is sparse; unsparsing via simg2img..."
        if [ -x "$TOOLS_DIR/simg2img" ]; then
            "$TOOLS_DIR/simg2img" "$SUPER_IMG" "$SUPER_RAW"
        elif command -v simg2img >/dev/null 2>&1; then
            simg2img "$SUPER_IMG" "$SUPER_RAW"
        else
            cp "$SUPER_IMG" "$SUPER_RAW"
        fi
    else
        echo "[INFO] super.img is already raw."
        mv "$SUPER_IMG" "$SUPER_RAW"
    fi

    if [ -f "$SUPER_RAW" ]; then
        echo "[INFO] Unpacking dynamic partitions using lpunpack..."
        LPUNPACK_BIN="$TOOLS_DIR/lpunpack"
        if [ ! -x "$LPUNPACK_BIN" ] && command -v lpunpack >/dev/null 2>&1; then
            LPUNPACK_BIN=$(command -v lpunpack)
        fi

        if [ -x "$LPUNPACK_BIN" ]; then
            "$LPUNPACK_BIN" "$SUPER_RAW" "$WORK_DIR" 2>/dev/null || true
        fi
        rm -f "$SUPER_RAW"
    fi
fi

# Move all resulting partition images to OUTPUT_DIR
TARGET_PARTITIONS=(
    system vendor product system_ext odm odm_ext oem cust
    boot vendor_boot recovery dtbo vbmeta vbmeta_system vbmeta_vendor
    init_boot vendor_dlkm system_dlkm
)

# Collect slot-suffixed partitions (_a, _b) and normalize
for img in "$WORK_DIR"/*.img; do
    if [ -f "$img" ]; then
        base=$(basename "$img" .img)
        # Handle slot suffix: system_a -> system
        clean_name="${base%_a}"
        clean_name="${clean_name%_b}"

        # If sparse image, unsparse it first
        MAGIC=$(od -A n -X -j 0 -N 4 "$img" 2>/dev/null | tr -d ' ' || true)
        if [ "$MAGIC" = "ed26ff3a" ]; then
            echo "[INFO] Unsparsing $(basename "$img")..."
            if [ -x "$TOOLS_DIR/simg2img" ]; then
                "$TOOLS_DIR/simg2img" "$img" "$OUTPUT_DIR/${clean_name}.img" 2>/dev/null || mv "$img" "$OUTPUT_DIR/${clean_name}.img"
            elif command -v simg2img >/dev/null 2>&1; then
                simg2img "$img" "$OUTPUT_DIR/${clean_name}.img" 2>/dev/null || mv "$img" "$OUTPUT_DIR/${clean_name}.img"
            else
                mv "$img" "$OUTPUT_DIR/${clean_name}.img"
            fi
            rm -f "$img"
        else
            mv "$img" "$OUTPUT_DIR/${clean_name}.img"
        fi
    fi
done

echo "=== Extraction Complete! Images available in $OUTPUT_DIR: ==="
ls -lh "$OUTPUT_DIR"/*.img 2>/dev/null || echo "[WARN] No .img files found."
