#!/usr/bin/env python3
"""
Roomservice & Local Manifest Builder
Generates .repo/local_manifests/roomservice.xml mapping the generated
Device, Vendor, and Kernel repositories for automated ROM compilation.
"""

import os
import sys
import xml.etree.ElementTree as ET
from xml.dom import minidom
from typing import Dict, Any, Optional

class RoomserviceBuilder:
    def __init__(self, target_account: str, brand: str, codename: str, branch: str = "lineage-21.0"):
        self.target_account = target_account
        self.brand = brand
        self.codename = codename
        self.branch = branch

    def generate_xml_string(self) -> str:
        manifest = ET.Element("manifest")

        # Remote declaration
        remote = ET.SubElement(manifest, "remote")
        remote.set("name", "github")
        remote.set("fetch", "https://github.com")

        # Device Tree
        dev = ET.SubElement(manifest, "project")
        dev.set("name", f"{self.target_account}/device_{self.brand}_{self.codename}")
        dev.set("path", f"device/{self.brand}/{self.codename}")
        dev.set("remote", "github")
        dev.set("revision", self.branch)

        # Vendor Tree
        ven = ET.SubElement(manifest, "project")
        ven.set("name", f"{self.target_account}/vendor_{self.brand}_{self.codename}")
        ven.set("path", f"vendor/{self.brand}/{self.codename}")
        ven.set("remote", "github")
        ven.set("revision", self.branch)

        # Kernel Tree
        kern = ET.SubElement(manifest, "project")
        kern.set("name", f"{self.target_account}/kernel_{self.brand}_{self.codename}")
        kern.set("path", f"kernel/{self.brand}/{self.codename}")
        kern.set("remote", "github")
        kern.set("revision", self.branch)

        rough_string = ET.tostring(manifest, "utf-8")
        reparsed = minidom.parseString(rough_string)
        return reparsed.toprettyxml(indent="  ")

    def write_to_file(self, out_path: str) -> str:
        os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
        xml_content = self.generate_xml_string()
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(xml_content)
        return out_path

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: roomservice.py <TARGET_ACCOUNT> <BRAND> <CODENAME> [OUT_PATH] [BRANCH]", file=sys.stderr)
        sys.exit(1)
    out_file = sys.argv[4] if len(sys.argv) > 4 else "roomservice.xml"
    br = sys.argv[5] if len(sys.argv) > 5 else "lineage-21.0"
    builder = RoomserviceBuilder(sys.argv[1], sys.argv[2], sys.argv[3], branch=br)
    builder.write_to_file(out_file)
    print(f"Roomservice manifest created at {out_file}")
