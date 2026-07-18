"""Base domain errors that transport layers may translate."""


class DomainError(Exception):
    """Expected domain failure with a stable machine code."""

    def __init__(self, code: str, detail: str) -> None:
        super().__init__(detail)
        self.code = code
        self.detail = detail
