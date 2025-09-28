"""Data profiling service using Polars."""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

import polars as pl

from ..core import DataTooLargeError, InvalidRequestError, get_settings
from ..models import (
    ColumnProfile,
    DatasetProfileResponse,
    IngestRequest,
    IngestResponse,
)
from ..models.decision import SemanticType

logger = logging.getLogger(__name__)


class DataProfiler:
    def __init__(self, settings=None) -> None:
        self.settings = settings or get_settings()

    def _validate_path(self, path: Path) -> Path:
        if not path.exists():
            raise InvalidRequestError(f"Path not found: {path}")
        if path.is_dir():
            raise InvalidRequestError("Directory provided; expected a file")

        allowed_roots = self.settings.allowed_data_roots
        if allowed_roots:
            path = path.resolve()
            for root in allowed_roots:
                if path.is_relative_to(Path(root).resolve()):
                    break
            else:
                raise InvalidRequestError("Path not allowed by server configuration")

        return path

    def profile(self, request: IngestRequest) -> IngestResponse:
        file_path = self._validate_path(Path(request.path))

        size_mb = file_path.stat().st_size / (1024 * 1024)
        if size_mb > self.settings.max_file_mb:
            raise DataTooLargeError(
                f"File exceeds size limit {size_mb:.1f}MB > {self.settings.max_file_mb}MB",
                details={"limit": self.settings.max_file_mb, "size_mb": size_mb},
            )

        lazy_frame = self._read_lazy(file_path)
        sample_rows = request.sample_rows or self.settings.llm_sample_rows
        df_sample = lazy_frame.limit(sample_rows).collect()

        profile = self._profile_dataframe(df_sample)
        sample_records = df_sample.head(sample_rows).to_dicts()
        columns_meta = [
            {
                "name": col.name,
                "type": col.inferred_type.value,
            }
            for col in profile.columns
        ]

        suggestions = self._suggestions(profile)

        logger.info(
            "profile.generated",
            extra={"path": str(file_path), "rows": len(sample_records)},
        )

        return IngestResponse(
            profile=profile,
            sample=sample_records,
            columns_meta=columns_meta,
            suggestions=suggestions,
        )

    def _read_lazy(self, path: Path) -> pl.LazyFrame:
        suffix = path.suffix.lower()
        if suffix in {".csv", ".tsv"}:
            return pl.scan_csv(path, separator="," if suffix == ".csv" else "\t")
        if suffix == ".json":
            return pl.scan_ndjson(path)
        if suffix == ".ndjson":
            return pl.scan_ndjson(path)
        if suffix == ".parquet":
            return pl.scan_parquet(path)
        raise InvalidRequestError(f"Unsupported file type: {suffix}")

    def _profile_dataframe(self, df: pl.DataFrame) -> DatasetProfileResponse:
        columns = []
        issues: list[str] = []
        time_granularity: dict[str, str] = {}

        for column in df.schema:
            series = df[column]
            inferred_type = self._infer_type(series)

            unique = series.n_unique()
            missing = series.null_count()
            outliers = None

            if inferred_type == SemanticType.quantitative:
                q1 = series.quantile(0.25)
                q3 = series.quantile(0.75)
                iqr = q3 - q1
                if iqr is not None:
                    lower = q1 - 1.5 * iqr
                    upper = q3 + 1.5 * iqr
                    outliers = int(((series < lower) | (series > upper)).sum())
                    if outliers and outliers > 0:
                        issues.append(f"{column} has {outliers} outliers")

            if inferred_type == SemanticType.temporal:
                granularity = self._infer_time_granularity(series)
                if granularity:
                    time_granularity[column] = granularity

            if missing:
                issues.append(f"{column} has {missing} missing")

            columns.append(
                ColumnProfile(
                    name=column,
                    inferred_type=inferred_type,
                    unique=int(unique) if unique is not None else None,
                    missing=int(missing) if missing is not None else None,
                    outliers=outliers,
                )
            )

        profile = DatasetProfileResponse(
            row_count=df.height,
            columns=columns,
            issues=issues or None,
            time_granularity=time_granularity or None,
        )

        return profile

    def _infer_type(self, series: pl.Series) -> SemanticType:
        if series.dtype.is_numeric():
            return SemanticType.quantitative
        if series.dtype in {pl.Datetime, pl.Date}:  # type: ignore[arg-type]
            return SemanticType.temporal
        if series.dtype == pl.Boolean:
            return SemanticType.nominal
        if series.dtype == pl.Utf8:
            unique = series.n_unique()
            if unique is not None and unique < 20:
                return SemanticType.nominal
            return SemanticType.ordinal
        return SemanticType.nominal

    def _infer_time_granularity(self, series: pl.Series) -> str | None:
        try:
            dt_series = series.cast(pl.Datetime)
        except Exception:
            return None

        diffs = dt_series.sort().diff().drop_nulls()
        if diffs.is_empty():
            return None

        avg_diff = diffs.mean()
        if avg_diff is None:
            return None

        avg_seconds = avg_diff / 1_000_000_000

        if avg_seconds < 60:
            return "second"
        if avg_seconds < 3600:
            return "minute"
        if avg_seconds < 86400:
            return "hour"
        if avg_seconds < 604800:
            return "day"
        if avg_seconds < 2_592_000:
            return "week"
        if avg_seconds < 7_884_000:
            return "month"
        if avg_seconds < 31_536_000:
            return "quarter"
        return "year"

    def _suggestions(self, profile: DatasetProfileResponse) -> list[str]:
        suggestions: list[str] = []
        if profile.time_granularity:
            for column, unit in profile.time_granularity.items():
                if unit in {"day", "hour"}:
                    suggestions.append(f"Aggregate {column} to week for trend")
        if profile.issues:
            for issue in profile.issues:
                suggestions.append(issue)
        return suggestions


__all__ = ["DataProfiler"]
