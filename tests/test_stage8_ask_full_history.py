from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "ios" / "App"


def read(name: str) -> str:
    return (APP / name).read_text()


def test_horary_session_is_persistable():
    source = read("AskHistory.swift")
    assert "struct HorarySession: Codable, Equatable" in source or "struct HorarySession: Equatable, Codable" in source


def test_history_entry_carries_versioned_full_session_snapshot():
    source = read("AskHistory.swift")
    assert "currentSchemaVersion" in source
    assert "let session: HorarySession?" in source
    assert "decodeIfPresent(HorarySession.self" in source
    assert "decodeIfPresent(Int.self" in source


def test_new_history_entries_store_complete_session():
    source = read("SynastryView.swift")
    start = source.index("private func historyEntry(from session: HorarySession)")
    block = source[start:start + 2500]
    assert "session: session" in block


def test_history_rows_open_full_results_when_snapshot_exists():
    source = read("SynastryView.swift")
    assert "let onOpen: (AskHistoryEntry) -> Void" in source
    assert "onOpen(entry)" in source
    assert "entry.session != nil" in source


def test_opening_history_restores_session_without_recalculation():
    source = read("SynastryView.swift")
    assert "private func openHistoryEntry" in source
    start = source.index("private func openHistoryEntry")
    block = source[start:start + 1600]
    assert "entry.session" in block
    assert "session = restoredSession" in block
    assert "mode = restoredSession.mode" in block
    assert "calculateHorarySnapshot" not in block
    assert "searchElectionTiming" not in block


def test_history_route_reuses_existing_result_and_professional_analysis_pages():
    source = read("SynastryView.swift")
    assert "resultView(session)" in source
    assert "HoraryProfessionalView(session: session" in source
    # History is wired back into the same Ask flow rather than a lossy summary-only detail.
    assert "openHistoryEntry(entry)" in source

