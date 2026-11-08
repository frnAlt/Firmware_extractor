# 4-Module Multi-ROM Firmware Extractor & Bringup Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform `Firmware_extractor` into a 4-module automated pipeline:
- Module 1: Universal Firmware Extractor & Metadata Parser (`extractor/`)
- Module 2: Automated GitHub Dump & Release Pusher with LFS/Release sizing (`github_pusher/`)
- Module 3: Multi-ROM Device, Vendor, and Kernel Prebuilt Generator with Apktool RRO Overlays (`tree_generator/` & `rom_adapter/`)
- Module 4: Local Manifest & Cloud ROM Build Trigger (`manifest_builder/` & `.github/workflows/`)

**Architecture:**
- Python 3 + Bash hybrid architecture with modular Python packages and robust shell fallbacks.
- Single master controller `main.py` (with `run.sh` CLI wrapper).
- Standalone test suites validating each module independently.

---

### Task 1: Module 1 - Universal Firmware Extractor & Metadata Parser (`extractor/`)
**Files:**
- Create: `extractor/__init__.py`
- Create: `extractor/metadata_parser.py`
- Create: `extractor/boot_engine.py`
- Create: `extractor/firmware_engine.py`
- Test: `tests/test_module1.py`

- [ ] **Step 1: Implement extractor/metadata_parser.py**
Parse build.prop, extract brand, oem, codename, model, android_version, fingerprint, security_patch, platform, generate all_files.txt and board-info.txt.
- [ ] **Step 2: Implement extractor/boot_engine.py**
Unpack boot.img/vendor_boot.img, extract kernel Image.gz/Image, ramdisk, dtb/dtbo, extract ikconfig if available, decompile dtb into dts via dtc.
- [ ] **Step 3: Implement extractor/firmware_engine.py**
Coordinate downloading via aria2c/curl, unpacking payload.bin, super.img via lpunpack/simg2img, EROFS via fsck.erofs, EXT4 via 7z, and TAR.MD5.
- [ ] **Step 4: Write & Run tests/test_module1.py**
Verify metadata parsing, boot unpacking mock, and file indexing.
- [ ] **Step 5: Commit Module 1**

---

### Task 2: Module 2 - Automated GitHub Dump & Release Pusher (`github_pusher/`)
**Files:**
- Create: `github_pusher/__init__.py`
- Create: `github_pusher/dump_pusher.py`
- Test: `tests/test_module2.py`

- [ ] **Step 1: Implement github_pusher/dump_pusher.py**
Handle repo creation `<target>/dump_<oem>_<codename>`, manage files >50MB via Git LFS (.gitattributes) or GitHub Release uploads, commit in batches with retry logic, and push to GitHub.
- [ ] **Step 2: Write & Run tests/test_module2.py**
Verify LFS attribute generation, oversized file split/release logic, and dry-run push commands.
- [ ] **Step 3: Commit Module 2**

---

### Task 3: Module 3 - Multi-ROM Tree & Vendor Generator (`tree_generator/` & `rom_adapter/`)
**Files:**
- Create: `tree_generator/__init__.py`
- Create: `tree_generator/overlay_extractor.py`
- Create: `tree_generator/device_tree.py`
- Create: `tree_generator/vendor_tree.py`
- Create: `tree_generator/kernel_tree.py`
- Create: `rom_adapter/__init__.py`
- Create: `rom_adapter/adapter.py`
- Test: `tests/test_module3.py`

- [ ] **Step 1: Implement tree_generator/overlay_extractor.py**
Decompile framework-res.apk and SystemUI.apk via apktool to generate accurate RRO overlays (config_screenBrightnessSettingMinimum/Maximum, config_automatic_brightness_available, cutout paths, refresh rates, Doze).
- [ ] **Step 2: Implement tree_generator/device_tree.py**
Synthesize syntax-valid BoardConfig.mk, device.mk, AndroidProducts.mk, extract-files.sh, setup-makefiles.sh, fstab, and init scripts.
- [ ] **Step 3: Implement tree_generator/vendor_tree.py**
Scan VINTF manifests and ELF dependencies, populate proprietary-files.txt, and copy proprietary blobs into vendor tree.
- [ ] **Step 4: Implement tree_generator/kernel_tree.py**
Package prebuilt kernel, dtb, dtbo.img, and vendor_dlkm into a standalone kernel repository.
- [ ] **Step 5: Implement rom_adapter/adapter.py**
Add adapters for LineageOS, PixelOS, crDroid, Evolution X, and TWRP/OrangeFox.
- [ ] **Step 6: Write & Run tests/test_module3.py**
Verify RRO extraction, device tree, vendor tree, kernel tree, and ROM flavours.
- [ ] **Step 7: Commit Module 3**

---

### Task 4: Module 4 - Local Manifest & Cloud Build Trigger (`manifest_builder/`)
**Files:**
- Create: `manifest_builder/__init__.py`
- Create: `manifest_builder/roomservice.py`
- Create: `.github/workflows/cloud_build.yml`
- Test: `tests/test_module4.py`

- [ ] **Step 1: Implement manifest_builder/roomservice.py**
Generate .repo/local_manifests/roomservice.xml linking newly created GitHub Device, Vendor, and Kernel repositories.
- [ ] **Step 2: Create .github/workflows/cloud_build.yml**
GitHub Actions cloud build trigger for ROM compiling (`mka bacon`).
- [ ] **Step 3: Write & Run tests/test_module4.py**
Verify XML manifest generation and schema syntax.
- [ ] **Step 4: Commit Module 4**

---

### Task 5: Master Controller CLI (`main.py`) & Orchestrator Integration
**Files:**
- Create: `main.py`
- Update: `run.sh`
- Update: `README.md`
- Update: `setup_env.sh` and `requirements.txt`
- Update: `tests/test_components.sh`

- [ ] **Step 1: Implement main.py**
Support `--url`, `--path`, `--dump-dir`, `--rom-type`, `--push-github`, `--target-org`, `--lfs`, `--generate-trees`, `--generate-manifest`.
- [ ] **Step 2: Update run.sh wrapper**
Allow delegating directly to `main.py` while keeping shell options backward compatible.
- [ ] **Step 3: Run comprehensive verification suite**
Run all tests and verify full pipeline.
- [ ] **Step 4: Commit and Push to GitHub**
Push all modules, workflow triggers, and documentation to `frnAlt/Firmware_extractor`.
