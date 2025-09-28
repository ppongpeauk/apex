"""FastAPI application implementing the Sprint 1 backend as described in the PRD."""

from __future__ import annotations

import io
from typing import Any, Dict

import pandas as pd
from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from cache import get_cache
from data_utils import convert_to_parquet, is_parquet_file, read_parquet_data
from llm import call_llm
from models import AnalyzeResponse, ChartDecision
from profiling import profile_df, sample_df
from settings import (
    ALLOWED_CHART_TYPES,
    DEFAULT_SAMPLE_ROWS,
    MAX_FILE_BYTES,
    MAX_FILE_MB,
)
from vega import decision_to_vegalite


app = FastAPI(title="Auto Visualization Backend (Sprint 1)")


def _read_dataframe(filename: str | None, parquet_content: bytes) -> pd.DataFrame:
    """Parse Parquet data into a pandas DataFrame."""

    if not filename:
        raise HTTPException(status_code=400, detail="Uploaded file requires a name")

    # All data is now converted to Parquet format
    return read_parquet_data(parquet_content)


@app.post("/analyze", response_model=AnalyzeResponse)
async def analyze(
    file: UploadFile = File(...),
    sample_rows: int = Query(DEFAULT_SAMPLE_ROWS, ge=1, le=2000),
) -> JSONResponse:
    """Main endpoint that profiles data, calls the LLM, and returns a Vega-Lite spec."""

    print(f"Analyzing file {file.filename} with sample rows {sample_rows}")

    try:
        raw = await file.read()
        if not raw:
            raise HTTPException(status_code=400, detail="Empty file")

        if len(raw) > MAX_FILE_BYTES:
            raise HTTPException(
                status_code=400,
                detail=f"File too large (> {MAX_FILE_MB} MB)",
            )

        # Convert to Parquet if not already Parquet
        if not is_parquet_file(file.filename or ""):
            print("Converting file to Parquet format...")
            parquet_data = convert_to_parquet(raw, file.filename or "unknown")
        else:
            parquet_data = raw

        df = _read_dataframe(file.filename, parquet_data)
    except HTTPException:
        raise
    except Exception as exc:  # pragma: no cover - defensive path
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    # Check cache first using Parquet data
    cache = await get_cache()
    cached_result = await cache.get(parquet_data)
    if cached_result:
        print("Cache hit - returning cached result")
        return JSONResponse(cached_result)

    try:
        profile = profile_df(df)
        sample_records = sample_df(df, n=sample_rows).to_dict(orient="records")
    except Exception as exc:  # pragma: no cover - unexpected pandas issues
        raise HTTPException(status_code=500, detail=f"Profiling failed: {exc}") from exc

    prompt: Dict[str, Any] = {
        "allowed_chart_types": list(ALLOWED_CHART_TYPES),
        "columns": profile["columns"],
        "row_count": profile["row_count"],
        "sample": sample_records,
    }

    try:
        llm_output = await call_llm(
            model="", prompt=prompt
        )  # model parameter is ignored now
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"LLM call failed: {exc}") from exc

    try:
        decision = ChartDecision(**llm_output)
    except ValidationError as exc:
        raise HTTPException(
            status_code=422, detail=f"Schema validation failed: {exc}"
        ) from exc

    vega_spec = decision_to_vegalite(decision.model_dump())
    response = AnalyzeResponse(decision=decision, vega_lite=vega_spec, warnings=[])
    response_dict = response.model_dump()

    # Cache the result using Parquet data
    await cache.set(parquet_data, response_dict)
    print("Cached result for future use")

    return JSONResponse(response_dict)


@app.get("/cache/stats")
async def cache_stats():
    """Get cache statistics."""
    cache = await get_cache()
    # Get basic stats
    async with cache._db.execute("SELECT COUNT(*) FROM cache") as cursor:
        count = (await cursor.fetchone())[0]

    return {"total_entries": count, "cache_file": str(cache.db_path)}


@app.delete("/cache/clear")
async def clear_cache():
    """Clear all cache entries."""
    cache = await get_cache()
    await cache._db.execute("DELETE FROM cache")
    await cache._db.commit()
    return {"message": "Cache cleared", "entries_removed": 0}
