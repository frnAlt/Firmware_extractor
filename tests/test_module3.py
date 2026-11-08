#!/usr/bin/env python3
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from tree_generator.overlay_extractor import OverlayExtractor
from tree_generator.device_tree import DeviceTreeGenerator
from tree_generator.vendor_tree import VendorTreeGenerator
from tree_generator.kernel_tree import KernelTreeGenerator
from rom_adapter.adapter import RomAdapter

class TestModule3(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.metadata = {
            "brand": "google",
            "codename": "lynx",
            "model": "Pixel 7a",
            "platform": "gs201",
            "android_version": "14",
            "fingerprint": "google/lynx:14/release-keys",
        }

    def tearDown(self):
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_overlay_generation(self):
        overlay_ext = OverlayExtractor(self.test_dir)
        out_overlay = os.path.join(self.test_dir, "overlay")
        cfg_path = overlay_ext.extract_or_generate_overlay(out_overlay)
        self.assertTrue(os.path.isfile(cfg_path))
        with open(cfg_path, "r") as f:
            content = f.read()
            self.assertIn("config_automatic_brightness_available", content)

    def test_device_vendor_kernel_trees(self):
        # Mock some dump files
        v_dir = os.path.join(self.test_dir, "vendor", "lib64", "hw")
        os.makedirs(v_dir, exist_ok=True)
        open(os.path.join(v_dir, "gralloc.gs201.so"), "a").close()

        out_trees = os.path.join(self.test_dir, "trees")
        dev_gen = DeviceTreeGenerator(self.test_dir, self.metadata)
        dev_dir = dev_gen.generate(out_trees)
        self.assertTrue(os.path.isfile(os.path.join(dev_dir, "BoardConfig.mk")))

        ven_gen = VendorTreeGenerator(self.test_dir, self.metadata)
        ven_dir = ven_gen.generate(out_trees)
        self.assertTrue(os.path.isfile(os.path.join(ven_dir, "Android.mk")))
        self.assertTrue(os.path.isfile(os.path.join(dev_dir, "proprietary-files.txt")))

        kern_gen = KernelTreeGenerator(self.test_dir, self.metadata)
        kern_dir = kern_gen.generate(out_trees)
        self.assertTrue(os.path.isfile(os.path.join(kern_dir, "Android.mk")))

    def test_rom_adapter(self):
        out_trees = os.path.join(self.test_dir, "trees")
        dev_gen = DeviceTreeGenerator(self.test_dir, self.metadata)
        dev_dir = dev_gen.generate(out_trees)

        adapter = RomAdapter(dev_dir, self.metadata)
        files = adapter.adapt_to("all")
        self.assertTrue(any("pixelos" in f for f in files))
        self.assertTrue(any("crdroid" in f for f in files))
        self.assertTrue(any("evolution" in f for f in files))
        self.assertTrue(any("twrp" in f for f in files))

if __name__ == "__main__":
    unittest.main()
