# Backend PRD: FastAPI Service for Auto Visualization

## 1. Summary

A FastAPI service that accepts local file paths or file uploads, profiles the data, asks an OpenAI model to select a chart and explain why, validates the decision with Pydantic, applies transforms and filters on full data, and returns a renderable Vega-Lite spec plus a compact data payload. The macOS app is the client. Backend is Python. Use Polars for performance where possible.

## 2. Goals

* Single JSON contract for decisions that is stable across chart types
* Fast profiling on common files: CSV, JSON, Parquet, NDJSON
* Deterministic mapping from decision JSON to Vega-Lite
* Local filtering and aggregation without round trips to the model
* Strict schema validation with Pydantic AI models

## 3. Non-Goals

* No persistence of user data on disk, unless the user opts in to local caching
* No multi user auth or RBAC in v1
* No heavy data cleaning or joins across files

## 4. High Level Architecture

* **FastAPI app** served with Uvicorn
* **Data layer** using Polars for reading, profiling, filtering, and aggregation
* **Decision layer** uses OpenAI gpt-5-nano or gpt-5-mini to produce a chart decision JSON that matches a strict Pydantic model
* **Composer** builds a Vega-Lite JSON spec from the decision plus filtered data snapshot
* **Validation** with Pydantic. If model output fails, perform one repair attempt, then fallback chart rules locally if needed

```
Client (macOS) --> /ingest --> Profile JSON + sample
Client ---------> /decide --> Decision JSON
Client ---------> /render --> Vega-Lite JSON + data rows
```

## 5. Supported Inputs and Limits

* File types: .csv, .tsv, .json (array of objects), .ndjson, .parquet
* Size soft limit: 50 MB
* Row soft limit: 500k
* If limits are exceeded, service returns a 413 with advice and a sampling hint, or applies server side sampling when allowed

## 6. API Design

Base path: `/api/v1`

### 6.1 Health

**GET** `/healthz`
Returns 200 with `{"ok": true}`

### 6.2 Ingest

**POST** `/ingest`
Body:

```json
{
  "path": "/Users/pete/Desktop/sales.csv",
  "sample_rows": 1000,
  "type_hints": { "order_date": "temporal" }
}
```

Response:

```json
{
  "profile": { ...DatasetProfile... },
  "sample": [{ "order_date": "2024-01-01", "sales": 12.5, "region": "NE" }],
  "columns": [
    {"name":"order_date","type":"temporal"},
    {"name":"sales","type":"quantitative"},
    {"name":"region","type":"nominal"}
  ],
  "suggestions": ["Aggregate to week for trend"]
}
```

Errors:

* 400 invalid path or type
* 413 size limit exceeded

### 6.3 Decide

**POST** `/decide`
Body:

```json
{
  "profile": { ...DatasetProfile... },
  "sample": [ ... up to 1000 rows ... ],
  "columns": [ ... ],
  "prefer_model": "gpt-5-nano",
  "must_include_alternate": true
}
```

Response:

```json
{ ...VisualizationDecision... }
```

Notes:

* Service calls OpenAI with the schema and examples
* Validates with Pydantic
* If nano fails schema, retry once or promote to mini

### 6.4 Render

**POST** `/render`
Body:

```json
{
  "path": "/Users/pete/Desktop/sales.csv",
  "decision": { ...VisualizationDecision... },
  "filters": [
    {"field":"sales","op":"gt","value":100},
    {"field":"order_date","op":"between","values":["2024-01-01","2024-06-30"]}
  ],
  "limit_rows": 5000
}
```

Response:

```json
{
  "vega_lite": { ...valid Vega-Lite v5 spec... },
  "data": [ { "order_date": "2024-01-01", "sales_sum": 345.7 } ],
  "meta": {
    "applied_filters": 2,
    "rows_after_filter": 8172,
    "aggregated": true
  }
}
```

### 6.5 Models

**GET** `/models`
Returns available chart types, ops, time units, and current model selection.

## 7. Data Model

Use the unified decision schema from earlier. Pydantic models:

* `VisualizationDecision`
* `ChartChoice`, `AltChart`
* `FieldSpec`, `Transform`, `Encoding`
* `DatasetProfile`
* Filter grammar: `FilterSpec` with ops `eq, ne, gt, gte, lt, lte, in, not_in, between, is_null, is_not_null`

