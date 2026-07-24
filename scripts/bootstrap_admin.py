#!/usr/bin/env python3
"""Bootstrap or promote an account to super_admin and set default AI platform prompt."""

from __future__ import annotations

import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
API_ROOT = REPO_ROOT / "apps" / "api"

if str(API_ROOT) not in sys.path:
    sys.path.insert(0, str(API_ROOT))

from interstellar_api.account_store import AccountStore, DEFAULT_PLATFORM_AI_PROMPT
from interstellar_api.config import ApiSettings


def main() -> int:
    email = os.environ.get("INTERSTELLAR_ADMIN_BOOTSTRAP_EMAIL", "").strip()
    password = os.environ.get("INTERSTELLAR_ADMIN_BOOTSTRAP_PASSWORD", "").strip()
    display_name = os.environ.get("INTERSTELLAR_ADMIN_BOOTSTRAP_DISPLAY_NAME", "").strip() or "平台超级管理员"

    if not email:
        print("Error: INTERSTELLAR_ADMIN_BOOTSTRAP_EMAIL is not set.", file=sys.stderr)
        return 1

    settings = ApiSettings.from_env()
    store = AccountStore(database_path=settings.account_database_path)

    result = store.ensure_super_admin(email, password if password else None, display_name=display_name)
    print(f"超级管理员已就绪")
    print(f"  邮箱: {result['email']}")
    print(f"  昵称: {result['displayName']}")
    print(f"  角色: {result['role']}")
    print(f"  状态: {result['status']}")

    current = store.get_platform_ai_prompt()
    if not current["platform_prompt"]:
        store.set_platform_ai_prompt(
            DEFAULT_PLATFORM_AI_PROMPT,
            None,
            actor_email=email,
        )
        print(f"  AI 平台提示词已初始化为默认版本。")
    else:
        print(f"  AI 平台提示词已存在，未覆盖。")

    print(f"  管理后台: /admin")
    print(f"  本地地址: http://127.0.0.1:3001/admin")
    return 0


if __name__ == "__main__":
    sys.exit(main())
