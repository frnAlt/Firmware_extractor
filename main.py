#!/usr/bin/env python3
"""
Universal Firmware Extractor, Dump Pusher & Multi-ROM Tree Generator
Master Orchestrator CLI (Python 3)
"""

import os
import sys
import argparse
from typing import Optional

from extractor.firmware_engine import FirmwareEngine
from extractor.metadata_parser import MetadataParser
from github_pusher.dump_pusher import DumpPusher
from tree_generator.device_tree import DeviceTreeGenerator
from tree_generator.vendor_tree import VendorTreeGenerator
from tree_generator.kernel_tree import KernelTreeGenerator
from rom_adapter.adapter import RomAdapter
from manifest_builder.roomservice import RoomserviceBuilder

def main():
    parser = argparse.ArgumentParser(
        description="Universal Firmware Extractor, GitHub Dump Pusher & Multi-ROM Device Tree Generator",
        formatter_class=argparse.RawTextHelpFormatter,
    )

    input_group = parser.add_mutually_exclusive_group(required=False)
    input_group.add_argument("-u", "--url", type=str, help="Firmware download URL (Direct link, Google Drive, SourceForge, AFH)")
    input_group.add_argument("-f", "--path", "--file", dest="path", type=str, help="Local firmware package (.zip, .tar.md5, payload.bin, .ozip, .pac, etc.)")
    input_group.add_argument("-d", "--dump-dir", type=str, help="Path to already extracted filesystem dump directory")

    parser.add_argument("-o", "--out", type=str, default="out", help="Output root directory (default: out/)")
    parser.add_argument("--rom-type", type=str, choices=RomAdapter.SUPPORTED_ROMS, default="lineageos", help="Target Custom ROM flavor (default: lineageos)")
    parser.add_argument("--push-github", action="store_true", help="Automatically push dumps and generated trees to GitHub")
    parser.add_argument("--target-org", type=str, default=os.environ.get("GITHUB_ACTOR", "frnAlt"), help="GitHub organization or username (default: current user)")
    parser.add_argument("--branch", type=str, default="lineage-21.0", help="Git branch name (default: lineage-21.0)")
    parser.add_argument("--token", type=str, default=os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN"), help="GitHub personal access token")
    parser.add_argument("--lfs", action="store_true", help="Enable Git LFS for large files (>50MB)")
    parser.add_argument("--no-trees", action="store_true", help="Skip AOSP/LineageOS tree generation")
    parser.add_argument("--generate-manifest", action="store_true", help="Generate .repo/local_manifests/roomservice.xml")
    parser.add_argument("--dry-run", action="store_true", help="Simulate Git pushes and repository creation without pushing")

    args = parser.parse_args()

    if not args.url and not args.path and not args.dump_dir:
        parser.print_help()
        sys.exit(1)

    out_dir = os.path.abspath(args.out)
    os.makedirs(out_dir, exist_ok=True)
    images_dir = os.path.join(out_dir, "images")
    dump_dir = os.path.abspath(args.dump_dir) if args.dump_dir else os.path.join(out_dir, "dump")
    trees_dir = os.path.join(out_dir, "trees")

    print("=" * 80)
    print(" Universal Android Firmware Extractor & Multi-ROM Tree Generator")
    print("=" * 80)
    print(f" Target Account: {args.target_org}")
    print(f" Target ROM:     {args.rom_type}")
    print(f" Target Branch:  {args.branch}")
    print("=" * 80)

    # --------------------------------------------------------------------------
    # Module 1: Firmware Extraction
    # --------------------------------------------------------------------------
    if not args.dump_dir:
        target_input = args.url if args.url else args.path
        engine = FirmwareEngine()
        ext_result = engine.run_extraction(target_input, out_dir)
        metadata = ext_result["metadata"]
    else:
        print(f"[Module 1] Using existing dump directory: {dump_dir}")
        parser_meta = MetadataParser(dump_dir)
        metadata = parser_meta.extract_metadata()
        parser_meta.generate_all_files_index()
        parser_meta.generate_board_info()
        parser_meta.save_metadata_json()

    brand = metadata.get("brand", "generic")
    codename = metadata.get("codename", "device")
    print(f"[Device Identity] {brand.upper()} {codename.upper()} ({metadata.get('model')})")
    print(f"[Fingerprint]     {metadata.get('fingerprint')}")

    # --------------------------------------------------------------------------
    # Module 2: GitHub Dump Pusher
    # --------------------------------------------------------------------------
    if args.push_github:
        print("\n" + "=" * 80)
        print(" [Module 2] Pushing Raw Firmware Dump to GitHub")
        print("=" * 80)
        pusher = DumpPusher(target_account=args.target_org, auth_token=args.token, dry_run=args.dry_run)
        pusher.push_dump_repo(
            dump_dir=dump_dir,
            brand=brand,
            codename=codename,
            branch=args.branch,
            use_lfs=args.lfs,
        )

    # --------------------------------------------------------------------------
    # Module 3: Multi-ROM Tree Generation
    # --------------------------------------------------------------------------
    if not args.no_trees:
        print("\n" + "=" * 80)
        print(f" [Module 3] Generating Multi-ROM Trees for {args.rom_type.upper()}")
        print("=" * 80)
        os.makedirs(trees_dir, exist_ok=True)

        # 1. Device Tree
        dev_gen = DeviceTreeGenerator(dump_dir, metadata)
        device_dir = dev_gen.generate(trees_dir)
        print(f"[Device Tree] {device_dir}")

        # 2. Vendor Tree
        ven_gen = VendorTreeGenerator(dump_dir, metadata)
        vendor_dir = ven_gen.generate(trees_dir)
        print(f"[Vendor Tree] {vendor_dir}")

        # 3. Kernel Prebuilt Tree
        kern_gen = KernelTreeGenerator(dump_dir, metadata)
        kernel_dir = kern_gen.generate(trees_dir)
        print(f"[Kernel Tree] {kernel_dir}")

        # 4. Multi-ROM Adapters
        adapter = RomAdapter(device_dir, metadata)
        adapted_files = adapter.adapt_to(args.rom_type)
        print(f"[ROM Adapters] Generated configs: {', '.join([os.path.basename(f) for f in adapted_files])}")

        # Push generated trees to GitHub
        if args.push_github or args.dry_run:
            from github_pusher.dump_pusher import DumpPusher
            print("\n[Module 3] Pushing Device, Vendor, and Kernel trees to GitHub...")
            for tree_type, t_dir in [("device", device_dir), ("vendor", vendor_dir), ("kernel", kernel_dir)]:
                tree_pusher = DumpPusher(target_account=args.target_org, auth_token=args.token, dry_run=args.dry_run)
                tree_pusher.push_dump_repo(
                    dump_dir=t_dir,
                    brand=brand,
                    codename=codename,
                    branch=args.branch,
                    use_lfs=False,
                )

    # --------------------------------------------------------------------------
    # Module 4: Local Manifest & Build Integration
    # --------------------------------------------------------------------------
    if args.generate_manifest or args.push_github:
        print("\n" + "=" * 80)
        print(" [Module 4] Generating .repo/local_manifests/roomservice.xml")
        print("=" * 80)
        roomservice_out = os.path.join(out_dir, "roomservice.xml")
        manifest_builder = RoomserviceBuilder(
            target_account=args.target_org,
            brand=brand,
            codename=codename,
            branch=args.branch,
        )
        manifest_builder.write_to_file(roomservice_out)
        print(f"[Roomservice] Manifest saved at {roomservice_out}")

    print("\n" + "=" * 80)
    print(" Pipeline Execution Finished Successfully!")
    print(f" Dump Directory:  {dump_dir}")
    print(f" Trees Directory: {trees_dir}")
    print("=" * 80)

if __name__ == "__main__":
    main()
