#!/usr/bin/env python3
"""
Multi-ROM Adapter
Transforms standard AOSP device trees into target Custom ROM flavors:
LineageOS, PixelOS, crDroid, Evolution X, and TWRP/OrangeFox recovery trees.
"""

import os
import sys
from typing import Dict, Any, List

class RomAdapter:
    SUPPORTED_ROMS = ["lineageos", "pixelos", "crdroid", "evolutionx", "twrp", "all"]

    def __init__(self, device_dir: str, metadata: Dict[str, Any]):
        self.device_dir = os.path.abspath(device_dir)
        self.metadata = metadata
        self.brand = metadata.get("brand", "generic")
        self.codename = metadata.get("codename", "device")
        self.model = metadata.get("model", "Device")

    def adapt_to(self, rom_type: str = "lineageos") -> List[str]:
        rom_type = rom_type.lower()
        generated = []
        if rom_type in ["lineageos", "all"]:
            generated.append(self._generate_lineage())
        if rom_type in ["pixelos", "all"]:
            generated.append(self._generate_pixelos())
        if rom_type in ["crdroid", "all"]:
            generated.append(self._generate_crdroid())
        if rom_type in ["evolutionx", "all"]:
            generated.append(self._generate_evolutionx())
        if rom_type in ["twrp", "all"]:
            generated.append(self._generate_twrp())
        self._update_android_products(rom_type)
        return generated

    def _generate_lineage(self) -> str:
        path = os.path.join(self.device_dir, f"lineage_{self.codename}.mk")
        content = f"""# LineageOS Product Configuration for {self.codename}
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, device/{self.brand}/{self.codename}/device.mk)
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_{self.codename}
PRODUCT_DEVICE := {self.codename}
PRODUCT_BRAND := {self.brand}
PRODUCT_MODEL := {self.model}
"""
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        return path

    def _generate_pixelos(self) -> str:
        path = os.path.join(self.device_dir, f"pixelos_{self.codename}.mk")
        content = f"""# PixelOS Product Configuration for {self.codename}
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, device/{self.brand}/{self.codename}/device.mk)
$(call inherit-product, vendor/pixelos/config/common_full_phone.mk)

PRODUCT_NAME := pixelos_{self.codename}
PRODUCT_DEVICE := {self.codename}
PRODUCT_BRAND := {self.brand}
PRODUCT_MODEL := {self.model}
"""
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        return path

    def _generate_crdroid(self) -> str:
        path = os.path.join(self.device_dir, f"crdroid_{self.codename}.mk")
        content = f"""# crDroid Product Configuration for {self.codename}
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, device/{self.brand}/{self.codename}/device.mk)
$(call inherit-product, vendor/croid/config/common.mk)

PRODUCT_NAME := crdroid_{self.codename}
PRODUCT_DEVICE := {self.codename}
PRODUCT_BRAND := {self.brand}
PRODUCT_MODEL := {self.model}
"""
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        return path

    def _generate_evolutionx(self) -> str:
        path = os.path.join(self.device_dir, f"evolution_{self.codename}.mk")
        content = f"""# Evolution X Product Configuration for {self.codename}
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, device/{self.brand}/{self.codename}/device.mk)
$(call inherit-product, vendor/evolution/config/common_full_phone.mk)

PRODUCT_NAME := evolution_{self.codename}
PRODUCT_DEVICE := {self.codename}
PRODUCT_BRAND := {self.brand}
PRODUCT_MODEL := {self.model}
"""
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        return path

    def _generate_twrp(self) -> str:
        path = os.path.join(self.device_dir, f"twrp_{self.codename}.mk")
        content = f"""# TWRP / OrangeFox Recovery Configuration for {self.codename}
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, device/{self.brand}/{self.codename}/device.mk)

PRODUCT_NAME := twrp_{self.codename}
PRODUCT_DEVICE := {self.codename}
PRODUCT_BRAND := {self.brand}
PRODUCT_MODEL := {self.model}

TW_THEME := portrait_hdpi
RECOVERY_SDCARD_ON_DATA := true
"""
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        return path

    def _update_android_products(self, rom_type: str):
        mk_files = []
        lunch_choices = []
        roms = [rom_type] if rom_type != "all" else ["lineageos", "pixelos", "crdroid", "evolutionx", "twrp"]
        for r in roms:
            prefix = "evolution" if r == "evolutionx" else r
            mk_files.append(f"    $(LOCAL_DIR)/{prefix}_{self.codename}.mk")
            lunch_choices.append(f"    {prefix}_{self.codename}-userdebug")

        content = f"""# Auto-generated AndroidProducts.mk
PRODUCT_MAKEFILES := \\
{chr(10).join(mk_files)}

COMMON_LUNCH_CHOICES := \\
{chr(10).join(lunch_choices)}
"""
        with open(os.path.join(self.device_dir, "AndroidProducts.mk"), "w", encoding="utf-8") as f:
            f.write(content)