Store the Pydantic classes in `backend/models/decision.py`. Export JSON Schema for the OpenAI call.

## 8. Profiling and Type Inference

Library: Polars

Steps:

1. Detect file type by extension, with override from user
2. Lazy scan where possible
3. Sample first N rows for type inference and missingness
4. Infer semantic types

   * numeric → quantitative
   * ISO like strings or parsed dates → temporal
   * strings with low cardinality → nominal
   * ordered categories or Likert patterns → ordinal
   * lat lon pairs or known geo id patterns → geospatial
5. Column stats

   * unique count, missing count, min, max
   * outliers using IQR for numeric
   * time granularity guess for temporal columns: day, week, month

DatasetProfile shape:

```json
{
  "row_count": 12743,
  "columns": [
    {"name":"date","inferred_type":"temporal","unique":365,"missing":0},
    {"name":"sales","inferred_type":"quantitative","missing":12,"outliers":3}
  ],
  "issues": ["sales has 12 missing"],
  "time_granularity": {"date":"day"}
}
```

## 9. Decision Service

Prompt strategy:

* System prompt sets rules: choose one primary chart plus alternates, include fields, transforms, encoding, justification, warnings
* Provide the JSON Schema with `response_format` that enforces JSON
* Provide 2 or 3 in-context examples
* Temperature low, top_p default, max_tokens small to keep latency tight

Retry logic:

* If validation fails, run a short repair prompt with the exact Pydantic error messages
* If still failing and `prefer_model` is nano, promote to mini
* If model path fails, run a minimal local rule:

  * If 1 temporal + 1 quantitative → line
  * If 1 nominal + 1 quantitative → bar
  * If 2 quantitative → scatter
  * If 1 quantitative only → histogram

## 10. Transform and Filter Engine

All transforms are executed in Python using Polars. The LLM suggests transforms in the decision JSON. Backend validates that every referenced field exists and that aggregations are safe.

Supported transforms:

* `aggregate` with groupby fields and measures
* `bin` for numeric histograms using strategy parameter
* `time_unit` to derive week, month, quarter, year columns
* `filter` from client side requests
* `derive` with a safe subset of expressions. In v1 only allow named functions the backend implements, not freeform code

Filter grammar mapping to Polars:

* eq, ne → `pl.col(f) == v`, `!=`
* gt, gte, lt, lte → `>`, `>=`, `<`, `<=`
* in, not_in → `is_in`, `~is_in`
* between → `(col >= a) & (col <= b)`
* is_null, is_not_null → `.is_null()`, `.is_not_null()`

## 11. Vega-Lite Composer

Map decision to Vega-Lite v5. Use a small adapter per chart type.

Examples:

* Line:

  * x: temporal field with `timeUnit`
  * y: measure with `aggregate`
  * series → `color`
* Bar:

  * x: dimension, y: aggregate measure, `sort` by `-y`
* Histogram:

  * x: quantitative with `bin` param or `maxbins`
  * y: `count` or density via transform

Composer returns:

```json
{
  "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
  "data": { "values": [ ...rows...] },
  "mark": "line",
  "encoding": { ... },
  "config": { "axis": { "labelAngle": 0 } }
}
```

## 12. Error Handling

Error types and responses:

* 400 `INVALID_REQUEST` - bad path, unknown file type, invalid filters
* 413 `DATA_TOO_LARGE` - suggest sampling with limits
* 422 `SCHEMA_VALIDATION_FAILED` - include Pydantic errors and the bad payload id
* 424 `MODEL_DECISION_FAILED` - LLM unreachable or repeated invalid JSON
* 500 `INTERNAL` - include correlation id

Always return a `correlation_id` header for traceability.

## 13. Performance and Concurrency

Targets:

* Ingest and profile under 600 ms for 10 MB CSV
* Decide under 1.2 s with nano, under 2.5 s with mini
* Render under 400 ms for aggregation on 200k rows

Tactics:

* Use Polars lazy pipelines
* Push filters before aggregation
* Limit `sample_rows` to 1000 by default for the LLM
* Uvicorn with `--workers` = CPU cores
* Optional in process LRU for profiles keyed by file path and mtime

## 14. Security and Privacy

