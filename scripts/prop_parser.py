#!/usr/bin/env python3
"""
Prop Parser for Android Dumps
Extracts device identities, platform targets, fingerprint, and Android OS versions
from stock build.prop files across all dumped partitions.
"""

import sys
import os
import re
import json

def parse_props_from_file(filepath):
    props = {}
    if not os.path.isfile(filepath):
        return props
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if '=' in line:
                    key, val = line.split('=', 1)
                    props[key.strip()] = val.strip()
    except Exception as e:
        pass
    return props

def aggregate_props(dump_dir):
    aggregated = {}
    prop_files = []
    
    # Priority order: vendor > system > product > system_ext > odm
    for root, _, files in os.walk(dump_dir):
        for file in files:
            if file.endswith('.prop') or file == 'build.prop':
                prop_files.append(os.path.join(root, file))

    # Sort so vendor and system take precedence appropriately
    prop_files.sort(key=lambda x: (
        0 if 'vendor' in x else
        1 if 'system' in x else
        2 if 'system_ext' in x else
        3 if 'product' in x else
        4 if 'odm' in x else 5
    ))

    for pfile in prop_files:
        props = parse_props_from_file(pfile)
        aggregated.update(props)

    # Resolve core properties
    def get_first(*keys, default=""):
        for k in keys:
            v = aggregated.get(k)
            if v:
                return v
        return default

    brand = get_first(
        'ro.product.vendor.brand', 'ro.product.brand',
        'ro.product.system.brand', 'ro.product.odm.brand',
        'ro.product.product.brand', default='generic'
    ).lower().replace(' ', '_')

    codename = get_first(
        'ro.product.vendor.device', 'ro.product.device',
        'ro.build.product', 'ro.product.system.device',
        'ro.product.odm.device', default='device'
    ).lower().replace(' ', '_')

    model = get_first(
        'ro.product.vendor.model', 'ro.product.model',
        'ro.product.system.model', 'ro.product.odm.model',
        default=f"{brand.capitalize()} {codename.capitalize()}"
    )

    name = get_first(
        'ro.product.vendor.name', 'ro.product.name',
        'ro.product.system.name', default=codename
    )

    platform = get_first(
        'ro.board.platform', 'ro.hardware',
        'ro.boot.hardware', 'ro.soc.manufacturer',
        default='generic'
    ).lower()

    android_version = get_first(
        'ro.build.version.release', 'ro.vendor.build.version.release',
        'ro.system.build.version.release', default='14'
    )

    security_patch = get_first(
        'ro.build.version.security_patch', 'ro.vendor.build.security_patch',
        default='2024-01-01'
    )

    fingerprint = get_first(
        'ro.vendor.build.fingerprint', 'ro.build.fingerprint',
        'ro.system.build.fingerprint',
        default=f"{brand}/{codename}/{codename}:{android_version}/RELEASE/user:release-keys"
    )

    cpu_abi = get_first(
        'ro.product.cpu.abi', 'ro.vendor.product.cpu.abi',
        'ro.system.product.cpu.abi', default='arm64-v8a'
    )

    first_api = get_first(
        'ro.product.first_api_level', 'ro.board.first_api_level',
        default='30'
    )

    result = {
        'brand': brand,
        'codename': codename,
        'model': model,
        'name': name,
        'platform': platform,
        'android_version': android_version,
        'security_patch': security_patch,
        'fingerprint': fingerprint,
        'cpu_abi': cpu_abi,
        'first_api_level': first_api
    }
    return result

def main():
    if len(sys.argv) < 2:
        print("Usage: prop_parser.py <DUMP_DIRECTORY> [--shell]", file=sys.stderr)
        sys.exit(1)

    dump_dir = sys.argv[1]
    shell_mode = '--shell' in sys.argv

    if not os.path.isdir(dump_dir):
        print(f"[ERROR] Directory does not exist: {dump_dir}", file=sys.stderr)
        sys.exit(1)

    data = aggregate_props(dump_dir)

    if shell_mode:
        for k, v in data.items():
            safe_val = str(v).replace('"', '\\"')
            print(f"export {k.upper()}=\"{safe_val}\"")
    else:
        print(json.dumps(data, indent=2))

if __name__ == '__main__':
    main()
