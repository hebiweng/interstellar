from __future__ import annotations

import asyncio

from interstellar_api.readiness import ProbeResult, ReadinessRegistry


def test_readiness_registry_isolates_probe_failures() -> None:
    registry = ReadinessRegistry()
    registry.register("ok", lambda: ProbeResult(ready=True, detail="ok"))

    def broken() -> ProbeResult:
        raise RuntimeError("secret detail must not leak")

    registry.register("broken", broken)
    results = asyncio.run(registry.check())

    assert results["ok"].ready is True
    assert results["broken"] == ProbeResult(
        ready=False, detail="probe failed: RuntimeError"
    )
