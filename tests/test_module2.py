#!/usr/bin/env python3
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from github_pusher.dump_pusher import DumpPusher

class TestModule2(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_lfs_attributes(self):
        pusher = DumpPusher(target_account="testuser", dry_run=True)
        large_file = os.path.join(self.test_dir, "heavy_image.img")
        with open(large_file, "wb") as f:
            f.seek(1024)
            f.write(b"0")

        gitattr = pusher.setup_lfs_attributes(self.test_dir, [large_file])
        self.assertTrue(os.path.isfile(gitattr))
        with open(gitattr, "r") as f:
            content = f.read()
            self.assertIn("heavy_image.img filter=lfs", content)
            self.assertIn("*.img filter=lfs", content)

    def test_dry_run_push(self):
        pusher = DumpPusher(target_account="testuser", dry_run=True)
        res = pusher.push_dump_repo(self.test_dir, "google", "lynx")
        self.assertEqual(res["status"], "dry_run")
        self.assertEqual(res["repo"], "testuser/dump_google_lynx")

if __name__ == "__main__":
    unittest.main()
