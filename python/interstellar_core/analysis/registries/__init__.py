"""Strict, immutable analysis registry public API."""

from .loader import (
    DEFAULT_ANALYSIS_CATALOG,
    DEFAULT_CAPABILITIES_CATALOG,
    INTENT_SOURCE_POINTER,
    RegistryValidationError,
    load_analysis_registry,
)
from .models import (
    AnalysisIntent,
    AnalysisRegistry,
    BaseAnalysisModel,
    EntryPoint,
    RegistrySource,
    TopicModel,
)

__all__ = [
    "DEFAULT_ANALYSIS_CATALOG",
    "DEFAULT_CAPABILITIES_CATALOG",
    "INTENT_SOURCE_POINTER",
    "AnalysisIntent",
    "AnalysisRegistry",
    "BaseAnalysisModel",
    "EntryPoint",
    "RegistrySource",
    "RegistryValidationError",
    "TopicModel",
    "load_analysis_registry",
]
