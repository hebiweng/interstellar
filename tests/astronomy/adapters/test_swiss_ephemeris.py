from __future__ import annotations

import math
from datetime import UTC, datetime, timedelta, timezone
from importlib.metadata import version

import pytest
import swisseph as swe

from interstellar_core.astronomy.adapters import (
    EphemerisFallbackError,
    EphemerisInputError,
    SwissEphemerisAdapter,
    SwissEphemerisError,
    SwissEphemerisMode,
)
from interstellar_core.astronomy.adapters.swiss_ephemeris import (
    EphemerisCalculationError,
    EphemerisFlagsError,
)

EXPECTED_POINT_IDS = (
    "sun",
    "moon",
    "mercury",
    "venus",
    "mars",
    "jupiter",
    "saturn",
    "uranus",
    "neptune",
    "pluto",
)


class FakeBackend:
    version = "test-c-library"
    __version__ = "test-binding"

    def __init__(
        self,
        *,
        actual_mode_flag: int = swe.FLG_MOSEPH,
        include_required_flags: bool = True,
        fail: bool = False,
    ) -> None:
        self.actual_mode_flag = actual_mode_flag
        self.include_required_flags = include_required_flags
        self.fail = fail
        self.path: str | None = None

    def set_ephe_path(self, path: str) -> None:
        self.path = path

    def get_library_path(self) -> str:
        return "/test/swisseph.so"

    def julday(
        self, year: int, month: int, day: int, hour: float, calendar: int
    ) -> float:
        assert (year, month, day, calendar) == (2000, 1, 1, swe.GREG_CAL)
        assert hour == 12
        return 2451545.0

    def calc_ut(self, _jd: float, body: int, flags: int):  # type: ignore[no-untyped-def]
        if self.fail:
            raise RuntimeError("calculation failed")
        returned_flags = self.actual_mode_flag
        if self.include_required_flags:
            returned_flags |= flags & (swe.FLG_SPEED | swe.FLG_EQUATORIAL)
        distance = 1.0 + body / 100
        if flags & swe.FLG_EQUATORIAL:
            values = (100.0 + body, 10.0, distance, 0.5, 0.25, 0.001)
        else:
            values = (30.0 + body, 1.0, distance, -0.00005, 0.01, 0.001)
        return values, returned_flags, "using test fallback"

    def deltat_ex(self, _jd: float, flag: int):  # type: ignore[no-untyped-def]
        assert flag == self.actual_mode_flag
        return 0.00075, "test delta-t model"


def test_moshier_j2000_positions_are_deterministic_and_complete() -> None:
    result = SwissEphemerisAdapter(mode=SwissEphemerisMode.MOSHIER).calculate(
        julian_day_ut=2451545.0
    )

    assert tuple(point["point_id"] for point in result.points) == EXPECTED_POINT_IDS
    sun = result.points[0]
    assert sun["position"]["ecliptic"]["longitude_deg"] == pytest.approx(
        280.36891967534325,
        abs=1e-10,
    )
    assert sun["position"]["ecliptic"]["latitude_deg"] == pytest.approx(
        0.00023232651435007193,
        abs=1e-12,
    )
    assert sun["position"]["distance_au"] == pytest.approx(
        0.9833276448202024, abs=1e-12
    )
    assert sun["position"]["velocity"]["longitude_deg_per_day"] == pytest.approx(
        1.0194320944202486,
        abs=1e-12,
    )
    assert result.points[6]["point_id"] == "saturn"
    assert result.points[6]["position"]["motion_state"] == "retrograde"
    assert result.points[6]["retrograde"] is True


def test_utc_input_matches_julian_day_and_exposes_delta_t() -> None:
    adapter = SwissEphemerisAdapter(mode=SwissEphemerisMode.MOSHIER)
    from_utc = adapter.calculate(utc_instant=datetime(2000, 1, 1, 12, tzinfo=UTC))
    from_jd = adapter.calculate(julian_day_ut=2451545.0)

    assert from_utc.julian_day_ut == 2451545.0
    assert from_utc.utc_instant == "2000-01-01T12:00:00Z"
    assert from_utc.points == from_jd.points
    assert from_utc.delta_t_seconds == pytest.approx(
        swe.deltat_ex(2451545.0, swe.FLG_MOSEPH)[0] * 86400
    )
    assert from_utc.julian_day_tt == pytest.approx(
        from_utc.julian_day_ut + from_utc.delta_t_seconds / 86400
    )
    assert from_utc.provenance.delta_t_function == "swe_deltat_ex"
    assert from_utc.provenance.delta_t_model == "automatic_ephemeris_dependent"
    assert from_utc.provenance.delta_t_ephemeris_mode == "moshier"


