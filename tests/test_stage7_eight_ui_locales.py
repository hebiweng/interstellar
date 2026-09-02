import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / 'ios'
EXPECTED_SOURCE_LOCALES = {'en','zh','es','fr','tr','de','it','ko'}
EXPECTED_APP_LOCALES = {'en','zh-Hans','es','fr','tr','de','it','ko'}


def test_ui_translations_are_split_into_fragments_with_eight_locales():
    legacy = IOS / 'Localization' / 'ui-translations.json'
    assert not legacy.exists(), 'legacy monolithic ui-translations.json should be removed'
    ui_dir = IOS / 'Localization' / 'UI'
    fragments = sorted(ui_dir.glob('*.json'))
    assert len(fragments) >= 6
    merged = {}
    for path in fragments:
        payload = json.loads(path.read_text())
        assert payload, path
        overlap = set(merged) & set(payload)
        assert not overlap, f'duplicate localization keys: {sorted(overlap)[:5]}'
        merged.update(payload)
    assert len(merged) >= 1073
    for key, entry in merged.items():
        assert set(entry) == EXPECTED_SOURCE_LOCALES, key
        assert all(isinstance(value, str) and value.strip() for value in entry.values()), key
        expected = sorted(re.findall(r'\{\{[A-Za-z][A-Za-z0-9]*\}\}', entry['en']))
        for locale in EXPECTED_SOURCE_LOCALES - {'en'}:
            assert sorted(re.findall(r'\{\{[A-Za-z][A-Za-z0-9]*\}\}', entry[locale])) == expected, (key, locale)


def test_app_language_exposes_eight_ui_languages_and_new_locales_use_english_corpus():
    source = (IOS / 'App' / 'Models.swift').read_text()
    for raw in EXPECTED_APP_LOCALES:
        assert f'= "{raw}"' in source
    assert 'case turkish' in source
    assert 'case german' in source
    assert 'case italian' in source
    assert 'case korean' in source
    assert 'case .turkish, .german, .italian, .korean:' in source
    assert '.english' in source[source.index('var corpusLanguage'):source.index('enum AppAppearance')]


def test_astro_terms_exist_for_all_eight_ui_locales():
    for locale in EXPECTED_APP_LOCALES:
        path = IOS / 'App' / 'Resources' / f'AstroTerms-{locale}.json'
        assert path.exists(), locale
        payload = json.loads(path.read_text())
        assert payload['locale'] == locale



def test_astro_terms_and_builder_accept_relationship_supplemental_bodies():
    expected = {'sun','moon','mercury','venus','mars','jupiter','saturn','uranus','neptune','pluto','trueNode','lilith','partOfFortune','juno'}
    for locale in EXPECTED_APP_LOCALES:
        payload = json.loads((IOS / 'App' / 'Resources' / f'AstroTerms-{locale}.json').read_text())
        assert set(payload['bodies']) == expected, locale
    source = (ROOT / 'scripts' / 'build-ios-localization.mjs').read_text()
    for key in ['lilith', 'partOfFortune', 'juno']:
        assert f'"{key}"' in source

def test_localization_builder_reads_fragments_and_emits_eight_locales():
    source = (ROOT / 'scripts' / 'build-ios-localization.mjs').read_text()
    assert 'Localization", "UI"' in source or "Localization', 'UI'" in source
    for locale in ['tr','de','it','ko']:
        assert f'"{locale}"' in source
    assert 'ui-translations.json' not in source


def test_project_validation_inputs_include_fragment_directory_and_new_astro_terms():
    source = (IOS / 'project.yml').read_text()
    assert 'Localization/UI/' in source
    assert 'Localization/ui-translations.json' not in source
    for locale in ['tr','de','it','ko']:
        assert f'AstroTerms-{locale}.json' in source


def test_copy_catalog_uses_corpus_language_for_ui_only_locales():
    source = (IOS / 'App' / 'InsightContent.swift').read_text()
    section = source[source.index('struct CopyCatalogMatcher'):source.index('func value(at sourcePath')]
    assert 'language.corpusLanguage' in section


def test_new_ui_locales_are_actually_translated_not_mass_english_fallbacks():
    ui_dir = IOS / 'Localization' / 'UI'
    merged = {}
    for path in ui_dir.glob('*.json'):
        merged.update(json.loads(path.read_text()))
    for locale in ['tr', 'de', 'it', 'ko']:
        same = [key for key, entry in merged.items() if entry[locale].strip() == entry['en'].strip()]
        assert len(same) / len(merged) < 0.06, (locale, same[:30])


def test_life_area_help_is_localized_for_all_eight_ui_locales():
    for locale in EXPECTED_APP_LOCALES:
        path = IOS / 'App' / 'Resources' / 'Help' / f'abc-life-areas-help-{locale}.md'
        assert path.exists(), locale
        assert len(path.read_text().strip()) > 200
    source = (IOS / 'App' / 'SynastryView.swift').read_text()
    for token in ['case .turkish: "tr"', 'case .german: "de"', 'case .italian: "it"', 'case .korean: "ko"']:
        assert token in source


def test_location_permission_prompt_is_localized_for_all_eight_ui_locales():
    for locale in EXPECTED_APP_LOCALES:
        path = IOS / 'App' / f'{locale}.lproj' / 'InfoPlist.strings'
        assert path.exists(), locale
        text = path.read_text().strip()
        assert 'NSLocationWhenInUseUsageDescription' in text
        assert len(text) > 80


def test_checked_in_xcode_project_registers_all_eight_infoplist_localizations():
    source = (IOS / 'Interstellar.xcodeproj' / 'project.pbxproj').read_text()
    group = source[source.index('/* Begin PBXVariantGroup section */'):source.index('/* End PBXVariantGroup section */')]
    for locale in EXPECTED_APP_LOCALES:
        assert f'/* {locale} */' in group, locale

