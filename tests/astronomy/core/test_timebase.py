from __future__ import annotations

from datetime import UTC, datetime, timedelta, timezone
from math import nan

import pytest

from interstellar_core.astronomy.timebase import (
    DeltaTInput,
    DeltaTQuality,
    TimeScaleStatus,
    derive_time_scales,
    julian_day_from_utc,
)


def test_j2000_epoch_is_exact_gold_value() -> None:
    assert julian_day_from_utc(datetime(2000, 1, 1, 12, tzinfo=UTC)) == 2_451_545.0


def test_gregorian_leap_day_gold_value() -> None:
    assert julian_day_from_utc(datetime(2000, 2, 29, 0, tzinfo=UTC)) == 2_451_603.5


def test_julian_day_advances_one_for_each_utc_calendar_day() -> None:
    samples = (
        datetime(1900, 2, 28, 3, 4, 5, tzinfo=UTC),
        datetime(2000, 2, 28, 3, 4, 5, tzinfo=UTC),
        datetime(2024, 2, 29, 23, 59, 59, tzinfo=UTC),
    )
    for sample in samples:
        assert julian_day_from_utc(sample + timedelta(days=1)) - julian_day_from_utc(
            sample
        ) == pytest.approx(1.0, abs=1e-10)


def test_julian_day_rejects_naive_or_nonzero_offset_inputs() -> None:
    with pytest.raises(ValueError, match="timezone-aware"):
        julian_day_from_utc(datetime(2000, 1, 1, 12))
    with pytest.raises(ValueError, match="zero UTC offset"):
        julian_day_from_utc(
            datetime(2000, 1, 1, 20, tzinfo=timezone(timedelta(hours=8)))
        )


def test_tt_from_ut1_keeps_delta_t_value_and_provenance_visible() -> None:
    delta_t = DeltaTInput(
        seconds=69.184,
        source="iers_bulletin",
        quality=DeltaTQuality.OBSERVED,
        model="bulletin_b",
        version="test-fixture",
        uncertainty_seconds=0.001,
    )
    result = derive_time_scales(2_460_000.5, delta_t)

    assert result.status is TimeScaleStatus.RESOLVED
    assert result.jd_tt == pytest.approx(2_460_000.5 + 69.184 / 86_400.0)
    assert result.delta_t is delta_t
    assert result.delta_t.source == "iers_bulletin"
    assert result.delta_t.quality is DeltaTQuality.OBSERVED
    assert result.delta_t.uncertainty_seconds == 0.001


def test_missing_delta_t_never_fabricates_tt() -> None:
    delta_t = DeltaTInput(
        seconds=None,
        source="not_supplied",
        quality=DeltaTQuality.UNKNOWN,
    )
    result = derive_time_scales(2_460_000.5, delta_t)

    assert result.status is TimeScaleStatus.UNRESOLVED_DELTA_T
    assert result.jd_ut1 == 2_460_000.5
    assert result.jd_tt is None


def test_delta_t_input_rejects_hidden_or_incoherent_provenance() -> None:
    with pytest.raises(ValueError, match="source"):
        DeltaTInput(seconds=69.0, source="", quality=DeltaTQuality.ESTIMATED)
    with pytest.raises(ValueError, match="quality=unknown"):
        DeltaTInput(seconds=None, source="missing", quality=DeltaTQuality.ESTIMATED)
    with pytest.raises(ValueError, match="cannot use quality=unknown"):
        DeltaTInput(seconds=69.0, source="fixture", quality=DeltaTQuality.UNKNOWN)
    with pytest.raises(ValueError, match="finite"):
        DeltaTInput(seconds=nan, source="fixture", quality=DeltaTQuality.ESTIMATED)
