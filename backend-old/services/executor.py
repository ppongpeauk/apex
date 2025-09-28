"""Transform and aggregation executor using Polars."""

from __future__ import annotations

import logging
from typing import Any

import polars as pl

from ..core import InvalidRequestError, get_settings
from ..models import FilterRequest, FilterSpecRequest, VisualizationDecision
from ..models.decision import (
    AggregateOp,
    AggregateSpec,
    BinSpec,
    FilterOp,
    SemanticType,
    TimeUnit,
)
from ..utils.files import validate_data_path

logger = logging.getLogger(__name__)


class TransformExecutor:
    def __init__(self, settings=None) -> None:
        self.settings = settings or get_settings()

    def execute(
        self,
        path: str,
        decision: VisualizationDecision,
        filters: list[FilterSpecRequest] | None = None,
        limit_rows: int | None = None,
    ) -> tuple[pl.DataFrame, dict[str, Any]]:
        file_path = validate_data_path(path)
        lazy_frame = self._read_lazy(file_path)

        lazy_frame = self._apply_filters(lazy_frame, filters)
        lazy_frame = self._apply_transforms(lazy_frame, decision)

        if limit_rows:
            lazy_frame = lazy_frame.limit(limit_rows)

        df = lazy_frame.collect()

        meta = {
            "rows_after_filter": df.height,
            "applied_filters": len(filters or []),
        }

        return df, meta

    def _read_lazy(self, path) -> pl.LazyFrame:
        suffix = path.suffix.lower()
        if suffix in {".csv", ".tsv"}:
            return pl.scan_csv(path, separator="," if suffix == ".csv" else "\t")
        if suffix == ".json" or suffix == ".ndjson":
            return pl.scan_ndjson(path)
        if suffix == ".parquet":
            return pl.scan_parquet(path)
        raise InvalidRequestError(f"Unsupported file type: {suffix}")

    def _apply_filters(
        self, lazy_frame: pl.LazyFrame, filters: list[FilterSpecRequest] | None
    ) -> pl.LazyFrame:
        if not filters:
            return lazy_frame

        for spec in filters:
            column = spec.field
            col_expr = pl.col(column)
            if spec.op == FilterOp.eq:
                lazy_frame = lazy_frame.filter(col_expr == spec.value)
            elif spec.op == FilterOp.ne:
                lazy_frame = lazy_frame.filter(col_expr != spec.value)
            elif spec.op == FilterOp.gt:
                lazy_frame = lazy_frame.filter(col_expr > spec.value)
            elif spec.op == FilterOp.gte:
                lazy_frame = lazy_frame.filter(col_expr >= spec.value)
            elif spec.op == FilterOp.lt:
                lazy_frame = lazy_frame.filter(col_expr < spec.value)
            elif spec.op == FilterOp.lte:
                lazy_frame = lazy_frame.filter(col_expr <= spec.value)
            elif spec.op == FilterOp.in_:
                lazy_frame = lazy_frame.filter(col_expr.is_in(spec.values or []))
            elif spec.op == FilterOp.not_in:
                lazy_frame = lazy_frame.filter(~col_expr.is_in(spec.values or []))
            elif spec.op == FilterOp.between:
                if not spec.values or len(spec.values) != 2:
                    raise InvalidRequestError("between filter expects two values")
                lazy_frame = lazy_frame.filter(col_expr.is_between(*spec.values))
            elif spec.op == FilterOp.is_null:
                lazy_frame = lazy_frame.filter(col_expr.is_null())
            elif spec.op == FilterOp.is_not_null:
                lazy_frame = lazy_frame.filter(col_expr.is_not_null())
            else:
                raise InvalidRequestError(f"Unsupported filter operation: {spec.op}")

        return lazy_frame

    def _apply_transforms(
        self, lazy_frame: pl.LazyFrame, decision: VisualizationDecision
    ) -> pl.LazyFrame:
        transform = decision.transform
        if not transform:
            return lazy_frame

        if transform.filter:
            lazy_frame = self._apply_filters(lazy_frame, transform.filter)

        if transform.time_unit:
            for spec in transform.time_unit:
                alias = (
                    spec.field
                    if spec.unit == TimeUnit.auto
                    else f"{spec.field}:{spec.unit.value}"
                )
                lazy_frame = lazy_frame.with_columns(
                    pl.col(spec.field)
                    .cast(pl.Datetime)
                    .dt.truncate(self._time_unit_to_pl_duration(spec.unit))
                    .alias(alias),
                )

        if transform.derive:
            for derive in transform.derive:
                raise InvalidRequestError("derive transform not implemented in v1")

        if transform.bin:
            for bin_spec in transform.bin:
                lazy_frame = self._apply_bin(lazy_frame, bin_spec)

        if transform.aggregate:
            for aggregate in transform.aggregate:
                lazy_frame = self._apply_aggregate(lazy_frame, aggregate)

        return lazy_frame

    def _time_unit_to_pl_duration(self, unit: TimeUnit) -> str:
        mapping = {
            TimeUnit.second: "1s",
            TimeUnit.minute: "1m",
            TimeUnit.hour: "1h",
            TimeUnit.day: "1d",
            TimeUnit.week: "1w",
            TimeUnit.month: "1mo",
            TimeUnit.quarter: "3mo",
            TimeUnit.year: "1y",
        }
        return mapping.get(unit, "1d")

    def _apply_bin(self, lazy_frame: pl.LazyFrame, spec: BinSpec) -> pl.LazyFrame:
        field = spec.field
        params = spec.params
        if params and params.step:
            step = params.step
            lazy_frame = lazy_frame.with_columns((pl.col(field) / step).floor() * step)
        else:
            lazy_frame = lazy_frame.with_columns(
                pl.col(field).cut(bin_count=params.maxbins if params else 10)
            )
        return lazy_frame

    def _apply_aggregate(
        self, lazy_frame: pl.LazyFrame, spec: AggregateSpec
    ) -> pl.LazyFrame:
        groupby_exprs = [pl.col(col) for col in spec.groupby]
        agg_exprs = []
        for measure in spec.measures:
            agg_exprs.append(self._aggregate_expression(measure))

        return lazy_frame.group_by(groupby_exprs).agg(agg_exprs)

    def _aggregate_expression(self, measure) -> pl.Expr:
        field = measure.field
        op = measure.op
        alias = measure.as_ or f"{field}_{op}"

        ops_map = {
            AggregateOp.sum: pl.col(field).sum().alias(alias),
            AggregateOp.mean: pl.col(field).mean().alias(alias),
            AggregateOp.median: pl.col(field).median().alias(alias),
            AggregateOp.min: pl.col(field).min().alias(alias),
            AggregateOp.max: pl.col(field).max().alias(alias),
            AggregateOp.count: pl.col(field).count().alias(alias),
        }

        if op not in ops_map:
            raise InvalidRequestError(f"Unsupported aggregate operation: {op}")

        return ops_map[op]


__all__ = ["TransformExecutor"]
