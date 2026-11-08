#!/usr/bin/env python3
"""
Kernel Prebuilt Tree Generator
Packages extracted kernel Image, dtb, dtbo, and vendor_dlkm modules
into a standalone prebuilt kernel repository.
"""

import os
import sys
import shutil
from typing import Dict, Any

class KernelTreeGenerator:
    def __init__(self, dump_dir: str, metadata: Dict[str, Any]):
        self.dump_dir = os.path.abspath(dump_dir)
        self.metadata = metadata
        self.brand = metadata.get("brand", "generic")
        self.codename = metadata.get("codename", "device")

    def generate(self, out_trees_dir: str) -> str:
        kernel_repo_dir = os.path.join(out_trees_dir, "kernel", self.brand, self.codename)
        os.makedirs(kernel_repo_dir, exist_ok=True)
        modules_dir = os.path.join(kernel_repo_dir, "modules")
        os.makedirs(modules_dir, exist_ok=True)

        # 1. Copy kernel binary
        kernel_copied = False
        for k in ["kernel", "Image", "Image.gz", "zImage"]:
            src = os.path.join(self.dump_dir, "boot", k)
            if os.path.isfile(src):
                shutil.copy2(src, os.path.join(kernel_repo_dir, "Image.gz"))
                kernel_copied = True
                break
        if not kernel_copied:
            open(os.path.join(kernel_repo_dir, "Image.gz"), "a").close()

        # 2. Copy DTB and DTBO
        for d in ["dtb", "dtb.img"]:
            src = os.path.join(self.dump_dir, "boot", d)
            if os.path.isfile(src):
                shutil.copy2(src, os.path.join(kernel_repo_dir, "dtb.img"))
                break
        if not os.path.isfile(os.path.join(kernel_repo_dir, "dtb.img")):
            open(os.path.join(kernel_repo_dir, "dtb.img"), "a").close()

        src_dtbo = os.path.join(self.dump_dir, "dtbo", "dtbo.img")
        if os.path.isfile(src_dtbo):
            shutil.copy2(src_dtbo, os.path.join(kernel_repo_dir, "dtbo.img"))
        else:
            open(os.path.join(kernel_repo_dir, "dtbo.img"), "a").close()

        # 3. Copy vendor_dlkm modules
        for root, _, files in os.walk(self.dump_dir):
            if "vendor_dlkm" in root or "dlkm" in root:
                for f in files:
                    if f.endswith(".ko"):
                        shutil.copy2(os.path.join(root, f), os.path.join(modules_dir, f))

        # 4. Generate Android.mk
        with open(os.path.join(kernel_repo_dir, "Android.mk"), "w", encoding="utf-8") as f:
            f.write(f"""#
# Prebuilt Kernel Repository for {self.brand} {self.codename}
#

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),{self.codename})

PRODUCT_COPY_FILES += \\
    $(LOCAL_PATH)/Image.gz:kernel \\
    $(LOCAL_PATH)/dtb.img:dtb.img \\
    $(LOCAL_PATH)/dtbo.img:dtbo.img

endif
""")

        return kernel_repo_dir
