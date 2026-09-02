import json
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / "ios" / "PrivateContent"
SCRIPT = ROOT / "scripts" / "build-ios-private-content.mjs"


def test_private_content_builder_generates_domain_specific_runtime_files(tmp_path):
    if not PRIVATE.exists():
        pytest.skip("Private editorial sources are intentionally absent from the public checkout")

    output = tmp_path / "PrivateContent"
    result = subprocess.run(
        ["node", str(SCRIPT), "--build", "--output", str(output)],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    assert result.returncode == 0, result.stderr or result.stdout
    payload = json.loads(result.stdout)
    assert payload["generated"] == 10
    assert (output / "PrivateContent-today-en.json").exists()
    assert (output / "PrivateContent-today-zh-Hans.json").exists()
    assert (output / "PrivateContent-week-en.json").exists()
    assert (output / "PrivateContent-week-zh-Hans.json").exists()
    assert (output / "PrivateContent-ask-en.json").exists()
    assert (output / "PrivateContent-ask-zh-Hans.json").exists()
    for locale in ["en", "zh-Hans", "es", "fr"]:
        assert (output / f"CopyCatalog-{locale}.json").exists()

    validation = subprocess.run(
        ["node", str(SCRIPT), "--validate", "--output", str(output)],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    assert validation.returncode == 0, validation.stderr or validation.stdout


def test_today_and_ask_sources_have_exact_locale_and_placeholder_parity():
    if not PRIVATE.exists():
        pytest.skip("Private editorial sources are intentionally absent from the public checkout")

    for area in ["today", "week", "ask"]:
        english = json.loads((PRIVATE / area / "Content-en.json").read_text(encoding="utf-8"))
        chinese = json.loads((PRIVATE / area / "Content-zh-Hans.json").read_text(encoding="utf-8"))
        assert english["schemaVersion"] == chinese["schemaVersion"] == 1
        assert english["area"] == chinese["area"] == area
        assert english["locale"] == "en"
        assert chinese["locale"] == "zh-Hans"
        english_by_key = {entry["contentKey"]: entry for entry in english["entries"]}
        chinese_by_key = {entry["contentKey"]: entry for entry in chinese["entries"]}
        assert set(chinese_by_key) == set(english_by_key)
        assert all(entry["translationStatus"] == "approved" for entry in english_by_key.values())
        assert all(entry["translationStatus"] == "approved" for entry in chinese_by_key.values())
