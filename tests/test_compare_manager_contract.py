from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANAGER = ROOT / "ios/App/CompareAnalysisManager.swift"


def text():
    assert MANAGER.exists(), "missing CompareAnalysisManager.swift"
    return MANAGER.read_text()


def test_local_bundle_is_persisted_before_ai_generation_and_failure_keeps_it():
    s = text()
    assert "coordinator.calculate" in s
    assert "status: .chartsReady" in s
    assert "store.upsert(localAnalysis)" in s
    assert s.index("store.upsert(localAnalysis)") < s.index("reportService.generate")
    assert "failed.status = .relayFailed" in s
    assert "failed.bundle" not in s, "failure should not replace the stored deterministic bundle"


def test_retry_reuses_analysis_id_as_relay_request_id():
    s = text()
    assert "requestID: current.id" in s
    assert "func retry" in s


def test_failed_compare_is_terminal_until_explicit_retry():
    manager = text()
    view = (ROOT / "ios/App/CompareView.swift").read_text()
    store = (ROOT / "ios/App/CompareAnalysisStore.swift").read_text()
    assert "func reconcilePendingReports" in manager
    assert ".reconcilePendingReports(" in view
    assert ".task { manager.beginReportGeneration" not in view
    assert "catch is URLError" in manager
    network_failure = manager[manager.index("catch is URLError"):]
    assert "current.status = .deliveryFailed" in network_failure
    load = store[store.index("private func load()"):store.index("private func persist()")]
    assert "decoded[index].status" not in load


def test_manual_compare_retry_recovers_existing_relay_result_before_generation():
    manager = text()
    service = (ROOT / "ios/App/CompareAIService.swift").read_text()
    shared = (ROOT / "ios/App/AppAIReportService.swift").read_text()
    retry = manager[manager.index("func retry"):]
    assert "recoverFirst: true" in retry
    assert "statusIfExists" in shared
    generate = service[service.index("func generate("):]
    assert "taskManager.submit(" in generate
    submit = shared[shared.index("func submit<Result>("):shared.index("/// Reconciles an existing task")]
    assert submit.index("recover(") < submit.index("client.createTask")


def test_compare_reconciliation_never_submits_generation_and_only_marks_running_after_relay_status():
    manager = text()
    service = (ROOT / "ios/App/CompareAIService.swift").read_text()
    shared = (ROOT / "ios/App/AppAIReportService.swift").read_text()
    reconcile = manager[manager.index("func reconcilePendingReports"):manager.index("func analyze")]
    assert "reportService.recover" in reconcile
    assert "reportService.generate" not in reconcile
    recover = service[service.index("func recover("):service.index("func generate(")]
    assert "taskManager.recover(" in recover
    assert "onGenerating: onGenerating" in recover
    shared_recover = shared[shared.index("func recover<Result>("):shared.index("private func waitForResult")]
    assert "client.createTask" not in shared_recover
    assert "onGenerating()" in shared_recover
