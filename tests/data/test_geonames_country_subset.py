from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path
from zipfile import ZipFile

from interstellar_core.location.importers import load_geonames


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).parent / "fixtures"
SCRIPT = ROOT / "scripts" / "data" / "build_geonames_country_subset.py"


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _build_subset(tmp_path: Path, output_name: str) -> tuple[Path, dict[str, object]]:
    places = tmp_path / "cities500.zip"
    with ZipFile(places, "w") as archive:
        archive.write(FIXTURES / "geonames.tsv", arcname="cities500.txt")
    admin1 = tmp_path / "admin1.txt"
    admin1.write_text(
        "CN.22\tBeijing Municipality\tBeijing Municipality\t2038349\n"
        "US.IL\tIllinois\tIllinois\t4896861\n",
        encoding="utf-8",
    )
    admin2 = tmp_path / "admin2.txt"
    admin2.write_text(
        "CN.22.11876380\tBeijing\tBeijing\t11876380\n"
        "US.IL.167\tSangamon County\tSangamon County\t4250554\n",
        encoding="utf-8",
    )
    output = tmp_path / output_name
    result = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--places",
            str(places),
            "--admin1",
            str(admin1),
            "--admin2",
            str(admin2),
            "--country-code",
            "CN",
            "--source-version",
            "2026-07-19",
            "--output-dir",
            str(output),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return output, json.loads(result.stdout)


def test_country_subset_is_filtered_versioned_and_deterministic(tmp_path: Path) -> None:
    first, summary = _build_subset(tmp_path, "first")
    second, _ = _build_subset(tmp_path, "second")

    archive_name = "cities500-CN-2026-07-19.zip"
    places = load_geonames(first / archive_name)
    assert tuple(place.country_code for place in places) == ("CN",)
    assert places[0].name == "Beijing"
    assert summary["place_records"] == 1
    assert (first / "admin1CodesASCII-CN-2026-07-19.txt").read_text(
        encoding="utf-8"
    ).startswith("CN.22\t")
    assert "US." not in (first / "admin2Codes-CN-2026-07-19.txt").read_text(
        encoding="utf-8"
    )
    assert _sha256(first / archive_name) == _sha256(second / archive_name)
