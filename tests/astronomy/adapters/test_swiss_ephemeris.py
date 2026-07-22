from __future__ import annotations

import math
from datetime import UTC, datetime, timedelta, timezone
from importlib.metadata import version

import pytest
import swisseph as swe

from interstellar_core.astronomy.adapters import (
    AYANAMSA_MODES,
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


def test_published_ayanamsa_catalog_includes_supported_consumer_choices() -> None:
    assert AYANAMSA_MODES["ushashashi"] == swe.SIDM_USHASHASHI
    assert AYANAMSA_MODES["djwhal_khul"] == swe.SIDM_DJWHAL_KHUL
    assert AYANAMSA_MODES["jn_bhasin"] == swe.SIDM_JN_BHASIN
    assert AYANAMSA_MODES["true_pushya"] == swe.SIDM_TRUE_PUSHYA


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


def test_sidereal_lahiri_changes_only_zodiacal_longitude_and_is_traced() -> None:
    adapter = SwissEphemerisAdapter(mode=SwissEphemerisMode.MOSHIER)
    tropical = adapter.calculate(julian_day_ut=2451545.0)
    sidereal = adapter.calculate(
        julian_day_ut=2451545.0,
        zodiac="sidereal",
        ayanamsa="lahiri",
    )

    tropical_sun = tropical.points[0]
    sidereal_sun = sidereal.points[0]
    ayanamsa = sidereal.provenance.ayanamsa_value_deg
    assert ayanamsa is not None
    assert sidereal.provenance.zodiac == "sidereal"
    assert sidereal.provenance.ayanamsa == "lahiri"
    assert sidereal_sun["position"]["ecliptic"]["longitude_deg"] == pytest.approx(
        (tropical_sun["position"]["ecliptic"]["longitude_deg"] - ayanamsa) % 360,
        abs=1e-9,
    )
    assert sidereal_sun["position"]["equatorial"] == tropical_sun["position"][
        "equatorial"
    ]
    assert sidereal.provenance.point_flags[0].requested_ecliptic_flags & swe.FLG_SIDEREAL
    assert not (
        sidereal.provenance.point_flags[0].requested_equatorial_flags & swe.FLG_SIDEREAL
    )


@pytest.mark.parametrize(
    ("zodiac", "ayanamsa"),
    [("tropical", "lahiri"), ("sidereal", None), ("sidereal", "invented")],
)
def test_zodiac_and_ayanamsa_must_be_an_explicit_supported_pair(
    zodiac: str,
    ayanamsa: str | None,
) -> None:
    with pytest.raises(EphemerisInputError):
        SwissEphemerisAdapter(mode=SwissEphemerisMode.MOSHIER).calculate(
            julian_day_ut=2451545.0,
            zodiac=zodiac,  # type: ignore[arg-type]
            ayanamsa=ayanamsa,
        )


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
            "distance_from_previous_cusp_deg",
            "distance_to_next_cusp_deg",
            "house_position_fraction",
            "retrograde",
            "motion_interpretation",
            "out_of_bounds",
            "solar_relation",
            "solar_elongation_deg",
            "visibility_state",
            "oriental_occidental",
            "formula_ref",
            "catalog_object_ref",
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


def test_topocentric_center_uses_observer_and_does_not_leak_into_geocentric_calls() -> None:
    adapter = SwissEphemerisAdapter(mode=SwissEphemerisMode.MOSHIER)
    geocentric_before = adapter.calculate(julian_day_ut=2451545.0)
    topocentric = adapter.calculate(
        julian_day_ut=2451545.0,
        center="topocentric",
        observer={"longitude": 121.4737, "latitude": 31.2304, "elevation_m": 4},
    )
    geocentric_after = adapter.calculate(julian_day_ut=2451545.0)

    assert topocentric.provenance.center == "topocentric"
    assert all(
        point["position"]["center"] == "topocentric" for point in topocentric.points
    )
    assert all(
        record.returned_ecliptic_flags & swe.FLG_TOPOCTR
        for record in topocentric.provenance.point_flags
    )
    assert geocentric_before.points == geocentric_after.points
    assert geocentric_after.provenance.center == "geocentric"


def test_topocentric_center_requires_valid_observer() -> None:
    adapter = SwissEphemerisAdapter(mode=SwissEphemerisMode.MOSHIER)
    with pytest.raises(EphemerisInputError, match="requires an observer"):
        adapter.calculate(julian_day_ut=2451545.0, center="topocentric")
    with pytest.raises(EphemerisInputError, match="out of range"):
        adapter.calculate(
            julian_day_ut=2451545.0,
            center="topocentric",
            observer={"longitude": 181, "latitude": 0},
        )


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
    assert all(point["retrograde"] is False for point in result.points)


def test_declared_extended_projection_is_ordered_and_traced() -> None:
    requested = (
        "sun",
        "true_north_node",
        "mean_north_node",
        "mean_lilith",
        "true_lilith",
        "lunar_perigee",
        "chiron",
        "ceres",
        "pallas",
        "juno",
        "vesta",
    )
    result = SwissEphemerisAdapter(
        mode=SwissEphemerisMode.MOSHIER,
        _backend=FakeBackend(),  # type: ignore[arg-type]
    ).calculate(julian_day_ut=2451545.0, point_ids=requested)

    assert tuple(point["point_id"] for point in result.points) == requested
    assert (
        tuple(record.point_id for record in result.provenance.point_flags) == requested
    )
    assert result.points[1]["kind"] == "node"
    assert result.points[3]["kind"] == "lunar_point"
    assert result.points[6]["kind"] == "centaur"
    assert result.points[7]["catalog_object_ref"] == "mpc:1"


def test_hamburg_tnps_match_swiss_reference_and_remain_hypothetical() -> None:
    from pathlib import Path

    from interstellar_core.astronomy.adapters import HAMBURG_TNP_POINT_IDS

    ephemeris_path = (
        Path(__file__).resolve().parents[3] / "vendor" / "swisseph" / "ephe"
    )
    result = SwissEphemerisAdapter(ephemeris_path=ephemeris_path).calculate(
        utc_instant=datetime(2000, 3, 1, 8, 30, tzinfo=UTC),
        point_ids=HAMBURG_TNP_POINT_IDS,
    )
    expected = {
        "cupido": 244.690811,
        "hades": 77.648938,
        "zeus": 184.965415,
        # Official seorbel.txt (sha256 97b454ff...) overrides the Swiss
        # built-in fallback elements and is the repository's locked source.
        "kronos": 87.258494,
        "apollon": 201.147435,
        "admetos": 49.086908,
        "vulkanus": 109.825050,
        "poseidon": 214.574483,
    }
    assert tuple(point["point_id"] for point in result.points) == HAMBURG_TNP_POINT_IDS
    for point in result.points:
        assert point["kind"] == "hypothetical"
        assert point["formula_ref"] == "ephemeris.swiss.hypothetical_orbit.v1"
        assert point["catalog_object_ref"].startswith("swiss:h")
        assert point["position"]["ecliptic"]["longitude_deg"] == pytest.approx(
            expected[point["point_id"]], abs=1e-6
        )


def test_common_minor_body_preset_uses_locked_swiss_files_without_fallback() -> None:
    from pathlib import Path

    from interstellar_core.astronomy.adapters import COMMON_MINOR_BODY_POINT_IDS

    ephemeris_path = (
        Path(__file__).resolve().parents[3] / "vendor" / "swisseph" / "ephe"
    )
    result = SwissEphemerisAdapter(
        ephemeris_path=ephemeris_path,
        moshier_fallback="error",
    ).calculate(
        utc_instant=datetime(2000, 3, 1, 8, 30, tzinfo=UTC),
        point_ids=COMMON_MINOR_BODY_POINT_IDS,
    )

    assert len(result.points) == 20
    assert tuple(point["point_id"] for point in result.points) == (
        "chiron",
        "ceres",
        "pallas",
        "juno",
        "vesta",
        "pholus",
        "nessus",
        "chariklo",
        "asteroid_eros",
        "psyche",
        "eris",
        "sedna",
        "haumea",
        "makemake",
        "quaoar",
        "orcus",
        "ixion",
        "varuna",
        "astraea",
        "hygiea",
    )
    assert result.provenance.actual_modes == ("swiss",)
    assert not any(
        warning.code == "EPHEMERIS_FALLBACK_MOSHIER" for warning in result.warnings
    )
    expected_longitudes = {
        "nessus": 276.891057,
        "chariklo": 148.183140,
        "asteroid_eros": 275.772019,
        "psyche": 356.730400,
        "eris": 18.848430,
        "sedna": 45.383580,
        "quaoar": 248.688181,
        "hygiea": 245.982723,
    }
    for point in result.points:
        assert point["catalog_object_ref"].startswith("mpc:")
        assert point["kind"] in {"asteroid", "centaur", "dwarf_planet"}
        if point["point_id"] in expected_longitudes:
            assert point["position"]["ecliptic"]["longitude_deg"] == pytest.approx(
                expected_longitudes[point["point_id"]], abs=1e-6
            )


@pytest.mark.parametrize(
    "point_ids",
    [(), ("sun", "sun"), ("sun", "invented_point")],
)
def test_declared_point_projection_rejects_empty_duplicate_or_unknown_ids(
    point_ids: tuple[str, ...],
) -> None:
    with pytest.raises(EphemerisInputError):
        SwissEphemerisAdapter(
            mode=SwissEphemerisMode.MOSHIER,
            _backend=FakeBackend(),  # type: ignore[arg-type]
        ).calculate(julian_day_ut=2451545.0, point_ids=point_ids)


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
