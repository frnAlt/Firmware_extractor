# Universal Firmware Extractor & AOSP Tree Generator

[![GitHub Actions Workflow](https://img.shields.io/badge/GitHub%20Actions-Automated%20Workflow-blue?logo=github-actions)](.github/workflows/dump_and_generate.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
[![Python 3.8+](https://img.shields.io/badge/Python-3.8%2B-yellow?logo=python)](https://python.org)
[![Android](https://img.shields.io/badge/Android-13%20%7C%2014%20%7C%2015-success?logo=android)](https://www.android.com)

A universal Android stock firmware dumper and automated AOSP / LineageOS device & vendor tree generator.

Takes any stock OEM firmware package (payload.bin, super.img, TAR.MD5, OZIP, OFP, PAC, KDZ, RAW/Sparse), unpacks filesystems (EXT4, EROFS, F2FS), creates complete, bootable AOSP/LineageOS device and vendor trees, and automatically uploads the resulting source trees to GitHub.

---

## ⚡ Highlights & Features

- **Universal Firmware Unpacking**:
  - `payload.bin` (A/B and Virtual A/B OTA packages via `payload-dumper-go` & `otadump`).
  - `super.img` with Dynamic Partitions (unsparse via `simg2img`, unpack via `lpunpack`).
  - Samsung `TAR.MD5` and LZ4 decompression.
  - OPPO / Realme `OZIP` & `OFP` decrypted using community keys.
  - Unisoc `PAC`, LG `KDZ`, Sony `FTF`/`SIN`, Motorola sparse chunks, HTC `RUU`, Huawei `UPDATE.APP`.
- **Filesystem & Boot Extraction**:
  - EROFS extraction without root privileges via `fsck.erofs --extract`.
  - EXT4 partition extraction via `7z` and `ext2rd`.
  - Android Boot Image inspection (`boot.img`, `vendor_boot.img`, `recovery.img`) with ramdisk unpacking and DTB extraction (`extract-dtb`).
- **Complete AOSP & LineageOS Tree Synthesis**:
  - Auto-generates complete, syntax-valid `AndroidProducts.mk`, `BoardConfig.mk`, `device.mk`, `lineage_<codename>.mk`.
  - Extracts and curates critical boot HALs into `proprietary-files.txt` (Gralloc, DRM, RIL, Audio, Power, Health, Sensors).
  - Populates vendor tree `vendor/<brand>/<codename>` with extracted proprietary blobs, `Android.mk`, and `<codename>-vendor.mk`.
- **Automated GitHub Deployment**:
  - Automatically initializes git repositories (`device_<brand>_<codename>`, `vendor_<brand>_<codename>`).
  - Commits with rich metadata (Fingerprint, Security Patch, Android Version, Kernel).
  - Pushes to GitHub via GitHub CLI (`gh`) or personal access token.
- **Ready for GitHub Actions**:
  - 1-click cloud execution via `workflow_dispatch`.
  - Automatic runner disk cleanup freeing 35GB+ of NVMe space for large firmwares.
  - Downloadable artifacts and summary reports.

---

## 🚀 Quickstart via GitHub Actions (Cloud)

You can run the entire pipeline directly in GitHub Actions without installing anything locally:

1. Go to the **Actions** tab of your repository.
2. Select **Universal Firmware Extractor & AOSP Tree Generator**.
3. Click **Run workflow** and provide:
   - **Firmware URL**: Direct link to your firmware (`.zip`, `.tar.md5`, `payload.bin`, Google Drive, SourceForge, etc.).
   - **Target account**: Your GitHub username or organization where trees should be pushed.
   - **Branch**: Default `lineage-21.0`.
4. Click **Run workflow**. In minutes, your `device_<brand>_<codename>` and `vendor_<brand>_<codename>` repositories will be created and pushed to your GitHub!

> **Note**: For automated repository creation and pushing, add a Personal Access Token (`GH_TOKEN` or `PAT`) with `repo` permissions to your repository Secrets (**Settings** -> **Secrets and variables** -> **Actions**).

---

## 💻 Local Installation & CLI Usage

### 1. Setup Dependencies
```bash
git clone --recurse-submodules https://github.com/AndroidDumps/Firmware_extractor.git
cd Firmware_extractor
chmod +x setup_env.sh run.sh scripts/*.sh
./setup_env.sh
```

### 2. Run Master Orchestrator

#### From a Firmware URL:
```bash
./run.sh --url "https://example.com/firmware.zip" --push-github --target-org "yourusername"
```

#### From a Local File:
```bash
./run.sh --file /path/to/stock_firmware.tar.md5
```

#### From an Existing Filesystem Dump:
```bash
./run.sh --dump-dir out/dump --out out/
```

### Options Reference:
```text
Input Options:
  -u, --url <URL>            Direct firmware URL, Google Drive, SourceForge, etc.
  -f, --file <PATH>          Path to local stock firmware archive or image file.
  -d, --dump-dir <PATH>      Use an already extracted filesystem dump directory.

Generation & Deployment:
  -o, --out <DIR>            Output root directory (default: out/).
      --no-trees             Skip AOSP & LineageOS device/vendor tree generation.
      --push-github          Automatically create/push device & vendor trees to GitHub.
      --target-org <USER>    Target GitHub user or organization.
      --token <TOKEN>        GitHub personal access token (GH_TOKEN).
      --branch <BRANCH>      Git branch for trees (default: lineage-21.0).
      --dry-run              Dry run mode for GitHub operations (no actual network push).
```

---

## 📖 Building Your Custom ROM

Once your trees are generated, consult the **[Complete AOSP & LineageOS Bringup Guide](GUIDE.md)** for step-by-step instructions on:
- Configuring dynamic partitions and sizing in `BoardConfig.mk`.
- Fixing `fstab` first-stage mount and file encryption parameters.
- Integrating prebuilt kernel & DTB.
- Resolving SELinux policy denials (`avc: denied`).
- Compiling LineageOS with `mka bacon`.

---

## ⚖️ License
Licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.
