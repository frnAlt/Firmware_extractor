# Universal Firmware Extractor, GitHub Dump Pusher & Multi-ROM Tree Generator

[![GitHub Actions Workflow](https://img.shields.io/badge/GitHub%20Actions-Automated%20Pipeline-blue?logo=github-actions)](.github/workflows/dump_and_generate.yml)
[![Cloud ROM Build](https://img.shields.io/badge/Cloud%20ROM%20Build-Automated-green?logo=android)](.github/workflows/cloud_build.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-success.svg)](LICENSE)
[![Python 3.8+](https://img.shields.io/badge/Python-3.8%2B-yellow?logo=python)](https://python.org)
[![Android](https://img.shields.io/badge/Android-13%20%7C%2014%20%7C%2015-orange?logo=android)](https://www.android.com)

A production-grade, automated Android firmware extraction engine, GitHub dump publisher, and multi-ROM device tree generator designed for custom ROM maintainers and AOSP platform engineers.

---

## 🏛️ 4-Module Core Architecture

```text
Firmware_extractor/
├── main.py                     # Master Orchestrator CLI
├── run.sh                      # Universal runner entrypoint
├── setup_env.sh                # Toolchain & environment installer
│
├── extractor/                  # MODULE 1: Universal Extractor & Metadata Parser
│   ├── firmware_engine.py      # Downloads & unpacks payload.bin, super.img, TAR.MD5, EROFS, EXT4
│   ├── boot_engine.py          # Unpacks boot.img/vendor_boot, extracts kernel, ikconfig, dtc dts
│   └── metadata_parser.py      # Aggregates build.prop, generates all_files.txt & board-info.txt
│
├── github_pusher/              # MODULE 2: Automated GitHub Dump & Release Pusher
│   └── dump_pusher.py          # Auto repo creator, Git LFS (>50MB), batch commits, Release uploads
│
├── tree_generator/             # MODULE 3: Multi-ROM Tree & Vendor Generator
│   ├── device_tree.py          # Generates BoardConfig.mk, device.mk, AndroidProducts.mk, fstab, init.rc
│   ├── vendor_tree.py          # Scans VINTF & ELF dependencies, builds proprietary-files.txt & blobs
│   ├── kernel_tree.py          # Packages prebuilt kernel, dtb.img, dtbo.img, and vendor_dlkm modules
│   └── overlay_extractor.py    # Decompiles framework-res.apk via apktool to generate accurate RRO config.xml
│
├── rom_adapter/                # Multi-ROM Flavor Adapters
│   └── adapter.py              # Adapts trees to LineageOS, PixelOS, crDroid, Evolution X, or TWRP
│
├── manifest_builder/           # MODULE 4: Local Manifest & Cloud Build Trigger
│   └── roomservice.py          # Generates .repo/local_manifests/roomservice.xml
│
└── .github/workflows/
    ├── dump_and_generate.yml   # Firmware dump & tree generation workflow
    └── cloud_build.yml         # Cloud ROM compilation workflow (mka bacon)
```

---

## 🚀 Cloud Execution via GitHub Actions

Run the entire pipeline in the cloud without installing any local dependencies:

### 1. Extract Firmware & Generate Trees
1. Open the [**Universal Firmware Extractor & AOSP Tree Generator**](.github/workflows/dump_and_generate.yml) workflow.
2. Click **Run workflow** and enter:
   - **Firmware URL**: Direct link to your stock ROM, OTA, Google Drive, or SourceForge file.
   - **Target account**: Your GitHub username or organization.
   - **Branch**: Default `lineage-21.0`.
3. In minutes, your `dump_<brand>_<codename>`, `device_<brand>_<codename>`, `vendor_<brand>_<codename>`, and `kernel_<brand>_<codename>` repositories will be created and pushed!

### 2. Trigger Cloud ROM Compilation
1. Open the [**Cloud ROM Build Trigger**](.github/workflows/cloud_build.yml) workflow.
2. Select your target ROM (`lineageos`, `pixelos`, `crdroid`, or `evolutionx`), brand, and codename.
3. The workflow injects the generated `roomservice.xml`, syncs sources, and triggers the build.

---

## 💻 Local CLI Usage

### Setup Environment
```bash
git clone --recurse-submodules https://github.com/frnAlt/Firmware_extractor.git
cd Firmware_extractor
chmod +x setup_env.sh run.sh main.py scripts/*.sh
./setup_env.sh
```

### Run Full Pipeline from Firmware URL
```bash
python3 main.py --url "https://example.com/stock_firmware.zip" \
               --rom-type all \
               --push-github \
               --target-org "frnAlt" \
               --lfs \
               --generate-manifest
```

### Run on Local Firmware Package
```bash
python3 main.py --path /path/to/stock_rom.tar.md5 --rom-type lineageos
```

### Generate Trees from an Existing Dump
```bash
python3 main.py --dump-dir out/dump --rom-type pixelos --generate-manifest
```

---

## ⚙️ CLI Options Reference

| Option | Description |
|---|---|
| `-u, --url <URL>` | Direct link to stock firmware (Fastboot, Recovery OTA, payload.bin, Google Drive, etc.) |
| `-f, --path <FILE>` | Path to local firmware archive or partition file |
| `-d, --dump-dir <DIR>` | Skip extraction and generate trees from an existing filesystem dump |
| `-o, --out <DIR>` | Output directory (default: `out/`) |
| `--rom-type <ROM>` | Target Custom ROM flavor (`lineageos`, `pixelos`, `crdroid`, `evolutionx`, `twrp`, `all`) |
| `--push-github` | Automatically create repositories and push dumps & trees to GitHub |
| `--target-org <USER>` | GitHub username or organization |
| `--branch <BRANCH>` | Git branch name (default: `lineage-21.0`) |
| `--lfs` | Enable Git LFS tracking for files >50MB |
| `--no-trees` | Skip device/vendor tree generation |
| `--generate-manifest`| Generate `.repo/local_manifests/roomservice.xml` |
| `--dry-run` | Simulate all git operations and repository creations without pushing |

---

## 📖 Custom ROM Bringup & Troubleshooting

For comprehensive guidance on dynamic partition sizing (`BOARD_SUPER_PARTITION_GROUPS`), `fstab` encryption flags, prebuilt kernel/DTB integration, and resolving SELinux policy denials, see the **[Complete AOSP & LineageOS Bringup Guide](GUIDE.md)**.

---

## ⚖️ License
Licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.
