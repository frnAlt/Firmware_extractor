# Universal Firmware Extractor & AOSP Tree Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform `Firmware_extractor` into an automated, universal firmware dumper, AOSP/LineageOS device and vendor tree generator, with automated GitHub repository uploading and GitHub Actions workflow execution.

**Architecture:** 
- A core firmware unpacker engine (`scripts/extract_firmware.sh`) supporting all Android firmware formats (payload.bin, super.img, EROFS, EXT4, F2FS, Samsung TAR.MD5, OZIP/OFP, KDZ, PAC, raw sparse images, etc.).
- A partition mounter/extractor engine (`scripts/extract_partitions.sh`) converting raw/sparse partition images into accessible filesystem hierarchies (extracting system, vendor, product, system_ext, odm, boot, etc.).
- An AOSP & LineageOS tree synthesis module (`scripts/generate_trees.sh`) using `aospdtgen`, `extract-utils`, and custom property/init/fstab/sepolicy parsers to produce buildable AOSP device trees (`device/<vendor>/<codename>`) and proprietary vendor blob trees (`vendor/<vendor>/<codename>`).
- A GitHub automation engine (`scripts/upload_github.sh`) to automatically initialize, commit, and push generated device trees, vendor trees, and dump releases to GitHub with structured commit messages.
- A GitHub Actions workflow (`.github/workflows/dump_and_generate.yml`) featuring runner disk space reclamation (freeing up 30GB+), parameter inputs (`workflow_dispatch`), and end-to-end execution.

**Tech Stack:** Bash, Python 3 (aospdtgen, twrpdtgen, protobuf, pycryptodome, requests), standard Android tools (simg2img, lpunpack, fsck.erofs, 7z, payload-dumper-go, otadump, unpackbootimg), GitHub CLI (`gh`), git.

**Spec:** The request asks for:
1. Ready for dumping any firmware format.
2. Generate full device tree and vendor tree for AOSP / custom ROM building.
3. Automatically upload generated trees to GitHub.
4. Integrate LineageOS and community extraction tools.
5. Create a GitHub Actions workflow for automated runs.
6. Provide complete user documentation and GitHub topics/description.

## Global Constraints

- Scripts must be POSIX/Bash compatible and run cleanly in Ubuntu 22.04 / 24.04 and GitHub Actions runners.
- Must handle both sparse images, raw images, payload.bin, and super.img with dynamic partitions without root requirements (using user-space unpackers: `lpunpack`, `fsck.erofs`, `7z`, `ext2rd`/`debugfs`).
- Must strictly validate GitHub authentication and provide fallback modes if git credentials are not configured.
- Preserves existing tools in `tools/` and extends functionality modularly.

## Review Focus

1. Firmware with nested super.img inside payload.bin or TAR.MD5: Ensure recursive unpacking works without crashing or premature exit.
2. EROFS partition images: Ensure modern Android 13/14/15/16 partitions using EROFS are cleanly extracted without requiring `sudo mount`.
3. Device tree codename detection: If build.prop is scattered across `system`, `vendor`, or `system_ext`, aggregate build properties properly.
4. GitHub push failures: Token permission errors or rate limits handled with clear diagnostics rather than silent failures.
5. Runner disk space exhaustion: Unpacking large 10GB+ firmwares requires freeing up runner storage in GitHub Actions.

---

### Task 1: Environment & Dependency Toolchain Setup

**Files:**
- Create: `setup_env.sh`
- Create: `requirements.txt`
- Modify: `Firmware_extractor/.gitignore`

**Interfaces:**
- Consumes: Host OS package manager (`apt-get`), Python 3, pip.
- Produces: Executable `setup_env.sh` that installs all required native packages (7z, brotli, lz4, erofs-utils, simg2img, dtc, gawk) and Python dependencies (`aospdtgen`, `twrpdtgen`, `pycryptodome`).

- [ ] **Step 1: Create requirements.txt**
Define Python dependencies: `aospdtgen`, `twrpdtgen`, `protobuf`, `pycryptodome`, `requests`, `urllib3`, `extract-dtb`.

- [ ] **Step 2: Create setup_env.sh**
Write script to detect OS, install native dependencies, install Python tools, verify binary availability, and exit 0.

- [ ] **Step 3: Test setup_env.sh in dry-run or verification mode**
Run validation script checking tool availability and versions.

- [ ] **Step 4: Update .gitignore**
Ensure `out/`, `work/`, `dumps/`, `*.tmp`, `*.raw`, `*.bin`, `*.log` are ignored while tracking necessary scripts and tools.

- [ ] **Step 5: Commit**
`git add setup_env.sh requirements.txt .gitignore && git commit -m "feat: add unified environment setup and dependencies"`

---

### Task 2: Advanced Firmware Extractor & Partition Unpacker Engine

**Files:**
- Create: `scripts/extract_firmware.sh`
- Create: `scripts/extract_partitions.sh`
- Test: Unit verification with mock/sample archives or partition headers.