* No data leaves machine except the profile and small sample sent to the model
* Redact PII shaped columns in samples when possible
* Do not log raw data unless `LOG_DATA=true` in dev only
* Validate that `path` belongs to an allowed directory if configured

## 15. Configuration

Environment variables:

* `OPENAI_API_KEY`
* `OPENAI_MODEL_FAST=gpt-5-nano`
* `OPENAI_MODEL_STRICT=gpt-5-mini`
* `SERVICE_PORT=8080`
* `MAX_FILE_MB=50`
* `MAX_ROWS=500000`
* `LLM_SAMPLE_ROWS=1000`
* `CACHE_TTL_SEC=300`
* `LOG_LEVEL=INFO`

Use Pydantic Settings in `backend/config.py`.

## 16. Observability

* Structured logs with JSON
* Request duration, file size, row count, model used, validation retries
* `/metrics` Prometheus style in v1.1
* Correlation id per request

## 17. Testing Plan

Unit tests:

* Type inference across edge cases
* Filter grammar to Polars expressions
* Aggregation correctness for each chart type
* Vega-Lite composer snapshot tests

Integration tests:

* End to end on small fixtures: retail daily sales, survey Likert, accidents with lat lon
* Mock OpenAI to return golden decisions
* Load tests on large CSV to ensure streaming and memory bounds

Contract tests:

* Validate that any LLM response must pass `VisualizationDecision` Pydantic model

## 18. Folder Layout

```
backend/
  app.py                # FastAPI app factory
  routers/
    ingest.py
    decide.py
    render.py
    health.py
  models/
    decision.py         # Pydantic models
    profile.py
    filters.py
  services/
    profiler.py         # Polars based
    llm_decider.py      # OpenAI call + retries
    composer.py         # Vega-Lite adapter
    executor.py         # Transform and aggregation
  core/
    config.py
    logging.py
    errors.py
  tests/
    unit/
    integration/
  pyproject.toml
```

## 19. OpenAI Integration

* Build request with a compact system message that defines the roles, constraints, and the JSON Schema
* Provide the schema through `response_format` or include as plain text guardrails
* Set temperature near 0.1
* Token budget small since inputs are profiles and samples only
* Capture raw response for debugging in dev, but do not log in prod

Retry strategy:

* Validate with Pydantic
* On error, run a short repair prompt that includes the exact Pydantic error messages
* If still failing, switch to strict model
* If still failing, run local fallback rules

## 20. Versioning

* Prefix all routes with `/api/v1`
* Keep the decision schema backward compatible
* Add new fields as optional only

## 21. Risks and Mitigations

* **Model returns invalid JSON**: strict schema, repair prompt, fallback rules
* **Large files stall memory**: lazy scan, sampling, and row limits
* **Misleading charts**: encode guardrails into the prompt and composer, add warnings in response
* **Temporal gaps**: detect and report in `warnings` and allow resample to week or month

## 22. Sample Sequence

1. `/ingest`

```bash
curl -X POST http://localhost:8080/api/v1/ingest \
  -H "Content-Type: application/json" \
  -d '{"path":"/Users/pete/Desktop/sales.csv","sample_rows":1000}'
```

2. `/decide`

```bash
curl -X POST http://localhost:8080/api/v1/decide \
  -H "Content-Type: application/json" \
  -d '{"profile":{...},"sample":[...],"columns":[...],"prefer_model":"gpt-5-nano"}'
```

3. `/render`

```bash
curl -X POST http://localhost:8080/api/v1/render \
  -H "Content-Type: application/json" \
  -d '{"path":"/Users/pete/Desktop/sales.csv","decision":{...},"filters":[{"field":"sales","op":"gt","value":100}]}'
```

## 23. Acceptance Criteria

* Given a valid CSV under limits, `/ingest` returns a profile within 600 ms on a modern laptop
* Given a valid profile and sample, `/decide` returns a valid `VisualizationDecision` JSON with at least one alternate
* Given a valid decision, `/render` returns a valid Vega-Lite spec and data rows that match the spec
* Filters change the returned rows and aggregates correctly for numeric and temporal columns
* Warnings are returned when guardrails trigger, such as pie slices over threshold or uneven sampling

If you want, I can scaffold the FastAPI routers and the Polars based profiler so you can paste them into a repo and run `uvicorn backend.app:app --reload`.
