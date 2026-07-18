"""Composable readiness checks for infrastructure introduced after M0."""

from __future__ import annotations

import inspect
from collections.abc import Awaitable, Callable
from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class ProbeResult:
    ready: bool
    detail: str


Probe = Callable[[], ProbeResult | Awaitable[ProbeResult]]


class ReadinessRegistry:
    def __init__(self) -> None:
        self._probes: dict[str, Probe] = {}

    def register(self, name: str, probe: Probe) -> None:
        if not name or name in self._probes:
            raise ValueError(f"readiness probe name is empty or already registered: {name!r}")
        self._probes[name] = probe

    async def check(self) -> dict[str, ProbeResult]:
        results: dict[str, ProbeResult] = {}
        for name, probe in self._probes.items():
            try:
                result = probe()
                if inspect.isawaitable(result):
                    result = await result
                if not isinstance(result, ProbeResult):
                    raise TypeError("probe must return ProbeResult")
                results[name] = result
            except Exception as exc:  # probes must degrade readiness, not crash the endpoint
                results[name] = ProbeResult(
                    ready=False,
                    detail=f"probe failed: {type(exc).__name__}",
                )
        return results
