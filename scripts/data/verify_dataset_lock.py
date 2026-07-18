#!/usr/bin/env python3
"""Offline verification of a dataset catalog and active lock."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from interstellar_core.datasets import DatasetRegistry


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--lock", type=Path, required=True)
    parser.add_argument("--artifact-root", type=Path, required=True)
    parser.add_argument("--require-v1", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    registry = DatasetRegistry.from_catalog(args.catalog)
    registry.load_active_lock(args.lock, args.artifact_root)
    if args.require_v1:
        registry.assert_required_active()
    print(json.dumps({"status": "verified", "lock": str(args.lock)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
