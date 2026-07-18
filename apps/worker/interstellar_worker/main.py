"""Worker command-line entry point."""

from __future__ import annotations

import argparse
import json
import signal
import threading
from collections.abc import Sequence
from dataclasses import asdict

from interstellar_worker.config import WorkerSettings
from interstellar_worker.health import check_heartbeat
from interstellar_worker.runner import WorkerRunner


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Interstellar M0 worker process")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--once", action="store_true", help="write one heartbeat and exit")
    mode.add_argument("--check", action="store_true", help="check heartbeat freshness and exit")
    return parser


def run_cli(argv: Sequence[str] | None = None, settings: WorkerSettings | None = None) -> int:
    arguments = _parser().parse_args(argv)
    resolved = settings or WorkerSettings.from_env()
    if arguments.check:
        result = check_heartbeat(
            resolved.heartbeat_path,
            max_age_seconds=resolved.heartbeat_max_age_seconds,
        )
        print(json.dumps(asdict(result), sort_keys=True))
        return 0 if result.healthy else 1

    runner = WorkerRunner(resolved)
    if arguments.once:
        print(json.dumps(asdict(runner.tick()), sort_keys=True))
        return 0

    stop_event = threading.Event()

    def stop(_signum: int, _frame: object) -> None:
        stop_event.set()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    runner.run(stop_event)
    return 0


def main() -> None:
    raise SystemExit(run_cli())


if __name__ == "__main__":
    main()
