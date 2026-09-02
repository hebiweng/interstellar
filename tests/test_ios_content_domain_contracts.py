import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_app_language_has_nine_locales_and_explicit_content_domains():
    source = read("ios/App/Models.swift")
    for raw_value in ["en", "zh-Hans", "es", "fr", "de", "it", "pt-BR", "tr", "ko"]:
        assert f'= "{raw_value}"' in source
    assert "corpusLanguage" not in source
    for property_name in ["chartContentLanguage", "todayContentLanguage", "weekContentLanguage", "askContentLanguage", "reportRequestLanguage"]:
        assert property_name in source


def test_consumer_content_loader_requires_matching_area_locale_and_schema():
    source = read("ios/App/InsightContent.swift")
    assert "enum ConsumerContentArea" in source
    assert 'case today' in source and 'case week' in source and 'case ask' in source
    assert 'PrivateContent-\\(area.rawValue)-\\(contentLanguage.rawValue)' in source
    assert "pack.schemaVersion == 1" in source
    assert "pack.locale == contentLanguage.rawValue" in source
    assert "pack.area == area" in source


def test_chart_cards_use_copy_catalog_without_legacy_private_corpus_fallback():
    model = read("ios/App/AppModel.swift")
    assert "corpusProviders" not in model
    assert "CorpusContentProvider(language:" not in model
    assert "content: nil" in model


def test_today_content_error_is_separate_from_chart_calculation_error():
    model = read("ios/App/AppModel.swift")
    view = read("ios/App/TodayView.swift")
    assert "todayContentErrorMessage" in model
    assert "ConsumerContentError" in model
    assert 'localized("app.error.local-chart-calculation"' in model
    assert "makeTodayDashboard" in model
    assert "todayContentErrorMessage" in view


def test_fixed_ui_and_astrology_terms_register_portuguese_brazil():
    expected_locales = {"en", "zh", "es", "fr", "tr", "de", "it", "pt-BR", "ko"}
    for path in (ROOT / "ios" / "Localization" / "UI").glob("*.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        for key, entry in data.items():
            assert set(entry) == expected_locales, (path.name, key)
    terms = json.loads(read("ios/App/Resources/AstroTerms-pt-BR.json"))
    assert terms["locale"] == "pt-BR"
    assert (ROOT / "ios/App/Resources/Help/abc-life-areas-help-pt-BR.md").exists()


def test_cancel_subscription_uses_native_storekit_management_sheet():
    source = read("ios/App/ProfileView.swift")
    assert "commerce.cancel-subscription" in source
    assert "manageSubscriptionsSheet" in source
