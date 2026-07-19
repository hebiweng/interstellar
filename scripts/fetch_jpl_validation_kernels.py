#!/usr/bin/env python3
"""Fetch and verify the large official JPL kernel excluded from normal Git.

Small text kernels remain versioned in ``vendor/jpl-naif``.  The 119 MB SPK is
re-created from its immutable official NAIF URL and is never fetched during a
user calculation.
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
import tempfile
import urllib.request
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
TARGET = REPOSITORY_ROOT / "vendor" / "jpl-naif" / "kernels" / "spk" / "de442.bsp"
SOURCE = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/de442.bsp"
EXPECTED_SIZE = 119_771_136
EXPECTED_SHA256 = "8d5001fab315eeff222cc51f7cf7ffcdb43fb38fb9ac73ff09e09a5b361fd388"


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def _verify(path: Path) -> None:
    if not path.is_file():
        raise RuntimeError(f"missing kernel: {path}")
    if path.stat().st_size != EXPECTED_SIZE:
        raise RuntimeError(f"unexpected size for {path}")
    actual = _sha256(path)
    if actual != EXPECTED_SHA256:
        raise RuntimeError(f"SHA-256 mismatch for {path}: {actual}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="verify the local kernel without downloading it",
    )
    args = parser.parse_args()

    try:
        _verify(TARGET)
        print(f"verified {TARGET.relative_to(REPOSITORY_ROOT)}")
        return 0
    except RuntimeError:
        if args.verify_only:
            raise

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        prefix="de442-",
        suffix=".bsp.part",
        dir=TARGET.parent,
        delete=False,
    ) as temporary:
        temporary_path = Path(temporary.name)
        with urllib.request.urlopen(SOURCE, timeout=60) as response:
            shutil.copyfileobj(response, temporary)
    try:
        _verify(temporary_path)
        temporary_path.replace(TARGET)
    except Exception:
        temporary_path.unlink(missing_ok=True)
        raise
    print(f"downloaded and verified {TARGET.relative_to(REPOSITORY_ROOT)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1) from exc
