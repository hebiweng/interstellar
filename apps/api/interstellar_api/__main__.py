"""Local API entry point."""

import uvicorn

from interstellar_api.config import ApiSettings


def main() -> None:
    settings = ApiSettings.from_env()
    uvicorn.run(
        "interstellar_api.main:app",
        host=settings.server_host,
        port=settings.server_port,
        reload=False,
        log_level=settings.log_level.lower(),
    )


if __name__ == "__main__":
    main()
