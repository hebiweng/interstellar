from __future__ import annotations

from interstellar_core.domain import DomainError


def test_domain_error_has_transport_neutral_machine_code() -> None:
    error = DomainError(
        "MODEL_NOT_AVAILABLE", "No calculation implementation exists in M0"
    )

    assert error.code == "MODEL_NOT_AVAILABLE"
    assert error.detail.endswith("M0")
    assert str(error) == error.detail
