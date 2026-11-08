#!/usr/bin/env bash
# ==============================================================================
# AOSP & LineageOS Device & Vendor Tree Generator
# Generates bootable device tree, vendor tree, and proprietary-files list
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [DUMP_DIR] [TREES_OUT_DIR]

Options:
  -d, --dump <DIR>       Extracted filesystem dump directory (default: out/dump).
  -o, --out <DIR>        Destination directory for generated trees (default: out/trees).
  -h, --help             Show this help message.

Examples:
  $0 out/dump out/trees
  $0 -d /path/to/dump -o /path/to/trees
EOF
}

DUMP_DIR="$REPO_ROOT/out/dump"
TREES_OUT_DIR="$REPO_ROOT/out/trees"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dump)
            DUMP_DIR="$2"
            shift 2
            ;;
        -o|--out)
            TREES_OUT_DIR="$2"
            shift 2
            ;;
        *)
            if [ "$DUMP_DIR" = "$REPO_ROOT/out/dump" ]; then
                DUMP_DIR="$1"
            elif [ "$TREES_OUT_DIR" = "$REPO_ROOT/out/trees" ]; then
                TREES_OUT_DIR="$1"
            fi
            shift
            ;;
    esac
done

if [ ! -d "$DUMP_DIR" ]; then
    echo "[ERROR] Dump directory does not exist: $DUMP_DIR"
    exit 1
fi

mkdir -p "$TREES_OUT_DIR"

echo "=== [1/5] Extracting Device Identity & Properties ==="
PROP_PARSER="$SCRIPT_DIR/prop_parser.py"
if [ ! -f "$PROP_PARSER" ]; then
    echo "[ERROR] prop_parser.py not found at $PROP_PARSER"
    exit 1
fi

PROP_ENV=$(python3 "$PROP_PARSER" "$DUMP_DIR" --shell)
eval "$PROP_ENV"

echo "[INFO] Brand:            $BRAND"
echo "[INFO] Codename:         $CODENAME"
echo "[INFO] Model:            $MODEL"
echo "[INFO] Platform:         $PLATFORM"
echo "[INFO] Android Version:  $ANDROID_VERSION"
echo "[INFO] Security Patch:   $SECURITY_PATCH"
echo "[INFO] Fingerprint:      $FINGERPRINT"

DEVICE_DIR="$TREES_OUT_DIR/device/$BRAND/$CODENAME"
VENDOR_DIR="$TREES_OUT_DIR/vendor/$BRAND/$CODENAME"
mkdir -p "$DEVICE_DIR"
mkdir -p "$VENDOR_DIR/proprietary"
mkdir -p "$DEVICE_DIR/overlay"
mkdir -p "$DEVICE_DIR/rootdir/etc"
mkdir -p "$DEVICE_DIR/prebuilt"
mkdir -p "$DEVICE_DIR/sepolicy/vendor"

echo "=== [2/5] Synthesizing AOSP/LineageOS Device Tree ==="

# ------------------------------------------------------------------------------
# 1. AndroidProducts.mk
# ------------------------------------------------------------------------------
cat <<EOF > "$DEVICE_DIR/AndroidProducts.mk"
#
# Copyright (C) $(date +%Y) The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

PRODUCT_MAKEFILES := \\
    \$(LOCAL_DIR)/lineage_${CODENAME}.mk \\
    \$(LOCAL_DIR)/aosp_${CODENAME}.mk

COMMON_LUNCH_CHOICES := \\
    lineage_${CODENAME}-user \\
    lineage_${CODENAME}-userdebug \\
    lineage_${CODENAME}-eng \\
    aosp_${CODENAME}-userdebug
EOF

