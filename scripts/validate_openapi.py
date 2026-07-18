#!/usr/bin/env python3
"""Validate Interstellar OpenAPI and Canonical JSON Schema contracts.

The validator deliberately keeps JSON Schema validation useful without the optional
``jsonschema`` package.  It always performs dialect, keyword-shape, regex, bounds,
identifier and local-reference checks.  When ``jsonschema`` is available it also
runs Draft202012Validator.check_schema for complete meta-schema validation.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import unquote, urlsplit

try:
    import yaml
except ImportError as exc:  # pragma: no cover - exercised only in incomplete envs
    raise SystemExit(
        "PyYAML is required to parse openapi/openapi.yaml. Install the repository "
        "development dependency `PyYAML==6.0.3`."
    ) from exc


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OPENAPI = REPO_ROOT / "openapi" / "openapi.yaml"
DEFAULT_SCHEMA_DIR = REPO_ROOT / "packages" / "canonical-schema"
JSON_SCHEMA_DIALECT = "https://json-schema.org/draft/2020-12/schema"
HTTP_METHODS = frozenset(
    {"get", "put", "post", "delete", "options", "head", "patch", "trace"}
)
VALID_JSON_SCHEMA_TYPES = frozenset(
    {"null", "boolean", "object", "array", "number", "string", "integer"}
)


class ContractValidationError(ValueError):
    """Raised when one or more contract invariants fail."""

    def __init__(self, errors: Iterable[str]):
        self.errors = tuple(errors)
        super().__init__("\n".join(self.errors))


@dataclass(frozen=True)
class ValidationReport:
    schema_files: int
    schema_refs: int
    openapi_paths: int
    openapi_operations: int
    openapi_refs: int
    full_meta_validation: bool


def load_yaml(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as stream:
        return yaml.safe_load(stream)


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as stream:
        return json.load(stream)


def iter_refs(node: Any, pointer: str = "#") -> Iterable[tuple[str, str]]:
    if isinstance(node, dict):
        for key, value in node.items():
            child_pointer = f"{pointer}/{_escape_pointer_token(str(key))}"
            if key == "$ref" and isinstance(value, str):
                yield child_pointer, value
            yield from iter_refs(value, child_pointer)
    elif isinstance(node, list):
        for index, value in enumerate(node):
            yield from iter_refs(value, f"{pointer}/{index}")


def _escape_pointer_token(token: str) -> str:
    return token.replace("~", "~0").replace("/", "~1")


def _decode_pointer_token(token: str) -> str:
    return unquote(token).replace("~1", "/").replace("~0", "~")


def resolve_json_pointer(document: Any, fragment: str) -> Any:
    if fragment in ("", "#"):
        return document
    pointer = fragment[1:] if fragment.startswith("#") else fragment
    if not pointer.startswith("/"):
        raise KeyError(f"unsupported fragment {fragment!r}; expected a JSON Pointer")

    current = document
    for raw_token in pointer[1:].split("/"):
        token = _decode_pointer_token(raw_token)
        if isinstance(current, dict):
            current = current[token]
        elif isinstance(current, list):
            current = current[int(token)]
        else:
            raise KeyError(f"cannot descend through {type(current).__name__}")
    return current


def _safe_local_path(source: Path, target: str, repo_root: Path) -> Path:
    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc:
        raise KeyError(f"remote references are not allowed: {target}")
    resolved = (source.parent / unquote(parsed.path)).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise KeyError(f"reference escapes repository root: {target}") from exc
    return resolved


def resolve_ref(
    source: Path,
    source_document: Any,
    ref: str,
    repo_root: Path = REPO_ROOT,
) -> Any:
    parsed = urlsplit(ref)
    if not parsed.path:
        target_path = source
        target_document = source_document
    else:
        target_path = _safe_local_path(source, ref, repo_root)
        if not target_path.is_file():
            raise KeyError(f"referenced file does not exist: {target_path}")
        if target_path.suffix == ".json":
            target_document = load_json(target_path)
        elif target_path.suffix in {".yaml", ".yml"}:
            target_document = load_yaml(target_path)
        else:
            raise KeyError(f"unsupported referenced file type: {target_path.suffix}")
    return resolve_json_pointer(target_document, f"#{parsed.fragment}" if parsed.fragment else "#")


def _schema_nodes(node: Any, pointer: str = "#") -> Iterable[tuple[str, dict[str, Any]]]:
    if not isinstance(node, dict):
        return
    yield pointer, node

    mapping_keywords = (
        "$defs",
        "definitions",
        "properties",
        "patternProperties",
        "dependentSchemas",
    )
    for keyword in mapping_keywords:
        children = node.get(keyword)
        if isinstance(children, dict):
            for name, child in children.items():
                if isinstance(child, dict):
                    child_pointer = (
                        f"{pointer}/{_escape_pointer_token(keyword)}/"
                        f"{_escape_pointer_token(str(name))}"
                    )
                    yield from _schema_nodes(child, child_pointer)

    array_keywords = ("allOf", "anyOf", "oneOf", "prefixItems")
    for keyword in array_keywords:
        children = node.get(keyword)
        if isinstance(children, list):
            for index, child in enumerate(children):
                if isinstance(child, dict):
                    yield from _schema_nodes(child, f"{pointer}/{keyword}/{index}")

    schema_keywords = (
        "not",
        "if",
        "then",
        "else",
        "contains",
        "propertyNames",
        "additionalProperties",
        "unevaluatedProperties",
        "items",
        "unevaluatedItems",
        "contentSchema",
    )
    for keyword in schema_keywords:
        child = node.get(keyword)
        if isinstance(child, dict):
            yield from _schema_nodes(child, f"{pointer}/{keyword}")


def validate_schema_document(document: Any, label: str) -> list[str]:
    """Perform deterministic Draft 2020-12 structural meta-validation."""
    errors: list[str] = []
    if not isinstance(document, dict):
        return [f"{label}: root must be an object"]
    if document.get("$schema") != JSON_SCHEMA_DIALECT:
        errors.append(f"{label}: $schema must be {JSON_SCHEMA_DIALECT}")
    if not isinstance(document.get("$id"), str) or not document["$id"].startswith("https://"):
        errors.append(f"{label}: $id must be a stable HTTPS URI")

    for pointer, schema in _schema_nodes(document):
        type_value = schema.get("type")
        if type_value is not None:
            types = type_value if isinstance(type_value, list) else [type_value]
            if not types or any(
                not isinstance(item, str) or item not in VALID_JSON_SCHEMA_TYPES
                for item in types
            ):
                errors.append(f"{label}{pointer[1:]}/type: invalid JSON Schema type {type_value!r}")
            if len(types) != len(set(types)):
                errors.append(f"{label}{pointer[1:]}/type: duplicate type values")

        for keyword in ("properties", "patternProperties", "$defs", "dependentSchemas"):
            value = schema.get(keyword)
            if value is not None and not isinstance(value, dict):
                errors.append(f"{label}{pointer[1:]}/{keyword}: must be an object")
        for keyword in ("allOf", "anyOf", "oneOf", "prefixItems"):
            value = schema.get(keyword)
            if value is not None and (
                not isinstance(value, list) or not value or not all(isinstance(item, dict) for item in value)
            ):
                errors.append(f"{label}{pointer[1:]}/{keyword}: must be a non-empty schema array")

        required = schema.get("required")
        if required is not None:
            if not isinstance(required, list) or not all(isinstance(item, str) for item in required):
                errors.append(f"{label}{pointer[1:]}/required: must be a string array")
            elif len(required) != len(set(required)):
                errors.append(f"{label}{pointer[1:]}/required: contains duplicates")

        enum = schema.get("enum")
        if enum is not None and (not isinstance(enum, list) or not enum):
            errors.append(f"{label}{pointer[1:]}/enum: must be a non-empty array")

        pattern = schema.get("pattern")
        if pattern is not None:
            if not isinstance(pattern, str):
                errors.append(f"{label}{pointer[1:]}/pattern: must be a string")
            else:
                try:
                    re.compile(pattern)
                except re.error as exc:
                    errors.append(f"{label}{pointer[1:]}/pattern: invalid regex: {exc}")

        for minimum_key, maximum_key in (
            ("minimum", "maximum"),
            ("minLength", "maxLength"),
            ("minItems", "maxItems"),
            ("minProperties", "maxProperties"),
        ):
            minimum = schema.get(minimum_key)
            maximum = schema.get(maximum_key)
            if minimum is not None and maximum is not None and minimum > maximum:
                errors.append(
                    f"{label}{pointer[1:]}: {minimum_key} ({minimum}) exceeds {maximum_key} ({maximum})"
                )
    return errors


def _optional_full_meta_validation(document: dict[str, Any], label: str) -> tuple[list[str], bool]:
    try:
        from jsonschema import Draft202012Validator
        from jsonschema.exceptions import SchemaError
    except ImportError:
        return [], False
    try:
        Draft202012Validator.check_schema(document)
    except SchemaError as exc:
        return [f"{label}: Draft 2020-12 meta-schema validation failed: {exc.message}"], True
    return [], True


def validate_schema_directory(
    schema_dir: Path,
    repo_root: Path = REPO_ROOT,
) -> tuple[int, int, bool, list[str]]:
    errors: list[str] = []
    files = sorted(schema_dir.glob("*.schema.json"))
    if not files:
        return 0, 0, False, [f"{schema_dir}: no *.schema.json files found"]

    seen_ids: dict[str, Path] = {}
    ref_count = 0
    full_meta = True
    for path in files:
        try:
            document = load_json(path)
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"{path}: cannot parse JSON: {exc}")
            continue
        label = str(path.relative_to(repo_root))
        errors.extend(validate_schema_document(document, label))
        extra_errors, used_full_meta = _optional_full_meta_validation(document, label)
        errors.extend(extra_errors)
        full_meta = full_meta and used_full_meta

        schema_id = document.get("$id")
        if isinstance(schema_id, str):
            if schema_id in seen_ids:
                errors.append(f"{label}: duplicate $id also used by {seen_ids[schema_id]}")
            else:
                seen_ids[schema_id] = path

        for pointer, ref in iter_refs(document):
            ref_count += 1
            try:
                resolve_ref(path, document, ref, repo_root)
            except (KeyError, OSError, ValueError, json.JSONDecodeError) as exc:
                errors.append(f"{label}{pointer[1:]}: unresolved $ref {ref!r}: {exc}")
    return len(files), ref_count, full_meta, errors


def validate_openapi_document(document: Any, label: str) -> tuple[int, int, list[str]]:
    errors: list[str] = []
    if not isinstance(document, dict):
        return 0, 0, [f"{label}: root must be an object"]
    version = document.get("openapi")
    if not isinstance(version, str) or not version.startswith("3.1."):
        errors.append(f"{label}: openapi must declare a 3.1.x version")
    if not isinstance(document.get("info"), dict):
        errors.append(f"{label}: info must be an object")
    paths = document.get("paths")
    if not isinstance(paths, dict) or not paths:
        return 0, 0, errors + [f"{label}: paths must be a non-empty object"]

    operation_ids: dict[str, str] = {}
    operation_count = 0
    for path_name, path_item in paths.items():
        if not isinstance(path_name, str) or not path_name.startswith("/"):
            errors.append(f"{label}: invalid path key {path_name!r}")
            continue
        if not isinstance(path_item, dict):
            errors.append(f"{label}: path {path_name} must be an object")
            continue
        for method, operation in path_item.items():
            if method not in HTTP_METHODS:
                continue
            operation_count += 1
            location = f"{method.upper()} {path_name}"
            if not isinstance(operation, dict):
                errors.append(f"{label}: {location} must be an object")
                continue
            operation_id = operation.get("operationId")
            if not isinstance(operation_id, str) or not operation_id:
                errors.append(f"{label}: {location} is missing operationId")
            elif operation_id in operation_ids:
                errors.append(
                    f"{label}: duplicate operationId {operation_id!r} at {location}; "
                    f"first used by {operation_ids[operation_id]}"
                )
            else:
                operation_ids[operation_id] = location
            responses = operation.get("responses")
            if not isinstance(responses, dict) or not responses:
                errors.append(f"{label}: {location} must declare responses")
    return len(paths), operation_count, errors


def validate_openapi_file(
    openapi_path: Path,
    repo_root: Path = REPO_ROOT,
) -> tuple[int, int, int, list[str]]:
    errors: list[str] = []
    try:
        document = load_yaml(openapi_path)
    except (OSError, yaml.YAMLError) as exc:
        return 0, 0, 0, [f"{openapi_path}: cannot parse YAML: {exc}"]
    label = str(openapi_path.relative_to(repo_root))
    paths, operations, document_errors = validate_openapi_document(document, label)
    errors.extend(document_errors)
    ref_count = 0
    for pointer, ref in iter_refs(document):
        ref_count += 1
        try:
            resolve_ref(openapi_path, document, ref, repo_root)
        except (KeyError, OSError, ValueError, json.JSONDecodeError, yaml.YAMLError) as exc:
            errors.append(f"{label}{pointer[1:]}: unresolved $ref {ref!r}: {exc}")
    return paths, operations, ref_count, errors


def validate_all(
    openapi_path: Path = DEFAULT_OPENAPI,
    schema_dir: Path = DEFAULT_SCHEMA_DIR,
    repo_root: Path = REPO_ROOT,
) -> ValidationReport:
    schema_files, schema_refs, full_meta, schema_errors = validate_schema_directory(
        schema_dir, repo_root
    )
    paths, operations, openapi_refs, openapi_errors = validate_openapi_file(
        openapi_path, repo_root
    )
    errors = schema_errors + openapi_errors
    if errors:
        raise ContractValidationError(errors)
    return ValidationReport(
        schema_files=schema_files,
        schema_refs=schema_refs,
        openapi_paths=paths,
        openapi_operations=operations,
        openapi_refs=openapi_refs,
        full_meta_validation=full_meta,
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--openapi", type=Path, default=DEFAULT_OPENAPI)
    parser.add_argument("--schema-dir", type=Path, default=DEFAULT_SCHEMA_DIR)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        report = validate_all(args.openapi.resolve(), args.schema_dir.resolve(), REPO_ROOT)
    except ContractValidationError as exc:
        print("Contract validation failed:", file=sys.stderr)
        for error in exc.errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    meta_mode = "full" if report.full_meta_validation else "built-in structural"
    print(
        "Contract validation passed: "
        f"{report.schema_files} schemas/{report.schema_refs} refs, "
        f"{report.openapi_paths} paths/{report.openapi_operations} operations/"
        f"{report.openapi_refs} refs; JSON Schema meta-check={meta_mode}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
