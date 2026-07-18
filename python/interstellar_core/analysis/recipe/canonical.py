"""Canonical JSON helpers for deterministic recipe identities.

The resolver only accepts JSON-compatible values.  Sorting object keys,
removing insignificant whitespace and rejecting non-finite numbers gives the
JCS properties needed by recipe documents.  The emitted form is UTF-8 and
keeps Unicode characters unescaped, as required by RFC 8785.
"""

from __future__ import annotations

import hashlib
import json
import math
from collections.abc import Mapping, Sequence
from decimal import Decimal
from typing import Any


def _string(value: str, *, path: str) -> str:
    if any(0xD800 <= ord(character) <= 0xDFFF for character in value):
        raise ValueError(f"unpaired surrogate at {path}")
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def _number(value: int | float, *, path: str) -> str:
    if isinstance(value, int):
        return str(value)
    if not math.isfinite(value):
        raise ValueError(f"non-finite number at {path}")
    if value == 0:
        return "0"
    decimal = Decimal(repr(value))
    adjusted = decimal.adjusted()
    if -6 <= adjusted < 21:
        rendered = format(decimal, "f")
        if "." in rendered:
            rendered = rendered.rstrip("0").rstrip(".")
        return rendered
    mantissa, exponent = format(decimal.normalize(), "e").split("e")
    mantissa = mantissa.rstrip("0").rstrip(".")
    exponent_number = int(exponent)
    exponent_sign = "+" if exponent_number >= 0 else ""
    return f"{mantissa}e{exponent_sign}{exponent_number}"


def _serialize(value: Any, *, path: str = "$") -> str:
    if value is None:
        return "null"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, (int, float)):
        return _number(value, path=path)
    if isinstance(value, str):
        return _string(value, path=path)
    if isinstance(value, Mapping):
        pairs: list[str] = []
        keys = list(value)
        for key in keys:
            if not isinstance(key, str):
                raise TypeError(f"non-string object key at {path}")
        for key in sorted(keys, key=lambda item: item.encode("utf-16-be")):
            pairs.append(
                f"{_string(key, path=path)}:{_serialize(value[key], path=f'{path}.{key}')}"
            )
        return "{" + ",".join(pairs) + "}"
    if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
        return (
            "["
            + ",".join(
                _serialize(item, path=f"{path}[{index}]") for index, item in enumerate(value)
            )
            + "]"
        )
    raise TypeError(f"non-JSON value {type(value).__name__} at {path}")


def canonical_json(value: Any) -> bytes:
    """Encode a JSON-compatible value into the resolver's canonical form."""

    return _serialize(value).encode("utf-8")


def content_hash(value: Any) -> str:
    """Return the canonical SHA-256 identifier used by repository schemas."""

    return f"sha256:{hashlib.sha256(canonical_json(value)).hexdigest()}"
