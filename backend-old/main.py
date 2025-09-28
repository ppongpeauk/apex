"""Entrypoint for running the FastAPI app with Uvicorn."""

from __future__ import annotations

import uvicorn

from .app import app


def main() -> None:
    uvicorn.run("backend.app:app", host="0.0.0.0", port=8080, reload=True)


if __name__ == "__main__":
    main()
