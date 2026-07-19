"""Isolated DeepSeek text-analysis adapter.

This module receives an already calculated, user-approved natal document.  It
never imports or calls the deterministic astrology engine.
"""

from __future__ import annotations

import asyncio
import json
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


class DeepSeekRequestError(RuntimeError):
    """A sanitized third-party request failure that never includes credentials."""


async def execute_deepseek_analysis(
    payload: dict[str, Any],
    *,
    api_key: str,
    base_url: str,
    model: str,
) -> dict[str, Any]:
    if payload.get("provider_id") != "deepseek":
        raise DeepSeekRequestError("The configured executor only accepts DeepSeek requests.")

    document = str(payload.get("technical_document") or "").strip()
    if not document:
        raise DeepSeekRequestError("The natal analysis document is empty.")
    focus = str(payload.get("analysis_focus") or "").strip()
    focus_instruction = (
        f"\n\n用户希望优先分析：{focus}" if focus else ""
    )
    body = {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": (
                    "你是一名严谨的专业西方占星分析助手。只依据用户提供的确定性计算结果进行综合，"
                    "清楚区分事实、占星解释和不确定性；不要重新计算或臆造行星、宫位、相位、尊贵，"
                    "不要作保证升职、复合、疾病、死亡、投资收益等确定性预测。用中文输出结构清楚、"
                    "可读的专业分析。"
                ),
            },
            {
                "role": "user",
                "content": f"请分析以下本命盘资料：{focus_instruction}\n\n{document}",
            },
        ],
        "stream": False,
        "temperature": 0.3,
        "max_tokens": 4_000,
    }

    def send() -> dict[str, Any]:
        request = Request(
            f"{base_url.rstrip('/')}/chat/completions",
            data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
            method="POST",
        )
        try:
            with urlopen(request, timeout=90) as response:  # noqa: S310 - fixed operator URL
                decoded = json.loads(response.read().decode("utf-8"))
        except HTTPError as exc:
            raise DeepSeekRequestError(
                f"DeepSeek returned HTTP {exc.code}. Please retry or verify server configuration."
            ) from exc
        except URLError as exc:
            raise DeepSeekRequestError(
                "DeepSeek is temporarily unreachable. Please retry later."
            ) from exc
        except (TimeoutError, json.JSONDecodeError) as exc:
            raise DeepSeekRequestError(
                "DeepSeek returned an invalid or timed-out response."
            ) from exc

        choices = decoded.get("choices") if isinstance(decoded, dict) else None
        first = choices[0] if isinstance(choices, list) and choices else None
        message = first.get("message") if isinstance(first, dict) else None
        content = message.get("content") if isinstance(message, dict) else None
        if not isinstance(content, str) or not content.strip():
            raise DeepSeekRequestError("DeepSeek returned no analysis text.")
        return {
            "text": content.strip(),
            "model": str(decoded.get("model") or model),
            "finish_reason": first.get("finish_reason") if isinstance(first, dict) else None,
            "usage": decoded.get("usage") if isinstance(decoded.get("usage"), dict) else None,
        }

    return await asyncio.to_thread(send)
