"""Pydantic models for the Sprint 1 backend."""

from typing import Any, Dict, List, Literal, Optional, Union

from pydantic import BaseModel, Field, field_validator, model_validator


ChartType = Literal["bar", "line", "histogram"]


class PlotChannel(BaseModel):
    field: str
    type: Literal["nominal", "ordinal", "quantitative", "temporal"]
    aggregate: Optional[Literal["sum", "mean", "median", "min", "max", "count"]] = None
    time_unit: Optional[Literal["auto", "day", "week", "month", "quarter", "year"]] = (
        None
    )
    bin: Optional[bool] = None

    @field_validator("time_unit", mode="before")
    @classmethod
    def normalize_time_unit(cls, v):
        if v == "None" or v is None:
            return None
        return v


class PlotSpec(BaseModel):
    x: PlotChannel
    y: PlotChannel
    series: Optional[PlotChannel] = None

    @field_validator("series", mode="before")
    @classmethod
    def normalize_series(cls, v):
        if v is None or v == []:
            return None
        if isinstance(v, dict) and "field" in v and "type" not in v:
            # Add default type based on common patterns
            if v["field"] in ["sales", "revenue", "value", "count"]:
                v["type"] = "quantitative"
            else:
                v["type"] = "nominal"
        return v


class ChartDecision(BaseModel):
    # Flexible chart field to handle different LLM response formats
    chart: Union[Dict[str, Any], str]
    title: str
    x_label: str
    y_label: Optional[str] = Field(default="")
    fields_used: List[str]
    plot: PlotSpec
    justification: str

    @model_validator(mode="before")
    @classmethod
    def normalize_input(cls, values):
        if isinstance(values, dict):
            # Handle nested structure where everything is under chart_decision
            if "chart_decision" in values:
                chart_decision = values["chart_decision"]

                if isinstance(chart_decision, str):
                    # chart_decision is a string, treat it as the chart type
                    return {
                        "chart": {"type": chart_decision, "score": 0.8},
                        "title": values.get("title", "Chart"),
                        "x_label": values.get("x_label", "X"),
                        "y_label": values.get("y_label", "Y"),
                        "fields_used": values.get("fields_used", []),
                        "plot": values.get(
                            "plot",
                            {
                                "x": {"field": "x", "type": "nominal"},
                                "y": {"field": "y", "type": "quantitative"},
                            },
                        ),
                        "justification": values.get(
                            "justification", "Auto-generated chart"
                        ),
                    }
                elif isinstance(chart_decision, dict):
                    # Create result starting with parent values, then override with chart_decision values
                    result = dict(values)
                    result.update(chart_decision)
                    del result["chart_decision"]  # Remove the nested key

                    # Handle the chart field specifically
                    if "chart" in result:
                        chart_value = result["chart"]
                        if isinstance(chart_value, str):
                            result["chart"] = {"type": chart_value, "score": 0.8}
                        elif (
                            isinstance(chart_value, dict)
                            and "chart_type" in chart_value
                        ):
                            result["chart"] = {
                                "type": chart_value["chart_type"],
                                "score": chart_value.get("score", 0.8),
                            }

                    return result
        return values

    @field_validator("chart", mode="before")
    @classmethod
    def normalize_chart(cls, v):
        if isinstance(v, str):
            # Convert string format to expected dict format
            return {"type": v, "score": 0.8}
        elif isinstance(v, dict) and "chart_type" in v:
            # Convert nested format to expected format
            return {"type": v["chart_type"], "score": v.get("score", 0.8)}
        return v


class AnalyzeResponse(BaseModel):
    decision: ChartDecision
    vega_lite: Dict[str, Any]
    warnings: List[str] = Field(default_factory=list)
