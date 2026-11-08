#!/usr/bin/env python3
"""
Metadata Parser
Extracts device identities, platform targets, fingerprint, and Android OS versions
from stock build.prop files across all dumped partitions.
Generates all_files.txt index and board-info.txt.
"""

import os
import sys
import json
from typing import Dict, Any, List

class MetadataParser:
    def __init__(self, dump_dir: str):
        self.dump_dir = os.path.abspath(dump_dir)
        self.props: Dict[str, str] = {}
        self.metadata: Dict[str, Any] = {}

    def parse_prop_file(self, filepath: str) -> Dict[str, str]:
        props = {}
        if not os.path.isfile(filepath):
            return props
        try:
            with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if "=" in line:
                        k, v = line.split("=", 1)
                        props[k.strip()] = v.strip()
        except Exception:
            pass
        return props

    def collect_props(self) -> Dict[str, str]:
        prop_files = []
        for root, _, files in os.walk(self.dump_dir):
            for file in files:
                if file.endswith(".prop") or file == "build.prop":
                    prop_files.append(os.path.join(root, file))

        # Priority order: vendor > odm > system > system_ext > product
        def get_priority(path: str) -> int:
            p = path.lower()
            if "vendor" in p:
                return 0
            if "odm" in p:
                return 1
            if "system_ext" in p:
                return 2
            if "product" in p:
                return 3
            if "system" in p:
                return 4
            return 5

        prop_files.sort(key=get_priority)

        for pfile in prop_files:
            file_props = self.parse_prop_file(pfile)
            self.props.update(file_props)

        return self.props

    def extract_metadata(self) -> Dict[str, Any]:
        if not self.props:
            self.collect_props()

        def get_first(*keys, default=""):
            for k in keys:
                v = self.props.get(k)
                if v:
                    return v
            return default

        brand = get_first(
            "ro.product.vendor.brand",
            "ro.product.brand",
            "ro.product.system.brand",
            "ro.product.odm.brand",
            "ro.product.product.brand",
            default="generic",
        ).lower().replace(" ", "_")

        oem = get_first(
            "ro.product.vendor.manufacturer",
            "ro.product.manufacturer",
            default=brand,
        ).lower().replace(" ", "_")

        codename = get_first(
            "ro.product.vendor.device",
            "ro.product.device",
            "ro.build.product",
            "ro.product.system.device",
            "ro.product.odm.device",
            default="device",
        ).lower().replace(" ", "_")

        model = get_first(
            "ro.product.vendor.model",
            "ro.product.model",
            "ro.product.system.model",
            "ro.product.odm.model",
            default=f"{brand.capitalize()} {codename.capitalize()}",
        )

        name = get_first(
            "ro.product.vendor.name",
            "ro.product.name",
            "ro.product.system.name",
            default=codename,
        )

        platform = get_first(
            "ro.board.platform",
            "ro.hardware",
            "ro.boot.hardware",
            "ro.soc.manufacturer",
            default="generic",
        ).lower()

        android_version = get_first(
            "ro.build.version.release",
            "ro.vendor.build.version.release",
            "ro.system.build.version.release",
            default="14",
        )

        incremental = get_first(
            "ro.build.version.incremental",
            "ro.vendor.build.version.incremental",
            default="1",
        )

        security_patch = get_first(
            "ro.build.version.security_patch",
            "ro.vendor.build.security_patch",
            default="2024-01-01",
        )

        fingerprint = get_first(
            "ro.vendor.build.fingerprint",
            "ro.build.fingerprint",
            "ro.system.build.fingerprint",
            default=f"{brand}/{codename}/{codename}:{android_version}/{incremental}/release-keys",
        )

        cpu_abi = get_first(
            "ro.product.cpu.abi",
            "ro.vendor.product.cpu.abi",
            "ro.system.product.cpu.abi",
            default="arm64-v8a",
        )

        first_api = get_first(
            "ro.product.first_api_level",
            "ro.board.first_api_level",
            default="30",
        )

        dynamic_partitions = (
            get_first("ro.boot.dynamic_partitions", "ro.vendor.dynamic_partitions", default="true").lower() == "true"
        )

        self.metadata = {
            "brand": brand,
            "oem": oem,
            "codename": codename,
            "model": model,
            "name": name,
            "platform": platform,
            "android_version": android_version,
            "incremental": incremental,
            "security_patch": security_patch,
            "fingerprint": fingerprint,
            "cpu_abi": cpu_abi,
            "first_api_level": first_api,
            "dynamic_partitions": dynamic_partitions,
        }
        return self.metadata

    def generate_all_files_index(self, out_path: str = None) -> str:
        if not out_path:
            out_path = os.path.join(self.dump_dir, "all_files.txt")
        file_list = []
        for root, _, files in os.walk(self.dump_dir):
            for file in files:
                rel_path = os.path.relpath(os.path.join(root, file), self.dump_dir)
                if not rel_path.startswith("all_files.txt"):
                    file_list.append(rel_path)
        file_list.sort()
        with open(out_path, "w", encoding="utf-8") as f:
            for item in file_list:
                f.write(f"{item}\n")
        return out_path

    def generate_board_info(self, out_path: str = None) -> str:
        if not self.metadata:
            self.extract_metadata()
        if not out_path:
            out_path = os.path.join(self.dump_dir, "board-info.txt")
        codename = self.metadata.get("codename", "generic")
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(f"require board={codename}\n")
        return out_path

    def save_metadata_json(self, out_path: str = None) -> str:
        if not self.metadata:
            self.extract_metadata()
        if not out_path:
            out_path = os.path.join(self.dump_dir, "metadata.json")
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(self.metadata, f, indent=2)
        return out_path

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: metadata_parser.py <DUMP_DIRECTORY> [--shell] [--index]", file=sys.stderr)
        sys.exit(1)
    parser = MetadataParser(sys.argv[1])
    meta = parser.extract_metadata()
    if "--index" in sys.argv:
        parser.generate_all_files_index()
        parser.generate_board_info()
        parser.save_metadata_json()
    if "--shell" in sys.argv:
        for k, v in meta.items():
            safe = str(v).replace('"', '\\"')
            print(f"export {k.upper()}=\"{safe}\"")
    else:
        print(json.dumps(meta, indent=2))