**Interfaces:**
- Consumes: Input firmware file path or download URL.
- Produces: `out/images/` containing raw `.img` files and `out/dump/` containing extracted filesystem trees (`system/`, `vendor/`, `product/`, `system_ext/`, `odm/`, `boot/`).

- [ ] **Step 1: Write URL downloader helper in scripts/extract_firmware.sh**
Support direct HTTP/HTTPS URLs, Google Drive, Mega, AndroidFileHost, SourceForge, and local files using `aria2c` / `curl` / `wget`.

- [ ] **Step 2: Write universal unpacker in scripts/extract_firmware.sh**
Integrate payload extraction (`payload-dumper-go` / `otadump`), super.img unpacker (`lpunpack`), Samsung TAR.MD5 LZ4 decompressor, OZIP decryptor, PAC extractor, and sparse unsparsing (`simg2img`).

- [ ] **Step 3: Write partition filesystem extractor in scripts/extract_partitions.sh**
Inspect magic bytes of each extracted `.img` file (EXT4, EROFS, F2FS, Boot image):
- If EROFS: extract with `fsck.erofs --extract`
- If EXT4: extract with `7z x` or `ext2rd`
- If boot/vendor_boot/recovery: extract kernel, ramdisk, dtb using `unpackbootimg` or `magiskboot` and `extract-dtb`.

- [ ] **Step 4: Verify extractor scripts syntax and mock execution**
Run bash syntax check (`bash -n scripts/extract_firmware.sh`) and mock test on sample partition structure.

- [ ] **Step 5: Commit**
`git add scripts/extract_firmware.sh scripts/extract_partitions.sh && git commit -m "feat: add universal firmware downloader, extractor and partition filesystem unpacker"`

---

### Task 3: AOSP & LineageOS Device and Vendor Tree Generator

**Files:**
- Create: `scripts/generate_trees.sh`
- Create: `scripts/prop_parser.py`

**Interfaces:**
- Consumes: `out/dump/` folder containing extracted partitions (`system/`, `vendor/`, etc.).
- Produces: 
  - `out/trees/device/<brand>/<codename>/` (AOSP/LineageOS device tree with `BoardConfig.mk`, `device.mk`, `AndroidProducts.mk`, `lineage_<codename>.mk`, init scripts, `proprietary-files.txt`).
  - `out/trees/vendor/<brand>/<codename>/` (Extracted proprietary vendor blobs matching `proprietary-files.txt`, with `Android.mk` and `<codename>-vendor.mk`).

- [ ] **Step 1: Implement scripts/prop_parser.py**
Parse `build.prop` files across `system`, `vendor`, `product`, `system_ext`, `odm` to extract:
- `ro.product.brand`, `ro.product.model`, `ro.product.device`, `ro.product.name`
- `ro.build.version.release`, `ro.build.version.security_patch`, `ro.build.fingerprint`
- Platform architecture, chipset (`ro.board.platform`, `ro.soc.manufacturer`).

- [ ] **Step 2: Implement scripts/generate_trees.sh**
1. Run `prop_parser.py` to identify device metadata.
2. Run `aospdtgen` over the extracted dump folder to produce initial AOSP device tree.
3. Enhance the device tree with:
   - LineageOS makefiles (`lineage_<codename>.mk`, `AndroidProducts.mk` lunch targets).
   - Extracted init `*.rc` scripts and `fstab` from `vendor/etc` or ramdisk.
   - Extract audio, display, camera, media configs and sepolicy.
4. Generate vendor tree:
   - Run LineageOS `extract-utils` or parse `proprietary-files.txt` generated by `aospdtgen` to copy matching files from `out/dump/` into `out/trees/vendor/<brand>/<codename>/`.
   - Generate `Android.mk` and `<codename>-vendor.mk`.

- [ ] **Step 3: Test tree generation logic**
Verify script with mock partition dump and assert structure of generated device and vendor trees.

- [ ] **Step 4: Commit**
`git add scripts/generate_trees.sh scripts/prop_parser.py && git commit -m "feat: add automated AOSP and LineageOS device and vendor tree generator"`

---

### Task 4: Automated GitHub Uploader & Git Repository Creator

**Files:**
- Create: `scripts/upload_github.sh`

**Interfaces:**
- Consumes: Generated device tree, vendor tree, dump metadata, and user's GitHub Token (`GH_TOKEN`).
- Produces: Git commits, branch creation, repository creation via `gh repo create` or pushing to existing repositories, and GitHub Release asset creation.

- [ ] **Step 1: Implement GitHub authentication check and repo discovery**
Validate `GH_TOKEN` or `GITHUB_TOKEN`. Determine target organization or username.

- [ ] **Step 2: Implement automated git commit and push for Device Tree**
Initialize git repo in `out/trees/device/<brand>/<codename>`, configure git author, add all files, commit with formatted message containing device fingerprint and Android version, and push to target GitHub repository (`device_<brand>_<codename>`).

