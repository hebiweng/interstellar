"""Independent-reference validation contracts for astronomical calculations."""

from .compare import compare_positions, evaluate_stable_gate
from .models import (
    ActualPositionSet,
    BodyDifference,
    CoordinateSpec,
    DifferenceReport,
    EpochSpec,
    GateStatus,
    MaturityGate,
    PositionValue,
    ReferenceFixture,
    ReferenceSource,
    SpiceKernelAvailability,
    ToleranceProfile,
    UnitSpec,
)
from .reader import load_reference_fixture

__all__ = [
    "ActualPositionSet",
    "BodyDifference",
    "CoordinateSpec",
    "DifferenceReport",
    "EpochSpec",
    "GateStatus",
    "MaturityGate",
    "PositionValue",
    "ReferenceFixture",
    "ReferenceSource",
    "SpiceKernelAvailability",
    "ToleranceProfile",
    "UnitSpec",
    "compare_positions",
    "evaluate_stable_gate",
    "load_reference_fixture",
]