# ------------------------------------------------------------------------------
# 2. lineage_<codename>.mk & aosp_<codename>.mk
# ------------------------------------------------------------------------------
cat <<EOF > "$DEVICE_DIR/lineage_${CODENAME}.mk"
#
# Copyright (C) $(date +%Y) The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
\$(call inherit-product, \$(SRC_TARGET_DIR)/product/core_64_bit.mk)
\$(call inherit-product, \$(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from ${CODENAME} device
\$(call inherit-product, device/${BRAND}/${CODENAME}/device.mk)

# Inherit some common Lineage stuff.
\$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_${CODENAME}
PRODUCT_DEVICE := ${CODENAME}
PRODUCT_MANUFACTURER := ${BRAND}
PRODUCT_BRAND := ${BRAND}
PRODUCT_MODEL := ${MODEL}

PRODUCT_GMS_CLIENTID_BASE := android-${BRAND}

PRODUCT_BUILD_PROP_OVERRIDES += \\
    PRODUCT_NAME=${NAME} \\
    TARGET_DEVICE=${CODENAME} \\
    BUILD_FINGERPRINT="${FINGERPRINT}"
EOF

cat <<EOF > "$DEVICE_DIR/aosp_${CODENAME}.mk"
#
# Copyright (C) $(date +%Y) The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

\$(call inherit-product, \$(SRC_TARGET_DIR)/product/core_64_bit.mk)
\$(call inherit-product, \$(SRC_TARGET_DIR)/product/full_base_telephony.mk)
\$(call inherit-product, device/${BRAND}/${CODENAME}/device.mk)

PRODUCT_NAME := aosp_${CODENAME}
PRODUCT_DEVICE := ${CODENAME}
PRODUCT_MANUFACTURER := ${BRAND}
PRODUCT_BRAND := ${BRAND}
PRODUCT_MODEL := ${MODEL}
EOF

# ------------------------------------------------------------------------------
# 3. Dynamic Partitions & BoardConfig.mk
# ------------------------------------------------------------------------------
DYNAMIC_PARTITIONS_LIST=""
for p in system vendor product system_ext odm odm_ext cust; do
    if [ -d "$DUMP_DIR/$p" ]; then
        DYNAMIC_PARTITIONS_LIST="$DYNAMIC_PARTITIONS_LIST $p"
    fi
done
DYNAMIC_PARTITIONS_LIST=$(echo "$DYNAMIC_PARTITIONS_LIST" | xargs)

# Fallback partition list if none detected in dump directory
if [ -z "$DYNAMIC_PARTITIONS_LIST" ]; then
    DYNAMIC_PARTITIONS_LIST="system vendor product system_ext odm"
fi

UPPER_BRAND=$(echo "$BRAND" | tr '[:lower:]' '[:upper:]')

cat <<EOF > "$DEVICE_DIR/BoardConfig.mk"
#
# Copyright (C) $(date +%Y) The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/${BRAND}/${CODENAME}

# Target Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_VARIANT := generic

# Board / Platform
TARGET_BOARD_PLATFORM := ${PLATFORM}
BOARD_VENDOR := ${BRAND}

# Kernel
BOARD_KERNEL_PAGESIZE := 4096
BOARD_BOOT_HEADER_VERSION := 2
BOARD_KERNEL_CMDLINE := console=null androidboot.hardware=${PLATFORM}
TARGET_PREBUILT_KERNEL := \$(DEVICE_PATH)/prebuilt/kernel
TARGET_PREBUILT_DTB := \$(DEVICE_PATH)/prebuilt/dtb.img
BOARD_PREBUILT_DTBOIMAGE := \$(DEVICE_PATH)/prebuilt/dtbo.img

# Dynamic Partitions
BOARD_SUPER_PARTITION_SIZE := 9126805504
BOARD_SUPER_PARTITION_GROUPS := ${BRAND}_dynamic_partitions
BOARD_${UPPER_BRAND}_DYNAMIC_PARTITIONS_SIZE := 9122611200
BOARD_${UPPER_BRAND}_DYNAMIC_PARTITIONS_PARTITION_LIST := ${DYNAMIC_PARTITIONS_LIST}

# Filesystem & Partition Types
TARGET_USERIMAGES_USE_EXT4 := true
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_FLASH_BLOCK_SIZE := 262144

# SELinux
BOARD_VENDOR_SEPOLICY_DIRS += \$(DEVICE_PATH)/sepolicy/vendor

# Releasetools
TARGET_RELEASETOOLS_EXTENSIONS := \$(DEVICE_PATH)
EOF

# ------------------------------------------------------------------------------
# 4. Copying Prebuilt Kernel & DTB
# ------------------------------------------------------------------------------
# Check for kernel images in boot dump
for k in "$DUMP_DIR/boot/kernel" "$DUMP_DIR/boot/Image" "$DUMP_DIR/boot/Image.gz" "$DUMP_DIR/boot/zImage"; do
    if [ -f "$k" ]; then
        echo "[INFO] Found prebuilt kernel at $k"
        cp "$k" "$DEVICE_DIR/prebuilt/kernel"
        break
    fi
done

# If no kernel found, create dummy marker for compilation verification
if [ ! -f "$DEVICE_DIR/prebuilt/kernel" ]; then
    touch "$DEVICE_DIR/prebuilt/kernel"
fi

# Check for dtb or dtbo images
if [ -f "$DUMP_DIR/boot/dtb" ]; then
    cp "$DUMP_DIR/boot/dtb" "$DEVICE_DIR/prebuilt/dtb.img"
elif [ -f "$DUMP_DIR/boot/dtb.img" ]; then
    cp "$DUMP_DIR/boot/dtb.img" "$DEVICE_DIR/prebuilt/dtb.img"
else
    touch "$DEVICE_DIR/prebuilt/dtb.img"
fi

if [ -f "$DUMP_DIR/dtbo/dtbo.img" ]; then
    cp "$DUMP_DIR/dtbo/dtbo.img" "$DEVICE_DIR/prebuilt/dtbo.img"
elif [ -f "$DUMP_DIR/dtbo.img" ]; then
    cp "$DUMP_DIR/dtbo.img" "$DEVICE_DIR/prebuilt/dtbo.img"
else
    touch "$DEVICE_DIR/prebuilt/dtbo.img"
fi

# ------------------------------------------------------------------------------
# 5. Extract Fstab and Init Scripts
# ------------------------------------------------------------------------------
echo "=== [3/5] Inspecting Init and Fstab Mount Configurations ==="

FSTAB_COPY_FILES=""
# Search for fstab files in vendor/etc or ramdisk
FSTAB_FOUND=$(find "$DUMP_DIR" -name "fstab.*" 2>/dev/null || true)
for f in $FSTAB_FOUND; do
    if [ -f "$f" ]; then
        fname=$(basename "$f")
        cp "$f" "$DEVICE_DIR/rootdir/etc/$fname"
        FSTAB_COPY_FILES="$FSTAB_COPY_FILES\n    \$(DEVICE_PATH)/rootdir/etc/$fname:\$(TARGET_COPY_OUT_VENDOR)/etc/$fname \\\\"
    fi
done

INIT_COPY_FILES=""
INIT_FOUND=$(find "$DUMP_DIR/vendor" -name "init.*.rc" 2>/dev/null || true)
for r in $INIT_FOUND; do
    if [ -f "$r" ]; then
        rname=$(basename "$r")
        cp "$r" "$DEVICE_DIR/rootdir/etc/$rname"
        INIT_COPY_FILES="$INIT_COPY_FILES\n    \$(DEVICE_PATH)/rootdir/etc/$rname:\$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/$rname \\\\"
    fi
done

# ------------------------------------------------------------------------------
# 6. device.mk
# ------------------------------------------------------------------------------
cat <<EOF > "$DEVICE_DIR/device.mk"
#
# Copyright (C) $(date +%Y) The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/${BRAND}/${CODENAME}

# Inherit proprietary vendor files
\$(call inherit-product, vendor/${BRAND}/${CODENAME}/${CODENAME}-vendor.mk)

# Overlays
DEVICE_PACKAGE_OVERLAYS += \$(DEVICE_PATH)/overlay

# Fstab and Init configurations
PRODUCT_COPY_FILES += \\$(echo -e "$FSTAB_COPY_FILES")
PRODUCT_COPY_FILES += \\$(echo -e "$INIT_COPY_FILES")

# Hardware services and HALs
PRODUCT_PACKAGES += \\
    android.hardware.audio.service \\
    android.hardware.audio@7.0-impl \\
    android.hardware.audio.effect@7.0-impl \\
    android.hardware.camera.provider@2.4-service \\
    android.hardware.graphics.composer@2.1-service \\
    android.hardware.health-service.example \\
    android.hardware.power-service.example \\
    android.hardware.wifi@1.0-service
EOF

# ------------------------------------------------------------------------------
# 7. extract-files.sh & setup-makefiles.sh
# ------------------------------------------------------------------------------
cat <<EOF > "$DEVICE_DIR/extract-files.sh"
#!/usr/bin/env bash
#
# Copyright (C) $(date +%Y) The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=${CODENAME}
VENDOR=${BRAND}

# Load extract_utils and execute
MY_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
ANDROID_ROOT="\${MY_DIR}/../../.."

HELPER="\${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "\${HELPER}" ]; then
    echo "Unable to find helper script at \${HELPER}"
    exit 1
fi
source "\${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

while [ "\$#" -gt 0 ]; do
    case "\$1" in
        -n | --no-cleanup)
            CLEAN_VENDOR=false
            ;;
        *)
            SRC="\$1"
            ;;
    esac
    shift
