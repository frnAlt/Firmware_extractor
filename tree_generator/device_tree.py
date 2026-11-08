#!/usr/bin/env python3
"""
Device Tree Generator
Synthesizes syntax-valid, complete AOSP and LineageOS device tree repositories.
"""

import os
import sys
import shutil
from typing import Dict, Any, List

from .overlay_extractor import OverlayExtractor

class DeviceTreeGenerator:
    def __init__(self, dump_dir: str, metadata: Dict[str, Any]):
        self.dump_dir = os.path.abspath(dump_dir)
        self.metadata = metadata
        self.brand = metadata.get("brand", "generic")
        self.codename = metadata.get("codename", "device")
        self.model = metadata.get("model", "AOSP Device")
        self.platform = metadata.get("platform", "generic")
        self.android_ver = metadata.get("android_version", "14")
        self.fingerprint = metadata.get("fingerprint", "")
        self.name = metadata.get("name", self.codename)

    def generate(self, out_trees_dir: str) -> str:
        device_dir = os.path.join(out_trees_dir, "device", self.brand, self.codename)
        os.makedirs(device_dir, exist_ok=True)
        os.makedirs(os.path.join(device_dir, "rootdir", "etc"), exist_ok=True)
        os.makedirs(os.path.join(device_dir, "prebuilt"), exist_ok=True)
        os.makedirs(os.path.join(device_dir, "sepolicy", "vendor"), exist_ok=True)

        # 1. AndroidProducts.mk
        self._write_android_products(device_dir)

        # 2. ROM Makefiles
        self._write_lineage_mk(device_dir)
        self._write_aosp_mk(device_dir)

        # 3. BoardConfig.mk
        self._write_board_config(device_dir)

        # 4. Copy fstab and init.rc
        fstab_copies, init_copies = self._copy_rootdir_files(device_dir)

        # 5. device.mk
        self._write_device_mk(device_dir, fstab_copies, init_copies)

        # 6. Extract/setup scripts
        self._write_extract_scripts(device_dir)

        # 7. SELinux file_contexts
        self._write_sepolicy(device_dir)

        # 8. RRO Overlays
        overlay_ext = OverlayExtractor(self.dump_dir)
        overlay_ext.extract_or_generate_overlay(os.path.join(device_dir, "overlay"))

        # 9. Prebuilt kernel & dtb assets
        self._copy_prebuilts(device_dir)

        return device_dir

    def _write_android_products(self, target_dir: str):
        content = f"""#
# Copyright (C) 2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

PRODUCT_MAKEFILES := \\
    $(LOCAL_DIR)/lineage_{self.codename}.mk \\
    $(LOCAL_DIR)/aosp_{self.codename}.mk

COMMON_LUNCH_CHOICES := \\
    lineage_{self.codename}-user \\
    lineage_{self.codename}-userdebug \\
    lineage_{self.codename}-eng \\
    aosp_{self.codename}-userdebug
"""
        with open(os.path.join(target_dir, "AndroidProducts.mk"), "w", encoding="utf-8") as f:
            f.write(content)

    def _write_lineage_mk(self, target_dir: str):
        content = f"""#
# Copyright (C) 2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, device/{self.brand}/{self.codename}/device.mk)
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_{self.codename}
PRODUCT_DEVICE := {self.codename}
PRODUCT_MANUFACTURER := {self.brand}
PRODUCT_BRAND := {self.brand}
PRODUCT_MODEL := {self.model}

PRODUCT_GMS_CLIENTID_BASE := android-{self.brand}

PRODUCT_BUILD_PROP_OVERRIDES += \\
    PRODUCT_NAME={self.name} \\
    TARGET_DEVICE={self.codename} \\
    BUILD_FINGERPRINT="{self.fingerprint}"
"""
        with open(os.path.join(target_dir, f"lineage_{self.codename}.mk"), "w", encoding="utf-8") as f:
            f.write(content)

    def _write_aosp_mk(self, target_dir: str):
        content = f"""#
# Copyright (C) 2024 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, device/{self.brand}/{self.codename}/device.mk)

PRODUCT_NAME := aosp_{self.codename}
PRODUCT_DEVICE := {self.codename}
PRODUCT_MANUFACTURER := {self.brand}
PRODUCT_BRAND := {self.brand}
PRODUCT_MODEL := {self.model}
"""
        with open(os.path.join(target_dir, f"aosp_{self.codename}.mk"), "w", encoding="utf-8") as f:
            f.write(content)

    def _write_board_config(self, target_dir: str):
        upper_brand = self.brand.upper()
        content = f"""#
# Copyright (C) 2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/{self.brand}/{self.codename}

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
TARGET_BOARD_PLATFORM := {self.platform}
BOARD_VENDOR := {self.brand}

# Kernel
BOARD_KERNEL_PAGESIZE := 4096
BOARD_BOOT_HEADER_VERSION := 2
BOARD_KERNEL_CMDLINE := console=null androidboot.hardware={self.platform}
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilt/dtb.img
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img

# Dynamic Partitions
BOARD_SUPER_PARTITION_SIZE := 9126805504
BOARD_SUPER_PARTITION_GROUPS := {self.brand}_dynamic_partitions
BOARD_{upper_brand}_DYNAMIC_PARTITIONS_SIZE := 9122611200
BOARD_{upper_brand}_DYNAMIC_PARTITIONS_PARTITION_LIST := system vendor product system_ext odm

# Filesystems
TARGET_USERIMAGES_USE_EXT4 := true
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_FLASH_BLOCK_SIZE := 262144

# SELinux
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor
TARGET_RELEASETOOLS_EXTENSIONS := $(DEVICE_PATH)
"""
        with open(os.path.join(target_dir, "BoardConfig.mk"), "w", encoding="utf-8") as f:
            f.write(content)

    def _copy_rootdir_files(self, target_dir: str) -> (str, str):
        fstab_copies = []
        init_copies = []
        for root, _, files in os.walk(self.dump_dir):
            for file in files:
                full_p = os.path.join(root, file)
                if file.startswith("fstab."):
                    dest = os.path.join(target_dir, "rootdir", "etc", file)
                    shutil.copy2(full_p, dest)
                    fstab_copies.append(f"    $(DEVICE_PATH)/rootdir/etc/{file}:$(TARGET_COPY_OUT_VENDOR)/etc/{file}")
                elif file.startswith("init.") and file.endswith(".rc"):
                    dest = os.path.join(target_dir, "rootdir", "etc", file)
                    shutil.copy2(full_p, dest)
                    init_copies.append(f"    $(DEVICE_PATH)/rootdir/etc/{file}:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/{file}")
        f_str = " \\\n".join(fstab_copies)
        i_str = " \\\n".join(init_copies)
        return f_str, i_str

    def _write_device_mk(self, target_dir: str, fstab_copies: str, init_copies: str):
        content = f"""#
# Copyright (C) 2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/{self.brand}/{self.codename}

$(call inherit-product, vendor/{self.brand}/{self.codename}/{self.codename}-vendor.mk)

DEVICE_PACKAGE_OVERLAYS += $(DEVICE_PATH)/overlay

PRODUCT_COPY_FILES += \\
{fstab_copies}

PRODUCT_COPY_FILES += \\
{init_copies}

PRODUCT_PACKAGES += \\
    android.hardware.audio.service \\
    android.hardware.camera.provider@2.4-service \\
    android.hardware.graphics.composer@2.1-service \\
    android.hardware.health-service.example \\
    android.hardware.power-service.example \\
    android.hardware.wifi@1.0-service
"""
        with open(os.path.join(target_dir, "device.mk"), "w", encoding="utf-8") as f:
            f.write(content)

    def _write_extract_scripts(self, target_dir: str):
        ext_script = f"""#!/usr/bin/env bash
set -e
DEVICE={self.codename}
VENDOR={self.brand}
MY_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)"
ANDROID_ROOT="${{MY_DIR}}/../../.."
HELPER="${{ANDROID_ROOT}}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${{HELPER}}" ]; then
    echo "extract-utils helper not found."
    exit 1
fi
source "${{HELPER}}"
setup_vendor "${{DEVICE}}" "${{VENDOR}}" "${{ANDROID_ROOT}}" false true
extract "${{MY_DIR}}/proprietary-files.txt" "$1"
"${{MY_DIR}}/setup-makefiles.sh"
"""
        with open(os.path.join(target_dir, "extract-files.sh"), "w", encoding="utf-8") as f:
            f.write(ext_script)
        os.chmod(os.path.join(target_dir, "extract-files.sh"), 0o755)

        setup_mk = f"""#!/usr/bin/env bash
set -e
DEVICE={self.codename}
VENDOR={self.brand}
MY_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)"
ANDROID_ROOT="${{MY_DIR}}/../../.."
HELPER="${{ANDROID_ROOT}}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${{HELPER}}" ]; then
    echo "extract-utils helper not found."
    exit 1
fi
source "${{HELPER}}"
write_headers
write_makefiles "${{MY_DIR}}/proprietary-files.txt"
write_footers
"""
        with open(os.path.join(target_dir, "setup-makefiles.sh"), "w", encoding="utf-8") as f:
            f.write(setup_mk)
        os.chmod(os.path.join(target_dir, "setup-makefiles.sh"), 0o755)

    def _write_sepolicy(self, target_dir: str):
        fc_path = os.path.join(target_dir, "sepolicy", "vendor", "file_contexts")
        stock_fc = os.path.join(self.dump_dir, "vendor", "etc", "selinux", "vendor_file_contexts")
        if os.path.isfile(stock_fc):
            shutil.copy2(stock_fc, fc_path)
        else:
            with open(fc_path, "w", encoding="utf-8") as f:
                f.write("# Vendor File Contexts\n")

    def _copy_prebuilts(self, target_dir: str):
        prebuilt_dir = os.path.join(target_dir, "prebuilt")
        # Check boot dump for kernel
        for k in ["kernel", "Image", "Image.gz", "zImage"]:
            src = os.path.join(self.dump_dir, "boot", k)
            if os.path.isfile(src):
                shutil.copy2(src, os.path.join(prebuilt_dir, "kernel"))
                break
        if not os.path.isfile(os.path.join(prebuilt_dir, "kernel")):
            open(os.path.join(prebuilt_dir, "kernel"), "a").close()

        for d in ["dtb", "dtb.img"]:
            src = os.path.join(self.dump_dir, "boot", d)
            if os.path.isfile(src):
                shutil.copy2(src, os.path.join(prebuilt_dir, "dtb.img"))
                break
        if not os.path.isfile(os.path.join(prebuilt_dir, "dtb.img")):
            open(os.path.join(prebuilt_dir, "dtb.img"), "a").close()

        src_dtbo = os.path.join(self.dump_dir, "dtbo", "dtbo.img")
        if os.path.isfile(src_dtbo):
            shutil.copy2(src_dtbo, os.path.join(prebuilt_dir, "dtbo.img"))
        else:
            open(os.path.join(prebuilt_dir, "dtbo.img"), "a").close()
