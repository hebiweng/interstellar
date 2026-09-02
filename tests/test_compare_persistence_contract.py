from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / "ios/App/CompareAnalysisStore.swift"


def read() -> str:
    assert STORE.exists(), "missing CompareAnalysisStore.swift"
    return STORE.read_text()


def test_compare_store_persists_request_bundle_result_and_status_atomically():
    s = read()
    for token in ["CompareRequest", "CompareCalculationBundle", "CompareNarrativeResponse", "CompareAnalysisStatus"]:
        assert token in s
    assert ".atomic" in s
    assert "chartsReady" in s
    assert "generatingReport" in s
    assert "completed" in s
    assert "reportFailed" in s


def test_compare_history_shows_six_recent_jobs_and_persists_a_bounded_history():
    s = read()
    assert "recentHistoryLimit = 6" in s
    assert "persistedHistoryLimit = 100" in s
    assert "var recentAnalyses" in s
    assert "prefix(Self.recentHistoryLimit)" in s
