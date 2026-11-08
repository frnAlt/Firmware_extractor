# Universal Firmware Extractor, GitHub Dump Pusher & Multi-ROM Tree Generator

[![GitHub Actions Workflows](https://img.shields.io/badge/GitHub%20Actions-9%20Automated%20Pipelines-blue?logo=github-actions)](.github/workflows/)
[![Continuous Integration](https://img.shields.io/badge/CI-Passing%20(11%2F11%20Tests)-brightgreen?logo=github-actions)](.github/workflows/ci_tests.yml)
[![Cloud ROM Build](https://img.shields.io/badge/Cloud%20ROM%20Build-Automated-green?logo=android)](.github/workflows/cloud_build.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-success.svg)](LICENSE)
[![Python 3.8+](https://img.shields.io/badge/Python-3.8%2B-yellow?logo=python)](https://python.org)
[![Android](https://img.shields.io/badge/Android-13%20%7C%2014%20%7C%2015-orange?logo=android)](https://www.android.com)

A production-grade, automated Android firmware extraction engine, GitHub dump publisher, and multi-ROM device tree generator designed for custom ROM maintainers and AOSP platform engineers.

---

## ⚡ Complete GitHub Actions Workflow Suite

You can execute every feature directly in the cloud via the GitHub Actions tab:

| Workflow | Direct Link | Description |
|---|---|---|
| **Full Pipeline** | [**`dump_and_generate.yml`**](.github/workflows/dump_and_generate.yml) | End-to-end: Download firmware, unpack partitions (EROFS/EXT4), extract metadata, generate multi-ROM trees, and push to GitHub. |
| **Firmware Dump Only** | [**`firmware_dump_only.yml`**](.github/workflows/firmware_dump_only.yml) | Unpack firmware, handle Git LFS (>50MB), and publish `<account>/dump_<brand>_<codename>` on GitHub. |
| **Trees From Existing Dump** | [**`generate_trees_from_dump.yml`**](.github/workflows/generate_trees_from_dump.yml) | Generate Device, Vendor, Kernel trees & roomservice manifest from an existing GitHub dump repo. |
| **Boot & DTB to DTS** | [**`boot_unpack_dtb_dts.yml`**](.github/workflows/boot_unpack_dtb_dts.yml) | Unpack `boot.img`/`vendor_boot`, extract kernel, extract `.config` via `ikconfig`, and decompile DTB/DTBO to DTS source. |
| **RRO Overlays Extractor** | [**`rro_overlay_extractor.yml`**](.github/workflows/rro_overlay_extractor.yml) | Decompile `framework-res.apk`/`SystemUI.apk` via `apktool` for display cutouts, refresh rates, and auto-brightness curves. |
| **TWRP Recovery Tree** | [**`twrp_recovery_tree.yml`**](.github/workflows/twrp_recovery_tree.yml) | Generate complete TWRP / OrangeFox recovery device trees using `twrpdtgen` and push to GitHub. |
| **Vendor Blobs Extractor** | [**`extract_blobs_to_vendor.yml`**](.github/workflows/extract_blobs_to_vendor.yml) | Extract proprietary blobs from a dump using `proprietary-files.txt` and push to `vendor_<brand>_<codename>`. |
| **Cloud ROM Compiler** | [**`cloud_build.yml`**](.github/workflows/cloud_build.yml) | Automated cloud ROM compilation using `roomservice.xml` and `mka bacon`. |
| **Continuous Integration** | [**`ci_tests.yml`**](.github/workflows/ci_tests.yml) | Automated test suite matrix across Ubuntu 22.04 & 24.04 verifying all modules. |

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
└── .github/workflows/          # 9 Dedicated GitHub Actions Workflows
```

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
