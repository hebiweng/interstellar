from __future__ import annotations

import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = REPO_ROOT / "scripts"
SDK_PYTHON = REPO_ROOT / "packages" / "sdk" / "python"
sys.path.insert(0, str(SCRIPTS))
sys.path.insert(0, str(SDK_PYTHON))

import generate_sdk  # noqa: E402
from interstellar_sdk.client import InterstellarClient, _parse_sse_lines  # noqa: E402
from interstellar_sdk.operations import OPERATIONS  # noqa: E402


class SdkGenerationTests(unittest.TestCase):
    def test_generated_operation_registries_are_current(self) -> None:
        for path, content in generate_sdk.expected_outputs().items():
            self.assertTrue(path.is_file(), path)
            self.assertEqual(path.read_text(encoding="utf-8"), content, path)
        self.assertEqual(len(OPERATIONS), 52)
        self.assertIn("getCalculationTable", OPERATIONS)
        self.assertEqual(OPERATIONS["streamJobEvents"]["method"], "GET")

    def test_python_client_renders_encoded_path_and_repeated_query(self) -> None:
        client = InterstellarClient("https://example.test/")
        url = client._url(
            "/api/v1/subjects/{id}",
            {"id": "person / one"},
            {"tag": ["alpha", "beta"], "enabled": True, "empty": None},
        )
        self.assertEqual(
            url,
            "https://example.test/api/v1/subjects/person%20%2F%20one"
            "?tag=alpha&tag=beta&enabled=true",
        )

    def test_sse_parser_resumes_structured_events(self) -> None:
        events = list(
            _parse_sse_lines(
                iter(
                    [
                        "id: 4",
                        "event: progress",
                        'data: {"progress":50}',
                        "",
                        ": keep-alive",
                        "id: 5",
                        "event: completed",
                        "data: done",
                        "",
                    ]
                )
            )
        )
        self.assertEqual(
            [(item.event_id, item.event) for item in events],
            [("4", "progress"), ("5", "completed")],
        )


if __name__ == "__main__":
    unittest.main()
