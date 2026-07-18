"""Typed failures raised while resolving immutable analysis recipes."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any


class RecipeResolutionError(ValueError):
    """Base error with a stable machine-readable code and JSON pointer."""

    code = "RECIPE_RESOLUTION_ERROR"

    def __init__(
        self,
        message: str,
        *,
        path: str | None = None,
        details: Mapping[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.path = path
        self.details = dict(details or {})


class InvalidDraftError(RecipeResolutionError):
    code = "INVALID_ANALYSIS_DRAFT"


class UnknownRegistryItemError(RecipeResolutionError):
    code = "UNKNOWN_REGISTRY_ITEM"


class LockedNodeOverrideError(RecipeResolutionError):
    code = "LOCKED_NODE_OVERRIDE"


class DependencyCycleError(RecipeResolutionError):
    code = "CALCULATION_DEPENDENCY_CYCLE"


class ResourceBudgetExceeded(RecipeResolutionError):
    code = "RESOURCE_BUDGET_EXCEEDED"


class RecipeConfirmationError(RecipeResolutionError):
    code = "RECIPE_CONFIRMATION_ERROR"


class RecipeExpiredError(RecipeConfirmationError):
    code = "RECIPE_EXPIRED"