- [ ] **Step 3: Implement automated git commit and push for Vendor Tree**
Initialize git repo in `out/trees/vendor/<brand>/<codename>`, commit proprietary blobs with LineageOS format, and push to `vendor_<brand>_<codename>`.

- [ ] **Step 4: Implement GitHub Release asset uploader for firmware dump**
Optionally compress the extracted dump or device tree archive and upload to GitHub Releases using `gh release create`.

- [ ] **Step 5: Verify upload script logic with dry-run mode**
Run `scripts/upload_github.sh --dry-run` to verify git init, commit structure, and target repo formatting without requiring real network push.

- [ ] **Step 6: Commit**
`git add scripts/upload_github.sh && git commit -m "feat: add automated GitHub repository creator and tree uploader"`

---

### Task 5: Master Orchestrator CLI (`run.sh`)

**Files:**
- Create: `run.sh`
- Modify: `extractor.sh` (integrate tree generation flag)

**Interfaces:**
- Consumes: Command line arguments `--url <URL>`, `--file <FILE>`, `--make-trees`, `--push-github`, `--target-org <ORG>`.
- Produces: Complete automated execution from download -> extraction -> tree generation -> GitHub upload.

- [ ] **Step 1: Implement CLI argument parser in run.sh**
Support all flags, help menu (`--help`), interactive prompts if run without args, and environment variable overrides.

- [ ] **Step 2: Chain workflow steps with rich logging and status indicators**
Step 1: Environment check -> Step 2: Firmware download/fetch -> Step 3: Extraction -> Step 4: Partition unpack -> Step 5: Tree generation -> Step 6: GitHub push -> Step 7: Summary report.

- [ ] **Step 3: Verify run.sh CLI help and options**
Execute `./run.sh --help` and verify syntax and exits.

- [ ] **Step 4: Commit**
`git add run.sh && git commit -m "feat: add master orchestrator run.sh for full automation"`

---

### Task 6: GitHub Actions CI/CD Workflow

**Files:**
- Create: `.github/workflows/dump_and_generate.yml`

**Interfaces:**
- Consumes: GitHub Actions `workflow_dispatch` inputs:
  - `firmware_url` (Required / Optional)
  - `generate_trees` (boolean, default true)
  - `push_to_github` (boolean, default true)
  - `target_org_or_user` (string)
  - `upload_dump_release` (boolean)
- Produces: Fully automated execution in the cloud runner with automatic runner storage cleanup (freeing 30GB+), artifact uploads, and GitHub summary.

- [ ] **Step 1: Create .github/workflows/dump_and_generate.yml**
Define workflow with:
- `workflow_dispatch` triggers and descriptions.
- Runner disk space freeing step (removing dotnet, android sdk, docker images).
- Dependency installation step.
- Execution step calling `./run.sh`.
- Artifact upload for generated device and vendor trees.
- Job summary output with build properties.

- [ ] **Step 2: Validate workflow yaml syntax**
Verify YAML structure with python/yaml parser.

- [ ] **Step 3: Commit**
`git add .github/workflows/dump_and_generate.yml && git commit -m "ci: add GitHub Actions workflow for automated firmware dump and tree generation"`

---

### Task 7: Comprehensive Documentation, User Guide & GitHub Topics Metadata

**Files:**
- Modify: `README.md`
- Create: `GUIDE.md`
- Create: `.github/repository-metadata.json`

**Interfaces:**
- Consumes: Tool features, workflow parameters, ROM building instructions.
- Produces: Detailed, high quality documentation for users and ROM developers, including instructions for GitHub Actions, local runs, secrets configuration, and repository topics.

- [ ] **Step 1: Create GUIDE.md**
Document step-by-step how to:
- Use via GitHub Actions in a few clicks.
- Configure `GH_TOKEN` secret.
- How to take the generated trees and compile an AOSP / LineageOS ROM.
- Supported firmware formats list and troubleshooting.

- [ ] **Step 2: Update README.md**
Update main README with feature badges, quickstart, workflow instructions, architecture overview, and examples.

- [ ] **Step 3: Create .github/repository-metadata.json**
Provide repository description, website, and topics (`android`, `aosp`, `lineageos`, `device-tree`, `firmware-extractor`, `payload-dumper`, `rom-development`, `android-dumps`, `erofs`, `vendor-tree`).

- [ ] **Step 4: Commit**
`git add README.md GUIDE.md .github/repository-metadata.json && git commit -m "docs: add comprehensive usage guide, updated README, and repository metadata"`

---

### Task 8: Verification & End-to-End Testing

**Files:**
- Test scripts: `tests/test_components.sh`

- [ ] **Step 1: Write integration tests in tests/test_components.sh**
Test URL parser, partition magic detector, prop parser on sample build.prop, and tree generation folder structures.

- [ ] **Step 2: Run verification test suite**
Execute `bash tests/test_components.sh` and ensure all tests pass.

- [ ] **Step 3: Verify git status and readiness for pushing**
Ensure clean working tree and correct git commit log.
