"""Data profiling utilities for Sprint 1 backend."""

from __future__ import annotations

from typing import Dict, List

import pandas as pd
from dateutil import parser as dt_parser
from dateutil.parser import ParserError


def infer_semantic_type(series: pd.Series) -> str:
    """Determine a semantic type for the provided pandas Series."""

    if pd.api.types.is_numeric_dtype(series):
        return "quantitative"

    sample_values = series.dropna().astype(str).head(50)
    temporal_hits = 0
    for value in sample_values:
        try:
            dt_parser.parse(value, fuzzy=False)
            temporal_hits += 1
        except (ParserError, ValueError, TypeError):
            continue

    if temporal_hits >= max(3, len(sample_values) // 4):
        return "temporal"

    unique_count = series.dropna().nunique()
    return "nominal" if unique_count <= 50 else "ordinal"


def profile_df(df: pd.DataFrame) -> Dict[str, object]:
    """Return lightweight profiling information for the dataframe."""

    columns: List[Dict[str, object]] = []
    for column_name in df.columns:
        series = df[column_name]
        inferred_type = infer_semantic_type(series)

        # Get sample values for categorical/nominal columns
        sample_values = None
        if inferred_type in ["nominal", "ordinal"]:
            sample_values = (
                series.dropna().unique()[:10].tolist()
            )  # First 10 unique values
        elif inferred_type == "quantitative":
            # For numeric columns, provide min/max and a few sample values
            non_null_series = series.dropna()
            if len(non_null_series) > 0:
                sample_values = {
                    "min": float(non_null_series.min()),
                    "max": float(non_null_series.max()),
                    "samples": non_null_series.head(3).tolist(),
                }

        column_info = {
            "name": column_name,
            "inferred_type": inferred_type,
            "missing": int(series.isna().sum()),
            "unique": int(series.dropna().nunique()),
        }

        if sample_values is not None:
            column_info["sample_values"] = sample_values

        columns.append(column_info)

    return {"row_count": int(len(df)), "columns": columns}


def sample_df(df: pd.DataFrame, n: int) -> pd.DataFrame:
    """Return a random sample of n rows from the dataframe."""

    if len(df) <= n:
        return df
    return df.sample(n=n)
