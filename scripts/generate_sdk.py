#!/usr/bin/env python3
"""Generate deterministic operation registries for the V1 SDKs from OpenAPI."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
OPENAPI_PATH = REPO_ROOT / "openapi" / "openapi.yaml"
PYTHON_OUTPUT = (
    REPO_ROOT / "packages" / "sdk" / "python" / "interstellar_sdk" / "operations.py"
)
TYPESCRIPT_OUTPUT = (
    REPO_ROOT / "packages" / "sdk" / "typescript" / "src" / "operations.ts"
)
HTTP_METHODS = {"get", "post", "put", "patch", "delete", "head", "options", "trace"}


def load_operations(path: Path = OPENAPI_PATH) -> list[dict[str, Any]]:
    document = yaml.safe_load(path.read_text(encoding="utf-8"))
    server_url = str(document["servers"][0]["url"]).rstrip("/")
    operations: list[dict[str, Any]] = []
    for route, path_item in document["paths"].items():
        for method, operation in path_item.items():
            if method.lower() not in HTTP_METHODS:
                continue
            operations.append(
                {
                    "operation_id": str(operation["operationId"]),
                    "method": method.upper(),
                    "path": f"{server_url}{route}",
                }
            )
    operation_ids = [item["operation_id"] for item in operations]
    if len(operation_ids) != len(set(operation_ids)):
        raise ValueError("OpenAPI operationId values must be unique")
    return sorted(operations, key=lambda item: item["operation_id"])


def python_source(operations: list[dict[str, Any]]) -> str:
    payload = json.dumps(
        {
            item["operation_id"]: {"method": item["method"], "path": item["path"]}
            for item in operations
        },
        ensure_ascii=False,
        indent=4,
        sort_keys=True,
    )
    return (
        '"""Generated from openapi/openapi.yaml; do not edit manually."""\n\n'
        "from __future__ import annotations\n\n"
        "from typing import Final\n\n"
        f"OPERATIONS: Final[dict[str, dict[str, str]]] = {payload}\n"
    )


def typescript_source(operations: list[dict[str, Any]]) -> str:
    lines = [
        "// Generated from openapi/openapi.yaml; do not edit manually.",
        "export const OPERATIONS = {",
    ]
    for item in operations:
        operation_id = json.dumps(item["operation_id"])
        method = json.dumps(item["method"])
        path = json.dumps(item["path"])
        lines.append(f"  {operation_id}: {{ method: {method}, path: {path} }},")
    lines.extend(
        [
            "} as const;",
            "",
            "export type OperationId = keyof typeof OPERATIONS;",
            "export type OperationDefinition = (typeof OPERATIONS)[OperationId];",
            "",
        ]
    )
    return "\n".join(lines)


def expected_outputs() -> dict[Path, str]:
    operations = load_operations()
    return {
        PYTHON_OUTPUT: python_source(operations),
        TYPESCRIPT_OUTPUT: typescript_source(operations),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    stale: list[str] = []
    for path, content in expected_outputs().items():
        if args.check:
            if not path.is_file() or path.read_text(encoding="utf-8") != content:
                stale.append(str(path.relative_to(REPO_ROOT)))
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    if stale:
        print("Generated SDK operation registries are stale: " + ", ".join(stale))
        return 1
    if args.check:
        print("Generated SDK operation registries are deterministic and current.")
    else:
        print(
            f"Generated SDK operation registries for {len(load_operations())} operations."
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
