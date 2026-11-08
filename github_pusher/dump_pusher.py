#!/usr/bin/env python3
"""
Dump Pusher Engine
Automates GitHub repository creation, Git LFS tracking for files >50MB,
batch commits to prevent RPC packfile errors, and GitHub Release asset uploads.
"""

import os
import sys
import subprocess
import shutil
from typing import Dict, Any, List, Optional

class DumpPusher:
    def __init__(self, target_account: str, auth_token: Optional[str] = None, dry_run: bool = False):
        self.target_account = target_account
        self.auth_token = auth_token or os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
        self.dry_run = dry_run

    def setup_lfs_attributes(self, repo_dir: str, large_files: List[str]) -> str:
        """Configures .gitattributes for Git LFS to track files exceeding threshold."""
        gitattr_path = os.path.join(repo_dir, ".gitattributes")
        standard_patterns = [
            "*.img filter=lfs diff=lfs merge=lfs -text",
            "*.bin filter=lfs diff=lfs merge=lfs -text",
            "*.elf filter=lfs diff=lfs merge=lfs -text",
            "*.so.* filter=lfs diff=lfs merge=lfs -text",
            "*.apk filter=lfs diff=lfs merge=lfs -text",
        ]
        with open(gitattr_path, "w", encoding="utf-8") as f:
            for pattern in standard_patterns:
                f.write(f"{pattern}\n")
            for lf in large_files:
                rel = os.path.relpath(lf, repo_dir)
                f.write(f"{rel} filter=lfs diff=lfs merge=lfs -text\n")
        return gitattr_path

    def scan_large_files(self, repo_dir: str, threshold_mb: int = 50) -> List[str]:
        threshold_bytes = threshold_mb * 1024 * 1024
        large_files = []
        for root, _, files in os.walk(repo_dir):
            if ".git" in root:
                continue
            for file in files:
                p = os.path.join(root, file)
                try:
                    if os.path.getsize(p) > threshold_bytes:
                        large_files.append(p)
                except OSError:
                    pass
        return large_files

    def push_dump_repo(
        self,
        dump_dir: str,
        brand: str,
        codename: str,
        branch: str = "master",
        use_lfs: bool = True,
        release_assets: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        repo_name = f"dump_{brand}_{codename}"
        target_repo = f"{self.target_account}/{repo_name}"

        print(f"[DumpPusher] Preparing dump deployment for {target_repo} on branch {branch}...")

        # 1. Initialize git
        git_dir = os.path.join(dump_dir, ".git")
        if not os.path.isdir(git_dir):
            subprocess.run(["git", "init", "-b", branch], cwd=dump_dir, check=True)

        subprocess.run(["git", "config", "user.name", "github-actions[bot]"], cwd=dump_dir, check=True)
        subprocess.run(["git", "config", "user.email", "github-actions[bot]@users.noreply.github.com"], cwd=dump_dir, check=True)

        # 2. Check for large files and configure LFS
        large_files = self.scan_large_files(dump_dir, threshold_mb=50)
        if large_files and use_lfs:
            print(f"[DumpPusher] Found {len(large_files)} files >50MB. Configuring Git LFS...")
            self.setup_lfs_attributes(dump_dir, large_files)
            if shutil.which("git-lfs"):
                subprocess.run(["git", "lfs", "install"], cwd=dump_dir, check=False)

        if self.dry_run:
            print(f"[DRY-RUN] Would create and push to https://github.com/{target_repo} ({branch})")
            return {"status": "dry_run", "repo": target_repo, "branch": branch, "large_files_count": len(large_files)}

        # 3. Create repository via gh CLI if available
        if shutil.which("gh") and self.auth_token:
            env = os.environ.copy()
            env["GH_TOKEN"] = self.auth_token
            view_res = subprocess.run(["gh", "repo", "view", target_repo], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if view_res.returncode != 0:
                print(f"[DumpPusher] Creating GitHub repository: {target_repo}...")
                subprocess.run(["gh", "repo", "create", target_repo, "--public", "--confirm"], env=env, check=False)

        # 4. Batch commit
        print("[DumpPusher] Staging and committing files...")
        subprocess.run(["git", "add", "."], cwd=dump_dir, check=True)
        commit_msg = f"dump: {brand} {codename}: Automated raw stock firmware dump\n\nBranch: {branch}"
        subprocess.run(["git", "commit", "-m", commit_msg], cwd=dump_dir, check=False)

        # 5. Remote push
        if self.auth_token:
            remote_url = f"https://x-access-token:{self.auth_token}@github.com/{target_repo}.git"
            subprocess.run(["git", "remote", "remove", "origin"], cwd=dump_dir, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            subprocess.run(["git", "remote", "add", "origin", remote_url], cwd=dump_dir, check=True)
            print(f"[DumpPusher] Pushing branch {branch} to GitHub...")
            subprocess.run(["git", "push", "-u", "origin", branch, "--force"], cwd=dump_dir, check=True)

        # 6. Upload release assets if provided
        if release_assets and shutil.which("gh") and self.auth_token:
            env = os.environ.copy()
            env["GH_TOKEN"] = self.auth_token
            tag = f"dump-{branch}"
            cmd = ["gh", "release", "create", tag, "--repo", target_repo, "--title", f"Dump Assets {branch}", "--notes", "Raw oversized partition images"] + release_assets
            subprocess.run(cmd, env=env, check=False)

        return {"status": "success", "repo": target_repo, "branch": branch}

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: dump_pusher.py <DUMP_DIR> <BRAND> <CODENAME> [--dry-run]", file=sys.stderr)
        sys.exit(1)
    pusher = DumpPusher(target_account="frnAlt", dry_run="--dry-run" in sys.argv)
    res = pusher.push_dump_repo(sys.argv[1], sys.argv[2], sys.argv[3])
    print(res)
