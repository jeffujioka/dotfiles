#!/usr/bin/env python3
"""Read values from manifest.toml and output them for shell consumption.

Usage:
  ./helpers/read-manifest.py packages.linux.list          # one item per line
  ./helpers/read-manifest.py cargo.tools                   # one item per line
  ./helpers/read-manifest.py symlinks --format jsonl       # one JSON object per line
  ./helpers/read-manifest.py resources --format jsonl      # one JSON object per line
"""

import argparse
import json
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:
    print("Error: Python 3.11+ required (for tomllib).", file=sys.stderr)
    sys.exit(1)


def find_manifest(script_path):
    """Find manifest.toml relative to this script (repo_root/helpers/read-manifest.py)."""
    repo_root = script_path.resolve().parent.parent
    manifest = repo_root / "manifest.toml"
    if manifest.exists():
        return manifest
    raise FileNotFoundError(f"manifest.toml not found at {manifest}")


def get_nested(data, key_path):
    """Navigate nested dict using dot notation: 'packages.linux.list'."""
    keys = key_path.split(".")
    current = data
    for key in keys:
        if isinstance(current, dict) and key in current:
            current = current[key]
        else:
            print(f"Error: key '{key_path}' not found in manifest.toml", file=sys.stderr)
            sys.exit(1)
    return current


def main():
    parser = argparse.ArgumentParser(description="Read manifest.toml values")
    parser.add_argument("key", help="Dot-separated key path (e.g., packages.linux.list)")
    parser.add_argument(
        "--format",
        choices=["plain", "jsonl"],
        default="plain",
        help="Output format (default: plain)",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=None,
        help="Path to manifest.toml (auto-detected if omitted)",
    )
    args = parser.parse_args()

    manifest_path = args.manifest or find_manifest(Path(__file__))

    with open(manifest_path, "rb") as f:
        data = tomllib.load(f)

    value = get_nested(data, args.key)

    if args.format == "jsonl":
        if isinstance(value, list):
            for item in value:
                print(json.dumps(item))
        else:
            print(json.dumps(value))
    else:
        if isinstance(value, list):
            for item in value:
                if isinstance(item, dict):
                    print(json.dumps(item))
                else:
                    print(item)
        elif isinstance(value, dict):
            print(json.dumps(value))
        else:
            print(value)


if __name__ == "__main__":
    main()
