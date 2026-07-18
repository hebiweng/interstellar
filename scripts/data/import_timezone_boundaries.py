#!/usr/bin/env python3
"""Validate a local Timezone Boundary Builder GeoJSON and emit JSON Lines."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from interstellar_core.location.importers import load_timezone_geojson


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    features = load_timezone_geojson(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as destination:
        for feature in features:
            destination.write(json.dumps(feature, ensure_ascii=False, sort_keys=True) + "\n")
    print(json.dumps({"features": len(features), "output": str(args.output)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
