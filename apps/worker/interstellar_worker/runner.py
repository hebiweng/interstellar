"""Interruptible M0 worker loop.

No job broker or astrology calculation is executed here. Later milestones replace the idle
tick with leased job dispatch while retaining the same shutdown and heartbeat boundaries.
"""

from __future__ import annotations

import threading

from interstellar_worker.config import WorkerSettings
from interstellar_worker.health import Heartbeat, write_heartbeat


class WorkerRunner:
    def __init__(self, settings: WorkerSettings) -> None:
        self.settings = settings
        self._sequence = 0

    def tick(self) -> Heartbeat:
        self._sequence += 1
        return write_heartbeat(
            self.settings.heartbeat_path,
            service=self.settings.service_name,
            version=self.settings.service_version,
            sequence=self._sequence,
        )

    def run(self, stop_event: threading.Event) -> None:
        while not stop_event.is_set():
            self.tick()
            stop_event.wait(self.settings.heartbeat_interval_seconds)
