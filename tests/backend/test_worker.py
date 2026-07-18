from __future__ import annotations

import json
from pathlib import Path

import pytest

from interstellar_worker.config import WorkerSettings
from interstellar_worker.health import check_heartbeat, write_heartbeat
from interstellar_worker.main import run_cli


def _settings(path: Path) -> WorkerSettings:
    return WorkerSettings(
        service_name="test-worker",
        service_version="0.1.0",
        heartbeat_path=path,
        heartbeat_interval_seconds=0.01,
        heartbeat_max_age_seconds=30,
    )


def test_worker_once_writes_an_atomic_health_record(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    path = tmp_path / "worker" / "heartbeat.json"

    assert run_cli(["--once"], settings=_settings(path)) == 0
    output = json.loads(capsys.readouterr().out)

    assert output["service"] == "test-worker"
    assert output["sequence"] == 1
    assert path.exists()
    assert check_heartbeat(path, max_age_seconds=30).healthy is True


def test_worker_health_check_detects_missing_and_stale_files(tmp_path: Path) -> None:
    path = tmp_path / "heartbeat.json"
    assert check_heartbeat(path, max_age_seconds=30).healthy is False

    heartbeat = write_heartbeat(
        path, service="test-worker", version="0.1.0", sequence=1
    )
    stale = check_heartbeat(
        path,
        max_age_seconds=30,
        now=heartbeat.timestamp_unix + 31,
    )
    assert stale.healthy is False
    assert stale.detail == "heartbeat is stale"


def test_worker_settings_validate_positive_intervals(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="greater than zero"):
        WorkerSettings.from_env(
            {
                "INTERSTELLAR_WORKER_HEARTBEAT_PATH": str(tmp_path / "heartbeat.json"),
                "INTERSTELLAR_WORKER_HEARTBEAT_INTERVAL_SECONDS": "0",
            }
        )