done

setup_vendor "\${DEVICE}" "\${VENDOR}" "\${ANDROID_ROOT}" false "\${CLEAN_VENDOR}"
extract "\${MY_DIR}/proprietary-files.txt" "\${SRC}"
"\${MY_DIR}/setup-makefiles.sh"
EOF
chmod +x "$DEVICE_DIR/extract-files.sh"

cat <<EOF > "$DEVICE_DIR/setup-makefiles.sh"
#!/usr/bin/env bash
#
# Copyright (C) $(date +%Y) The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=${CODENAME}
VENDOR=${BRAND}

MY_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
ANDROID_ROOT="\${MY_DIR}/../../.."

HELPER="\${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "\${HELPER}" ]; then
    echo "Unable to find helper script at \${HELPER}"
    exit 1
fi
source "\${HELPER}"

write_headers
write_makefiles "\${MY_DIR}/proprietary-files.txt"
write_footers
EOF
chmod +x "$DEVICE_DIR/setup-makefiles.sh"

# ------------------------------------------------------------------------------
# 8. Proprietary Files Extraction & proprietary-files.txt
# ------------------------------------------------------------------------------
echo "=== [4/5] Scanning and Curating Critical Boot HALs & Proprietary Files ==="

PROPRIETARY_LIST="$DEVICE_DIR/proprietary-files.txt"
cat <<EOF > "$PROPRIETARY_LIST"
#
# Proprietary blobs for ${BRAND} ${CODENAME}
# Extracted from build: ${FINGERPRINT}
#

