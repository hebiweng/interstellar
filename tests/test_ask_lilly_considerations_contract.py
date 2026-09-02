import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_resolved_judgment_uses_planetary_hour_and_timezone():
    core = read("ios/Packages/AstroCore/Sources/AstroCore/HoraryCore.swift")
    app_model = read("ios/App/AppModel.swift")
    actions = read("ios/App/Ask/AskActions.swift")
    assert "resolveHoraryPlanetaryHour" in core
    assert "timeZone: TimeZone? = nil" in core
    assert "timeZone: TimeZone? = nil" in app_model
    assert "TimeZone(identifier: location.timezoneID)" in actions


def test_deep_analysis_emits_consideration_and_planetary_hour_evidence():
    deep = read("ios/App/AskDeepAnalysis.swift")
    assert 'factType: "judgment_reliability"' in deep
    assert 'factType: "planetary_hour"' in deep
    assert 'factType: "radicality"' in deep
    assert 'factType: "consideration"' in deep


def test_professional_view_surfaces_considerations_without_probability_language():
    professional = read("ios/App/Ask/AskProfessionalView.swift")
    assert 'localized("ask.considerations"' in professional
    assert 'localized("ask.judgment-clarity"' in professional
    assert 'localized("ask.planetary-hour"' in professional
    assert 'localized("ask.radicality"' in professional
    assert 'radicalityLabel(' in professional
    assert r'ask.consideration.\(kind.rawValue)' not in professional
    for key in [
        'planetaryHourDiscordant', 'earlyAscendant', 'lateAscendant', 'moonLateDegrees',
        'moonViaCombusta', 'moonVoidOfCourse', 'saturnInAscendant', 'saturnInSeventh',
        'ascendantLordCombust', 'seventhCuspAfflicted', 'seventhLordUnfortunate', 'seventhLordRetrograde', 'seventhLordInFall',
        'seventhLordInMaleficTerm', 'saturnInTenthUnfortunate', 'marsInTenthUnfortunate',
        'southNodeInTenth',
    ]:
        assert f'localized("ask.consideration.{key}"' in professional


def test_consideration_localization_is_complete_for_all_nine_locales():
    data = json.loads(read("ios/Localization/UI/today-ask.json"))
    locales = {"en", "zh", "es", "fr", "tr", "de", "it", "ko", "pt-BR"}
    keys = {
        "ask.considerations",
        "ask.judgment-clarity",
        "ask.reliability.high",
        "ask.reliability.moderate",
        "ask.reliability.caution",
        "ask.planetary-hour",
        "ask.planetary-hour-unavailable",
        "ask.planetary-hour-agrees",
        "ask.planetary-hour-differs",
        "ask.radicality",
        "ask.radicality.supported",
        "ask.radicality.not-established",
        "ask.radicality.unavailable",
        "ask.consideration.planetaryHourDiscordant",
        "ask.consideration.earlyAscendant",
        "ask.consideration.lateAscendant",
        "ask.consideration.moonLateDegrees",
        "ask.consideration.moonViaCombusta",
        "ask.consideration.moonVoidOfCourse",
        "ask.consideration.saturnInAscendant",
        "ask.consideration.saturnInSeventh",
        "ask.consideration.ascendantLordCombust",
        "ask.consideration.seventhCuspAfflicted",
        "ask.consideration.seventhLordUnfortunate",
        "ask.consideration.seventhLordRetrograde",
        "ask.consideration.seventhLordInFall",
        "ask.consideration.seventhLordInMaleficTerm",
        "ask.consideration.saturnInTenthUnfortunate",
        "ask.consideration.marsInTenthUnfortunate",
        "ask.consideration.southNodeInTenth",
    }
    for key in keys:
        assert key in data, key
        assert set(data[key]) == locales, key
        assert all(str(data[key][locale]).strip() for locale in locales), key
