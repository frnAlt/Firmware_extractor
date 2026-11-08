#!/usr/bin/env python3
"""
Boot & Kernel Engine
Unpacks boot.img, vendor_boot.img, init_boot.img, and dtbo.img.
Extracts kernel, ramdisk, dtb, decompiles DTBs to readable .dts via dtc,
and extracts running kernel .config via ikconfig.
"""

import os
import sys
import subprocess
import shutil
from typing import Dict, Any, Optional

class BootEngine:
    def __init__(self, tools_dir: str = None):
        if not tools_dir:
            repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
            tools_dir = os.path.join(repo_root, "tools")
        self.tools_dir = tools_dir
        self.unpackbootimg = os.path.join(self.tools_dir, "unpackbootimg")
        if not os.path.isfile(self.unpackbootimg):
            self.unpackbootimg = shutil.which("unpackbootimg") or "unpackbootimg"

    def unpack_boot_image(self, boot_img_path: str, out_dir: str) -> Dict[str, Any]:
        os.makedirs(out_dir, exist_ok=True)
        results = {
            "kernel": None,
            "ramdisk": None,
            "dtb": None,
            "dtbo": None,
            "dts": None,
            "ikconfig": None,
        }

        if not os.path.isfile(boot_img_path):
            return results

        # 1. Unpack with unpackbootimg
        cmd = [self.unpackbootimg, "-i", boot_img_path, "-o", out_dir]
        try:
            subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        except Exception:
            pass

        # 2. Identify extracted files
        for f in os.listdir(out_dir):
            full_p = os.path.join(out_dir, f)
            if not os.path.isfile(full_p):
                continue
            lower_name = f.lower()
            if "kernel" in lower_name or lower_name in ["zimage", "image", "image.gz"]:
                results["kernel"] = full_p
            elif "ramdisk" in lower_name:
                results["ramdisk"] = full_p
            elif "dtb" in lower_name and not lower_name.endswith(".dts"):
                results["dtb"] = full_p
            elif "dtbo" in lower_name and not lower_name.endswith(".dts"):
                results["dtbo"] = full_p

        # 3. Extract ikconfig if kernel exists
        if results["kernel"]:
            ikconfig_path = os.path.join(out_dir, "kernel_defconfig")
            if self.extract_ikconfig(results["kernel"], ikconfig_path):
                results["ikconfig"] = ikconfig_path

        # 4. Decompile DTB to DTS using dtc
        dtb_target = results["dtb"] or results["dtbo"]
        if dtb_target and os.path.isfile(dtb_target):
            dts_out = os.path.join(out_dir, "decompiled_board.dts")
            if self.decompile_dtb(dtb_target, dts_out):
                results["dts"] = dts_out

        return results

    def extract_ikconfig(self, kernel_path: str, out_config_path: str) -> bool:
        """Extracts CONFIG_IKCONFIG gzip payload from kernel binary."""
        try:
            with open(kernel_path, "rb") as f:
                data = f.read()
            # Magic for gzip header is \x1f\x8b\x08
            # Look for IKCFG_ST or standard gzip streams
            import zlib
            pos = 0
            while True:
                pos = data.find(b"\x1f\x8b\x08", pos)
                if pos == -1:
                    break
                try:
                    # Decompress stream
                    decomp = zlib.decompress(data[pos:], 16 + zlib.MAX_WBITS)
                    if b"CONFIG_" in decomp:
                        with open(out_config_path, "wb") as out_f:
                            out_f.write(decomp)
                        return True
                except Exception:
                    pass
                pos += 1
        except Exception:
            pass
        return False

    def decompile_dtb(self, dtb_path: str, out_dts_path: str) -> bool:
        """Runs device-tree-compiler (dtc) to turn binary dtb into readable dts."""
        dtc_bin = shutil.which("dtc") or "dtc"
        try:
            cmd = [dtc_bin, "-I", "dtb", "-O", "dts", "-o", out_dts_path, dtb_path]
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            return res.returncode == 0 and os.path.isfile(out_dts_path)
        except Exception:
            return False

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: boot_engine.py <BOOT_IMG_PATH> <OUT_DIR>", file=sys.stderr)
        sys.exit(1)
    engine = BootEngine()
    out = engine.unpack_boot_image(sys.argv[1], sys.argv[2])
    import json
    print(json.dumps(out, indent=2))
