from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / 'ios'
PBX = IOS / 'Interstellar.xcodeproj' / 'project.pbxproj'


def _swift_names_in_project():
    text = PBX.read_text()
    raw = re.findall(r'path = \"?([^;\"]+\.swift)\"?;', text)
    return {Path(value).name for value in raw}


def test_checked_in_xcodeproj_has_no_stale_swift_file_references():
    names = _swift_names_in_project()
    app_names = {p.name for p in (IOS / 'App').rglob('*.swift')}
    stale = sorted(name for name in names if name not in app_names and not (IOS / 'Tests' / name).exists() and not (IOS / 'UITests' / name).exists())
    assert stale == []


def test_checked_in_xcodeproj_includes_every_app_swift_source():
    text = PBX.read_text()
    missing = sorted(str(p.relative_to(IOS / 'App')) for p in (IOS / 'App').rglob('*.swift') if p.name not in text)
    assert missing == []

