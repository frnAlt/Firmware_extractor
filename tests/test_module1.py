#!/usr/bin/env python3
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from extractor.metadata_parser import MetadataParser
from extractor.boot_engine import BootEngine

class TestModule1(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_metadata_parser(self):
        vendor_dir = os.path.join(self.test_dir, "vendor")
        os.makedirs(vendor_dir, exist_ok=True)
        build_prop = os.path.join(vendor_dir, "build.prop")
        with open(build_prop, "w") as f:
            f.write("ro.product.vendor.brand=Xiaomi\n")
            f.write("ro.product.vendor.device=sweet\n")
            f.write("ro.product.vendor.model=Redmi Note 10 Pro\n")
            f.write("ro.board.platform=sm6150\n")
            f.write("ro.build.version.release=13\n")
            f.write("ro.build.version.security_patch=2023-05-01\n")
            f.write("ro.vendor.build.fingerprint=Redmi/sweet/sweet:13/TKQ1/release-keys\n")

        parser = MetadataParser(self.test_dir)
        meta = parser.extract_metadata()
        self.assertEqual(meta["brand"], "xiaomi")
        self.assertEqual(meta["codename"], "sweet")
        self.assertEqual(meta["platform"], "sm6150")
        self.assertEqual(meta["android_version"], "13")

        all_files = parser.generate_all_files_index()
        self.assertTrue(os.path.isfile(all_files))

        board_info = parser.generate_board_info()
        self.assertTrue(os.path.isfile(board_info))
        with open(board_info, "r") as f:
            self.assertIn("require board=sweet", f.read())

    def test_boot_engine_init(self):
        engine = BootEngine()
        self.assertIsNotNone(engine.tools_dir)

if __name__ == "__main__":
    unittest.main()
