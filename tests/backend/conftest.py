"""Path setup for running M0 tests without installing local packages."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
for package_root in (ROOT / "apps" / "api", ROOT / "apps" / "worker", ROOT / "python"):
    sys.path.insert(0, str(package_root))
