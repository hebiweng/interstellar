#!/usr/bin/env python3
"""Validate an official GeoNames dump and emit normalized JSON Lines.

This command never downloads data. The caller supplies previously acquired,
checksummed files from an active dataset release.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path

from interstellar_core.location.importers import (
    iter_geonames,
    load_alternate_names,
    merge_alternate_names,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--places", type=Path, required=True, help="Unzipped allCountries.txt")
    parser.add_argument("--alternate-names", type=Path, help="Unzipped alternateNamesV2.txt")
    parser.add_argument("--output", type=Path, required=True, help="Normalized JSONL destination")
    parser.add_argument("--limit", type=int, help="Fixture/dev-only maximum record count")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    alternates: dict[int, tuple[str, ...]] = {}
    if args.alternate_names:
        with args.alternate_names.open(encoding="utf-8") as handle:
            alternates = load_alternate_names(handle)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with args.places.open(encoding="utf-8") as source, args.output.open(
        "w", encoding="utf-8"
    ) as destination:
        records = merge_alternate_names(iter_geonames(source), alternates)
        for record in records:
            if args.limit is not None and count >= args.limit:
                break
            destination.write(json.dumps(asdict(record), ensure_ascii=False, sort_keys=True) + "\n")
            count += 1
    print(json.dumps({"records": count, "output": str(args.output)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
