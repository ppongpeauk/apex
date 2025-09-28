"""Pydantic models representing the visualization decision contract."""

from __future__ import annotations

from enum import Enum, StrEnum
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator


class ChartType(StrEnum):
    bar = "bar"
    column = "column"
    line = "line"
    area = "area"
    scatter = "scatter"
    histogram = "histogram"
    boxplot = "boxplot"
    stacked_bar = "stacked_bar"
    diverging_stacked_bar = "diverging_stacked_bar"
    pie = "pie"
    heatmap = "heatmap"
    hexbin = "hexbin"
    geo_choropleth = "geo_choropleth"


class SemanticType(StrEnum):
    nominal = "nominal"
    ordinal = "ordinal"
    quantitative = "quantitative"
    temporal = "temporal"
    geospatial = "geospatial"


class FieldRole(StrEnum):
    dimension = "dimension"
    measure = "measure"
    time = "time"
    series = "series"
    geo = "geo"
    value = "value"
    x = "x"
    y = "y"


class AggregateOp(StrEnum):
    sum = "sum"
    mean = "mean"
    median = "median"
    min = "min"
    max = "max"
    count = "count"
    auto = "auto"


class TimeUnit(StrEnum):
    auto = "auto"
    second = "second"
    minute = "minute"
    hour = "hour"
    day = "day"
    week = "week"
    month = "month"
    quarter = "quarter"
    year = "year"


class FieldSpec(BaseModel):
    name: str
    role: FieldRole
    type: SemanticType
    aggregate: AggregateOp | None = None
    time_unit: TimeUnit | None = None
    binned: bool | None = None
    description: str | None = None


class BinParam(BaseModel):
    strategy: Literal["auto", "fd", "sturges", "scott"] | None = None
    maxbins: int | None = Field(default=None, ge=1)
    step: float | None = Field(default=None, gt=0)


class BinSpec(BaseModel):
    field: str
    params: BinParam | None = None


class TimeUnitSpec(BaseModel):
    field: str
    unit: TimeUnit


class DeriveSpec(BaseModel):
    as_: str = Field(alias="as")
    expr: str

    model_config = {
        "populate_by_name": True,
    }


class AggregateMeasure(BaseModel):
    field: str
    op: AggregateOp
    as_: str | None = Field(default=None, alias="as")

    model_config = {
        "populate_by_name": True,
    }


class AggregateSpec(BaseModel):
    groupby: list[str]
    measures: list[AggregateMeasure]


class FilterOp(StrEnum):
    is_null = "is_null"
    is_not_null = "is_not_null"
    eq = "eq"
    ne = "ne"
    gt = "gt"
    gte = "gte"
    lt = "lt"
    lte = "lte"
    in_ = "in"
    not_in = "not_in"
    between = "between"
    regex = "regex"


class FilterSpec(BaseModel):
    field: str
    op: FilterOp
    value: Any | None = None
    values: list[Any] | None = None

    @field_validator("values", mode="after")
    @classmethod
    def validate_values(cls, value: list[Any] | None) -> list[Any] | None:
        if value is not None and len(value) == 0:
            raise ValueError("values cannot be empty")
        return value


class AggregateTransform(BaseModel):
    aggregate: list[AggregateSpec] | None = None


class BinTransform(BaseModel):
    bin: list[BinSpec] | None = None


class TimeUnitTransform(BaseModel):
    time_unit: list[TimeUnitSpec] | None = None


class DeriveTransform(BaseModel):
    derive: list[DeriveSpec] | None = None


class FilterTransform(BaseModel):
    filter: list[FilterSpec] | None = None


class Transform(
    AggregateTransform,
    BinTransform,
    TimeUnitTransform,
    DeriveTransform,
    FilterTransform,
):
    pass


class Channel(BaseModel):
    field: str | None = None
    aggregate: AggregateOp | None = None
    time_unit: TimeUnit | None = None
    bin: bool | BinParam | None = None
    type: SemanticType | None = None


class FacetChannel(BaseModel):
    field: str | None = None
    type: Literal["nominal", "ordinal"] | None = None
    max_columns: int | None = Field(default=None, ge=1)


class OrderChannel(BaseModel):
    by: str | None = None
    direction: Literal["asc", "desc"] | None = None


class Encoding(BaseModel):
    x: Channel | None = None
    y: Channel | None = None
    color: Channel | None = None
    size: Channel | None = None
    shape: Channel | None = None
    row: FacetChannel | None = None
    column: FacetChannel | None = None
    order: OrderChannel | None = None


class WarningCode(StrEnum):
    high_cardinality = "HIGH_CARDINALITY"
    pie_too_many_slices = "PIE_TOO_MANY_SLICES"
    uneven_sampling = "UNEVEN_SAMPLING"
    missing_values = "MISSING_VALUES"
    too_many_points = "TOO_MANY_POINTS"
    join_mismatch = "JOIN_MISMATCH"
    axis_truncation = "AXIS_TRUNCATION"


class Warning(BaseModel):
    code: WarningCode
    message: str


class ColumnProfile(BaseModel):
    name: str
    inferred_type: SemanticType
    unique: int | None = Field(default=None, ge=0)
    missing: int | None = Field(default=None, ge=0)
    outliers: int | None = Field(default=None, ge=0)


class DatasetProfile(BaseModel):
    row_count: int | None = Field(default=None, ge=0)
    columns: list[ColumnProfile] | None = None
    issues: list[str] | None = None
    time_granularity: dict[str, TimeUnit] | None = None


class ChartAlternate(BaseModel):
    type: ChartType
    score: float = Field(ge=0, le=1)
    why: str | None = None


class Chart(BaseModel):
    type: ChartType
    score: float = Field(ge=0, le=1)
    alternates: list[ChartAlternate] | None = None

    @field_validator("alternates", mode="after")
    @classmethod
    def validate_alternates(
        cls, value: list[ChartAlternate] | None
    ) -> list[ChartAlternate] | None:
        if value is not None and len(value) == 0:
            raise ValueError("alternates cannot be empty array")
        return value


class RenderHints(BaseModel):
    x_rotation: int | None = Field(default=None, ge=0, le=90)
    y_zero: bool | None = None
    stack: Literal["none", "normal", "percent"] | None = None
    label_format: Literal["abbrev", "full", "percent"] | None = None
    tooltip: list[str] | None = None


class DataChecks(BaseModel):
    missing: dict[str, int] | None = None
    outliers: dict[str, dict[str, Any]] | None = None
    cardinality: dict[str, int] | None = None


class VisualizationDecision(BaseModel):
    chart: Chart
    fields: list[FieldSpec]
    transform: Transform | None = None
    encoding: Encoding
    assumptions: list[str] | None = None
    justification: str
    data_checks: DataChecks | None = None
    render_hints: RenderHints | None = None
    profile: DatasetProfile | None = None
    warnings: list[Warning] | None = None
    errors: list[str] | None = None

    model_config = {
        "json_schema_extra": {
            "examples": [],
        }
    }


__all__ = [
    "VisualizationDecision",
    "Chart",
    "ChartAlternate",
    "ChartType",
    "FieldSpec",
    "FieldRole",
    "Channel",
    "FacetChannel",
    "Encoding",
    "AggregateSpec",
    "AggregateMeasure",
    "AggregateOp",
    "BinSpec",
    "BinParam",
    "TimeUnit",
    "TimeUnitSpec",
    "DeriveSpec",
    "FilterOp",
    "FilterSpec",
    "Transform",
    "RenderHints",
    "Warning",
    "WarningCode",
    "DatasetProfile",
    "ColumnProfile",
]
