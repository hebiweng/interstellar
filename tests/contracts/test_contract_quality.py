from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import generate_contract_types  # noqa: E402
import validate_openapi  # noqa: E402


class ContractQualityTests(unittest.TestCase):
    def test_repository_contracts_are_valid(self) -> None:
        report = validate_openapi.validate_all()
        self.assertEqual(report.schema_files, 15)
        self.assertEqual(report.openapi_paths, 46)
        self.assertEqual(report.openapi_operations, 52)
        self.assertGreater(report.schema_refs, 0)
        self.assertGreater(report.openapi_refs, 0)

    def test_duplicate_operation_id_is_rejected(self) -> None:
        document = copy.deepcopy(validate_openapi.load_yaml(validate_openapi.DEFAULT_OPENAPI))
        document["paths"]["/techniques"]["get"]["operationId"] = document["paths"][
            "/entry-points"
        ]["get"]["operationId"]
        _, _, errors = validate_openapi.validate_openapi_document(document, "mutated.yaml")
        self.assertTrue(
            any("duplicate operationId" in error for error in errors),
            errors,
        )

    def test_invalid_json_schema_type_is_rejected_without_optional_dependency(self) -> None:
        document = {
            "$schema": validate_openapi.JSON_SCHEMA_DIALECT,
            "$id": "https://interstellar.dev/schemas/test/invalid.schema.json",
            "type": "mystery",
        }
        errors = validate_openapi.validate_schema_document(document, "invalid.schema.json")
        self.assertTrue(any("invalid JSON Schema type" in error for error in errors), errors)

    def test_generated_contracts_have_zero_diff(self) -> None:
        expected = generate_contract_types.expected_outputs(
            generate_contract_types.DEFAULT_SCHEMA_DIR,
            generate_contract_types.DEFAULT_OPENAPI,
        )
        for name, content in expected.items():
            path = generate_contract_types.DEFAULT_OUTPUT_DIR / name
            self.assertTrue(path.is_file(), f"missing generated contract: {path}")
            self.assertEqual(path.read_text(encoding="utf-8"), content, f"stale: {path}")

    def test_generated_python_index_compiles(self) -> None:
        source = (generate_contract_types.DEFAULT_OUTPUT_DIR / "types.py").read_text(
            encoding="utf-8"
        )
        compile(source, "generated/types.py", "exec")

    def test_generated_manifest_records_all_sources_and_operations(self) -> None:
        manifest = json.loads(
            (generate_contract_types.DEFAULT_OUTPUT_DIR / "manifest.lock").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(len(manifest["schemas"]), 15)
        self.assertEqual(len(manifest["operation_ids"]), 52)
        self.assertEqual(len(manifest["operation_ids"]), len(set(manifest["operation_ids"])))
        self.assertTrue(all(len(item["sha256"]) == 64 for item in manifest["schemas"]))


if __name__ == "__main__":
    unittest.main()