def test_points_match_canonical_point_shape_without_houses_or_aspects() -> None:
    result = SwissEphemerisAdapter(mode=SwissEphemerisMode.MOSHIER).calculate(
        julian_day_ut=2451545.0
    )

    for point in result.points:
        assert set(point) == {
            "point_id",
            "kind",
            "position",
            "sign",
            "degree_in_sign",
            "house",
            "distance_to_next_cusp_deg",
            "retrograde",
            "out_of_bounds",
            "solar_relation",
            "status_refs",
        }
        assert point["house"] is None
        assert 0 <= point["position"]["ecliptic"]["longitude_deg"] < 360
        assert -90 <= point["position"]["ecliptic"]["latitude_deg"] <= 90
        assert point["position"]["distance_au"] >= 0
        assert point["position"]["center"] == "geocentric"
        assert point["position"]["frame"] == "true_ecliptic_of_date"
        assert set(point["position"]["velocity"]) == {
            "longitude_deg_per_day",
            "latitude_deg_per_day",
            "right_ascension_deg_per_day",
            "declination_deg_per_day",
            "distance_au_per_day",
        }
    serialized = result.to_dict()
    assert "aspects" not in serialized
    assert "house_set" not in serialized


def test_versions_modes_and_return_flags_are_preserved() -> None:
    result = SwissEphemerisAdapter(mode=SwissEphemerisMode.MOSHIER).calculate(
        julian_day_ut=2451545.0
    )
    provenance = result.provenance

    assert provenance.maturity == "experimental"
    assert provenance.swiss_c_library_version == swe.version
    assert provenance.binding_version == version("pysweph")
    assert provenance.binding_library_path == swe.get_library_path()
    assert provenance.requested_mode == "moshier"
    assert provenance.actual_modes == ("moshier",)
    assert len(provenance.point_flags) == 10
    for record in provenance.point_flags:
        assert record.returned_ecliptic_flags & swe.FLG_MOSEPH
        assert record.returned_ecliptic_flags & swe.FLG_SPEED
        assert record.returned_equatorial_flags & swe.FLG_EQUATORIAL
        assert record.actual_mode == "moshier"


def test_swiss_to_moshier_fallback_is_visible_or_blocked() -> None:
    recording = SwissEphemerisAdapter(
        mode=SwissEphemerisMode.SWISS,
        moshier_fallback="record",
        _backend=FakeBackend(),  # type: ignore[arg-type]
    ).calculate(julian_day_ut=2451545.0)

    assert recording.provenance.requested_mode == "swiss"
    assert recording.provenance.actual_modes == ("moshier",)
    assert any(
        warning.code == "EPHEMERIS_FALLBACK_MOSHIER" for warning in recording.warnings
    )
    assert any(
        warning.code == "SWISS_EPHEMERIS_MESSAGE" for warning in recording.warnings
    )
    assert any(warning.code == "DELTA_T_MESSAGE" for warning in recording.warnings)

    with pytest.raises(EphemerisFallbackError, match="Moshier"):
        SwissEphemerisAdapter(
            mode=SwissEphemerisMode.SWISS,
            moshier_fallback="error",
            _backend=FakeBackend(),  # type: ignore[arg-type]
        ).calculate(julian_day_ut=2451545.0)


def test_stationary_classification_uses_explicit_threshold() -> None:
    result = SwissEphemerisAdapter(
        mode=SwissEphemerisMode.MOSHIER,
        stationary_threshold_deg_per_day=0.0001,
        _backend=FakeBackend(),  # type: ignore[arg-type]
    ).calculate(julian_day_ut=2451545.0)

    assert all(
        point["position"]["motion_state"] == "stationary" for point in result.points
    )
    assert all(point["retrograde"] is True for point in result.points)


@pytest.mark.parametrize(
    ("instant", "jd"),
    [
        (None, None),
        (datetime(2000, 1, 1, 12, tzinfo=UTC), 2451545.0),
        (datetime(2000, 1, 1, 12), None),
        (datetime(2000, 1, 1, 13, tzinfo=timezone(timedelta(hours=1))), None),
        (None, math.nan),
    ],
)
def test_invalid_time_inputs_are_rejected(
    instant: datetime | None,
    jd: float | None,
) -> None:
    with pytest.raises(EphemerisInputError):
        SwissEphemerisAdapter().calculate(utc_instant=instant, julian_day_ut=jd)


def test_missing_required_return_flags_are_rejected() -> None:
    adapter = SwissEphemerisAdapter(
        mode=SwissEphemerisMode.MOSHIER,
        _backend=FakeBackend(include_required_flags=False),  # type: ignore[arg-type]
    )

    with pytest.raises(EphemerisFlagsError, match="required flags"):
        adapter.calculate(julian_day_ut=2451545.0)


def test_binding_errors_are_wrapped_without_fallback() -> None:
    adapter = SwissEphemerisAdapter(
        mode=SwissEphemerisMode.MOSHIER,
        _backend=FakeBackend(fail=True),  # type: ignore[arg-type]
    )

    with pytest.raises(EphemerisCalculationError, match="sun") as captured:
        adapter.calculate(julian_day_ut=2451545.0)
    assert isinstance(captured.value, SwissEphemerisError)
