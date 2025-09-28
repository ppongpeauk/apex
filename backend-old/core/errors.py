"""Domain-specific error types and response helpers."""

from __future__ import annotations

from http import HTTPStatus
from typing import Any

from fastapi import HTTPException


class BackendException(Exception):
    """Base exception for backend errors."""

    status_code: HTTPStatus = HTTPStatus.INTERNAL_SERVER_ERROR
    error_code: str = "INTERNAL"

    def __init__(self, message: str, *, details: Any | None = None) -> None:
        super().__init__(message)
        self.details = details

    def to_http(self, *, correlation_id: str | None = None) -> HTTPException:
        payload = {
            "error": self.error_code,
            "message": str(self),
        }
        if self.details is not None:
            payload["details"] = self.details
        if correlation_id:
            payload["correlation_id"] = correlation_id

        return HTTPException(status_code=self.status_code.value, detail=payload)


class InvalidRequestError(BackendException):
    status_code = HTTPStatus.BAD_REQUEST
    error_code = "INVALID_REQUEST"


class DataTooLargeError(BackendException):
    status_code = HTTPStatus.REQUEST_ENTITY_TOO_LARGE
    error_code = "DATA_TOO_LARGE"


class SchemaValidationFailedError(BackendException):
    status_code = HTTPStatus.UNPROCESSABLE_ENTITY
    error_code = "SCHEMA_VALIDATION_FAILED"


class ModelDecisionFailedError(BackendException):
    status_code = HTTPStatus.FAILED_DEPENDENCY
    error_code = "MODEL_DECISION_FAILED"


__all__ = [
    "BackendException",
    "InvalidRequestError",
    "DataTooLargeError",
    "SchemaValidationFailedError",
    "ModelDecisionFailedError",
]
