#!/usr/bin/env python3
import os
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from manifest_builder.roomservice import RoomserviceBuilder

class TestModule4(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_roomservice_xml_generation(self):
        builder = RoomserviceBuilder("frnAlt", "google", "lynx", "lineage-21.0")
        xml_file = os.path.join(self.test_dir, "roomservice.xml")
        builder.write_to_file(xml_file)

        self.assertTrue(os.path.isfile(xml_file))
        tree = ET.parse(xml_file)
        root = tree.getroot()
        self.assertEqual(root.tag, "manifest")

        projects = root.findall("project")
        self.assertEqual(len(projects), 3)

        project_names = [p.get("name") for p in projects]
        self.assertIn("frnAlt/device_google_lynx", project_names)
        self.assertIn("frnAlt/vendor_google_lynx", project_names)
        self.assertIn("frnAlt/kernel_google_lynx", project_names)

if __name__ == "__main__":
    unittest.main()
