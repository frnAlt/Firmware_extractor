#!/usr/bin/env python3
"""
Firmware Engine
Master extraction controller for unpacking any stock Android firmware package
and extracting partition filesystems and boot artifacts.
"""

import os
import sys
import subprocess
import shutil
from typing import Dict, Any, Optional

from .metadata_parser import MetadataParser
from .boot_engine import BootEngine

class FirmwareEngine:
    def __init__(self, base_dir: str = None):
        if not base_dir:
            base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        self.base_dir = base_dir
        self.scripts_dir = os.path.join(self.base_dir, "scripts")
        self.tools_dir = os.path.join(self.base_dir, "tools")

    def run_extraction(self, input_target: str, out_dir: str) -> Dict[str, Any]:
        """Runs full firmware download, image unpacking, partition extraction and metadata indexing."""
        images_dir = os.path.join(out_dir, "images")
        dump_dir = os.path.join(out_dir, "dump")
        os.makedirs(images_dir, exist_ok=True)
        os.makedirs(dump_dir, exist_ok=True)

        extract_fw_script = os.path.join(self.scripts_dir, "extract_firmware.sh")
        extract_parts_script = os.path.join(self.scripts_dir, "extract_partitions.sh")

        print(f"[FirmwareEngine] Extracting firmware from {input_target}...")
        cmd1 = [extract_fw_script, input_target, images_dir]
        subprocess.run(cmd1, check=True)

        print(f"[FirmwareEngine] Unpacking partition filesystems into {dump_dir}...")
        cmd2 = [extract_parts_script, images_dir, dump_dir]
        subprocess.run(cmd2, check=True)

        # Process boot images
        boot_engine = BootEngine(self.tools_dir)
        boot_results = {}
        for b_name in ["boot", "vendor_boot", "init_boot"]:
            b_img = os.path.join(images_dir, f"{b_name}.img")
            if os.path.isfile(b_img):
                b_out = os.path.join(dump_dir, b_name)
                print(f"[FirmwareEngine] Unpacking boot asset: {b_name}.img...")
                boot_results[b_name] = boot_engine.unpack_boot_image(b_img, b_out)

        # Parse and generate metadata
        print(f"[FirmwareEngine] Indexing partitions and parsing device metadata...")
        parser = MetadataParser(dump_dir)
        metadata = parser.extract_metadata()
        parser.generate_all_files_index()
        parser.generate_board_info()
        parser.save_metadata_json()

        return {
            "images_dir": images_dir,
            "dump_dir": dump_dir,
            "metadata": metadata,
            "boot_results": boot_results,
        }

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: firmware_engine.py <INPUT_TARGET> <OUT_DIR>", file=sys.stderr)
        sys.exit(1)
    engine = FirmwareEngine()
    res = engine.run_extraction(sys.argv[1], sys.argv[2])
    print(res["metadata"])
