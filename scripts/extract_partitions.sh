#!/usr/bin/env bash
# ==============================================================================
# Universal Partition Filesystem Unpacker
# Extracts EROFS, EXT4, F2FS images and Boot/Recovery images into directories
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$REPO_ROOT/tools"

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [IMAGES_DIR] [DUMP_DIR]

Options:
  -i, --images <DIR>     Directory containing partition .img files (default: out/images).
  -d, --dump <DIR>       Destination directory for extracted filesystems (default: out/dump).
  -h, --help             Show this help message.

Examples:
  $0 out/images out/dump
  $0 -i /path/to/images -d /path/to/dump
EOF
}

IMAGES_DIR="$REPO_ROOT/out/images"
DUMP_DIR="$REPO_ROOT/out/dump"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -i|--images)
            IMAGES_DIR="$2"
            shift 2
            ;;
        -d|--dump)
            DUMP_DIR="$2"
            shift 2
            ;;
        *)
            if [ "$IMAGES_DIR" = "$REPO_ROOT/out/images" ]; then
                IMAGES_DIR="$1"
            elif [ "$DUMP_DIR" = "$REPO_ROOT/out/dump" ]; then
                DUMP_DIR="$1"
            fi
            shift
            ;;
    esac
done

if [ ! -d "$IMAGES_DIR" ]; then
    echo "[ERROR] Images directory does not exist: $IMAGES_DIR"
    exit 1
fi

mkdir -p "$DUMP_DIR"

echo "=== [1/2] Unpacking Filesystem Partitions ==="

# Locate extraction binaries
FSCK_EROFS="$TOOLS_DIR/fsck.erofs"
if [ ! -x "$FSCK_EROFS" ] && command -v fsck.erofs >/dev/null 2>&1; then
    FSCK_EROFS=$(command -v fsck.erofs)
fi

EXT2RD="$TOOLS_DIR/ext2rd"
UNPACKBOOTIMG="$TOOLS_DIR/unpackbootimg"

for img in "$IMAGES_DIR"/*.img; do
    [ -e "$img" ] || continue
    partition_name=$(basename "$img" .img)
    target_dir="$DUMP_DIR/$partition_name"

    # Skip vbmeta and non-filesystem raw metadata for filesystem unpacking
    if [[ "$partition_name" =~ ^vbmeta ]] || [[ "$partition_name" =~ ^dtbo ]]; then
        mkdir -p "$target_dir"
        cp "$img" "$target_dir/"
        continue
    fi

    echo "[INFO] Processing partition: $partition_name ($(du -h "$img" | cut -f1))"
    mkdir -p "$target_dir"

    # Detect image format
    FILE_INFO=$(file -b "$img" 2>/dev/null || true)
    MAGIC_HEAD=$(head -c 8 "$img" 2>/dev/null || true)

    # 1. Android Boot Image (boot, vendor_boot, recovery, init_boot)
    if [[ "$MAGIC_HEAD" =~ ^ANDROID! ]] || [[ "$partition_name" =~ ^(boot|vendor_boot|recovery|init_boot)$ ]]; then
        echo "  -> Android Boot image detected"
        BOOT_EXT_DIR="$target_dir"

        if [ -x "$UNPACKBOOTIMG" ]; then
            "$UNPACKBOOTIMG" -i "$img" -o "$BOOT_EXT_DIR" 2>/dev/null || true
        elif command -v unpackbootimg >/dev/null 2>&1; then
            unpackbootimg -i "$img" -o "$BOOT_EXT_DIR" 2>/dev/null || true
        fi

        # If ramdisk exists, unpack ramdisk
        for ramdisk in "$BOOT_EXT_DIR"/*ramdisk*; do
            if [ -f "$ramdisk" ]; then
                RAMDISK_DIR="$BOOT_EXT_DIR/ramdisk"
                mkdir -p "$RAMDISK_DIR"
                (
                    cd "$RAMDISK_DIR"
                    # Handle lz4, gzip, cpio
                    if file -b "$ramdisk" | grep -qi "gzip"; then
                        gzip -dc "$ramdisk" | cpio -idm 2>/dev/null || true
                    elif file -b "$ramdisk" | grep -qi "lz4"; then
                        lz4 -dc "$ramdisk" | cpio -idm 2>/dev/null || true
                    else
                        cpio -idm < "$ramdisk" 2>/dev/null || true
                    fi
                )
            fi
        done

        # If dtb present or kernel image, run extract-dtb
        if command -v extract-dtb >/dev/null 2>&1; then
            DTB_OUT="$BOOT_EXT_DIR/dtb_extracted"
            extract-dtb "$img" -o "$DTB_OUT" 2>/dev/null || true
        fi
        continue
    fi

    # 2. Check for EROFS
    # Magic at offset 1024 is 0xe0f5e1e2
    EROFS_MAGIC=$(od -A n -X -j 1024 -N 4 "$img" 2>/dev/null | tr -d ' ' || true)
    if [ "$EROFS_MAGIC" = "e0f5e1e2" ] || echo "$FILE_INFO" | grep -qi "erofs"; then
        echo "  -> EROFS filesystem detected. Extracting..."
        if [ -x "$FSCK_EROFS" ]; then
            "$FSCK_EROFS" --extract="$target_dir" "$img" >/dev/null 2>&1 || true
        else
            echo "  [WARN] fsck.erofs not available; attempting 7z fallback"
            7z x -y "$img" -o"$target_dir" >/dev/null 2>&1 || true
        fi
        continue
    fi

    # 3. Check for EXT4
    # Magic at offset 1080 is 0xef53
    EXT4_MAGIC=$(od -A n -x -j 1080 -N 2 "$img" 2>/dev/null | tr -d ' ' || true)
    if [ "$EXT4_MAGIC" = "ef53" ] || echo "$FILE_INFO" | grep -qi "ext[234]"; then
        echo "  -> EXT4 filesystem detected. Extracting..."
        7z x -y "$img" -o"$target_dir" >/dev/null 2>&1 || {
            if [ -x "$EXT2RD" ]; then
                "$EXT2RD" "$img" .:"$target_dir" >/dev/null 2>&1 || true
            fi
        }
        continue
    fi

    # 4. Fallback extraction (7z / archive uncompress)
    echo "  -> Generic extraction via 7z..."
    7z x -y "$img" -o"$target_dir" >/dev/null 2>&1 || true
done

echo "=== [2/2] Filesystem Extraction Summary ==="
for dir in "$DUMP_DIR"/*; do
    if [ -d "$dir" ]; then
        echo "  [Extracted] $(basename "$dir"): $(find "$dir" -type f | wc -l) files ($(du -sh "$dir" | cut -f1))"
    fi
done

echo "=== Filesystem Unpacking Complete! Output located at $DUMP_DIR ==="