# Audio HAL & Calibration
EOF

# Scan and append matching critical vendor blobs from dump
find_and_append_blobs() {
    local category="$1"
    local pattern="$2"
    echo "" >> "$PROPRIETARY_LIST"
    echo "# $category" >> "$PROPRIETARY_LIST"

    # Search in vendor/ and system/
    for search_dir in "$DUMP_DIR/vendor" "$DUMP_DIR/system"; do
        if [ -d "$search_dir" ]; then
            find "$search_dir" -type f \( $pattern \) 2>/dev/null | while read -r filepath; do
                rel_path="${filepath#$DUMP_DIR/}"
                # Rel path is vendor/lib64/hw/gralloc.default.so etc.
                echo "$rel_path" >> "$PROPRIETARY_LIST"
            done
        fi
    done
}

find_and_append_blobs "Graphics, Gralloc & DRM" "-name *gralloc* -o -name *hwcomposer* -o -name *libdrm* -o -name *vulkan* -o -name *egl*"
find_and_append_blobs "Radio, RIL & Telephony" "-name *libril* -o -name *rild* -o -name *telephony*"
find_and_append_blobs "Power, Perf & Health" "-name *android.hardware.power* -o -name *android.hardware.health*"
find_and_append_blobs "Sensors, Calibration & Audio" "-name *sensors* -o -name *audio_policy*.xml -o -name *audio_effects*.xml"
find_and_append_blobs "Vendor Firmware Binaries" "-path */firmware/*"

# Deduplicate proprietary-files.txt while preserving comments
awk '!seen[$0]++ || /^#/ || /^$/' "$PROPRIETARY_LIST" > "${PROPRIETARY_LIST}.tmp"
mv "${PROPRIETARY_LIST}.tmp" "$PROPRIETARY_LIST"

# ------------------------------------------------------------------------------
# 9. Synthesizing Vendor Tree & proprietary files copy
# ------------------------------------------------------------------------------
echo "=== [5/5] Generating Complete Vendor Tree ==="

VENDOR_MAKEFILE="$VENDOR_DIR/${CODENAME}-vendor.mk"
cat <<EOF > "$VENDOR_MAKEFILE"
#
# Copyright (C) $(date +%Y) The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

\$(call inherit-product, \$(SRC_TARGET_DIR)/product/core_64_bit.mk)

PRODUCT_COPY_FILES += \\
EOF

# Copy all proprietary files found in dump to vendor/proprietary
PROPRIETARY_COPIES=""
while read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^# ]] && continue
    [ -z "$line" ] && continue

    source_path="$DUMP_DIR/$line"
    if [ -f "$source_path" ]; then
        dest_path="$VENDOR_DIR/proprietary/$line"
        mkdir -p "$(dirname "$dest_path")"
        cp "$source_path" "$dest_path"
        echo "    vendor/${BRAND}/${CODENAME}/proprietary/$line:\$(TARGET_COPY_OUT_VENDOR)/${line#vendor/} \\" >> "$VENDOR_MAKEFILE"
    fi
done < "$PROPRIETARY_LIST"

cat <<EOF > "$VENDOR_DIR/Android.mk"
#
# Copyright (C) $(date +%Y) The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := \$(call my-dir)

ifeq (\$(TARGET_DEVICE),${CODENAME})
\$(call inherit-product, \$(LOCAL_PATH)/${CODENAME}-vendor.mk)
endif
EOF

cat <<EOF > "$VENDOR_DIR/Android.bp"
//
// Copyright (C) $(date +%Y) The LineageOS Project
//
// SPDX-License-Identifier: Apache-2.0
//

soong_namespace {
}
EOF

echo "=== AOSP & LineageOS Device & Vendor Trees Successfully Generated! ==="
echo "  [Device Tree] $DEVICE_DIR"
echo "  [Vendor Tree] $VENDOR_DIR"
