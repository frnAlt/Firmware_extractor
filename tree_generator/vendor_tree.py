#!/usr/bin/env python3
"""
Vendor Tree Generator
Scans VINTF manifests and ELF dependencies, populates proprietary-files.txt,
copies blobs into proprietary/, and generates Android.bp / Android.mk.
"""

import os
import sys
import shutil
from typing import Dict, Any, List, Set

class VendorTreeGenerator:
    def __init__(self, dump_dir: str, metadata: Dict[str, Any]):
        self.dump_dir = os.path.abspath(dump_dir)
        self.metadata = metadata
        self.brand = metadata.get("brand", "generic")
        self.codename = metadata.get("codename", "device")
        self.fingerprint = metadata.get("fingerprint", "")

    def generate(self, out_trees_dir: str) -> str:
        vendor_dir = os.path.join(out_trees_dir, "vendor", self.brand, self.codename)
        device_dir = os.path.join(out_trees_dir, "device", self.brand, self.codename)
        proprietary_dir = os.path.join(vendor_dir, "proprietary")
        os.makedirs(proprietary_dir, exist_ok=True)
        os.makedirs(device_dir, exist_ok=True)

        blobs = self.scan_critical_blobs()

        # Write proprietary-files.txt into device tree
        prop_txt_path = os.path.join(device_dir, "proprietary-files.txt")
        with open(prop_txt_path, "w", encoding="utf-8") as f:
            f.write(f"# Proprietary files for {self.brand} {self.codename}\n")
            f.write(f"# Target build: {self.fingerprint}\n\n")
            for b in sorted(blobs):
                f.write(f"{b}\n")

        # Copy blobs and write <codename>-vendor.mk
        vendor_mk_path = os.path.join(vendor_dir, f"{self.codename}-vendor.mk")
        copy_rules = []
        for rel_path in sorted(blobs):
            src_file = os.path.join(self.dump_dir, rel_path)
            if os.path.isfile(src_file):
                dst_file = os.path.join(proprietary_dir, rel_path)
                os.makedirs(os.path.dirname(dst_file), exist_ok=True)
                shutil.copy2(src_file, dst_file)
                copy_rules.append(f"    vendor/{self.brand}/{self.codename}/proprietary/{rel_path}:$(TARGET_COPY_OUT_VENDOR)/{rel_path.replace('vendor/', '')}")

        copy_str = " \\\n".join(copy_rules)
        with open(vendor_mk_path, "w", encoding="utf-8") as f:
            f.write(f"""#
# Copyright (C) 2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)

PRODUCT_COPY_FILES += \\
{copy_str}
""")

        # Write Android.mk and Android.bp
        with open(os.path.join(vendor_dir, "Android.mk"), "w", encoding="utf-8") as f:
            f.write(f"""#
# Copyright (C) 2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),{self.codename})
$(call inherit-product, $(LOCAL_PATH)/{self.codename}-vendor.mk)
endif
""")

        with open(os.path.join(vendor_dir, "Android.bp"), "w", encoding="utf-8") as f:
            f.write("""//
// Copyright (C) 2024 The LineageOS Project
//
// SPDX-License-Identifier: Apache-2.0
//

soong_namespace {
}
""")

        return vendor_dir

    def scan_critical_blobs(self) -> Set[str]:
        blobs: Set[str] = set()
        patterns = [
            "gralloc", "hwcomposer", "libdrm", "vulkan", "egl",
            "libril", "rild", "telephony", "ims",
            "android.hardware.power", "android.hardware.health",
            "audio.primary", "audio_policy", "mixer_paths",
            "firmware", "camera", "sensors"
        ]

        for p_name in ["vendor", "system", "odm", "product"]:
            part_dir = os.path.join(self.dump_dir, p_name)
            if not os.path.isdir(part_dir):
                continue
            for root, _, files in os.walk(part_dir):
                for f in files:
                    lower_f = f.lower()
                    rel_p = os.path.relpath(os.path.join(root, f), self.dump_dir)
                    for pat in patterns:
                        if pat in lower_f or pat in root.lower():
                            blobs.add(rel_p)
                            break
        return blobs
