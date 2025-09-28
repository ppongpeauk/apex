# Sprint 1 PRD — Backend Skeleton (FastAPI + Pydantic + Vega-Lite)

**Objective:** deliver an end-to-end backend that ingests a data file, profiles columns, calls an OpenAI model (gpt-5-nano/mini) to select a chart and explain it, validates the model output with Pydantic, and returns a minimal **Vega-Lite** spec + justification. This document is written to be executed directly in Cursor AI.

---

## 1) Scope (Sprint 1 Only)

* **In**

  * FastAPI service running on `localhost` with one primary endpoint: `POST /analyze` (multipart upload).
  * File parsing: CSV, TSV, JSON (array or NDJSON), Parquet.
  * Automatic conversion: All ingested data is converted to Parquet format for improved performance and type handling.
  * Lightweight profiling: inferred semantic type per column, missing count, unique count.
  * LLM call (gpt-5-nano default; gpt-5-mini fallback) to choose **one** chart type from the allowed list (see §6).
  * Strict Pydantic validation of the LLM decision.
  * Minimal **Vega-Lite** spec assembly for **bar**, **line**, and **histogram** (implemented); other types temporarily blocked at prompt-time.
  * JSON response returning: decision, vega_lite spec, warnings.

* **Out**

  * No persistence, auth, cache, or filter UI.
  * No macOS native UI.
  * No Parquet (can be added next sprint).
  * No alternates list (primary chart only in sprint 1).

---

## 2) Acceptance Criteria

* Uploading a valid CSV with one categorical column and one numeric column returns:

  * `200 OK` with `chart.type = "bar"`, a clear title, axis labels, a short justification, and a valid Vega-Lite spec that renders correctly in an online Vega-Lite viewer.
* Uploading a dataset with a temporal column (parsable date) and one numeric column returns a `line` chart decision with weekly or monthly time_unit (if needed) and a valid Vega-Lite spec.
* Uploading a one-column numeric file returns a `histogram` decision with binning reflected in the Vega-Lite spec.
* Invalid LLM JSON or schema violations result in `422` with a concise error message; corrupt file/type returns `400`.
* The endpoint handles files up to **10 MB** within **≤ 2.5s** on a modern Mac (cold LLM latency excluded).

---

## 3) Architecture Overview

```
Client (curl/Postman/temporary UI)
   |
   |  multipart/form-data (file=...)
   v
FastAPI (app)
   ├─ parsing: CSV/TSV/JSON → pandas.DataFrame
   ├─ profiling: infer semantic types, missing, unique, sample head(N)
   ├─ LLM call: gpt-5-nano (schema-guided JSON)
   ├─ validation: Pydantic models
   └─ vega-lite: assembly for bar/line/histogram → JSON response
```

---

## 4) Directory Structure (Cursor-ready)

```
backend/
  app.py                 # FastAPI entry
  models.py              # Pydantic models for request/response
  profiling.py           # type inference + profiling utilities
  llm.py                 # OpenAI call wrapper
  vega.py                # decision → Vega-Lite spec
  settings.py            # env vars, constants
  requirements.txt
  tests/
    test_smoke.py
    samples/
      cats_nums.csv
      temporal_numeric.csv
      single_numeric.csv
  .env.example
  Makefile
  README.md
```

---

## 5) Environment & Dependencies

* **Python:** 3.11+
* **Packages:**

  * `fastapi`, `uvicorn[standard]`
  * `pydantic` (v2)
  * `pandas`, `python-dateutil`
  * `python-dotenv`
  * `httpx` (if using async OpenAI client)

**requirements.txt**

```
fastapi==0.115.0
uvicorn[standard]==0.30.6
pydantic==2.8.2
pandas==2.2.2
python-dateutil==2.9.0.post0
python-dotenv==1.0.1
httpx==0.27.0
```

**.env.example**

```
OPENAI_API_KEY=sk-...
MODEL_DEFAULT=gpt-5-nano
MODEL_FALLBACK=gpt-5-mini
SAMPLE_ROWS=200
MAX_FILE_MB=10
```

---

## 6) Supported Chart Types (Sprint 1)

* **Implemented:** `bar`, `line`, `histogram`
* **Temporarily blocked at prompt:** `column`, `pie`, `scatter`, `boxplot`, `area`

> Rationale: guarantees a stable demo within the 16-hour window. Sprint 2 can expand types.

---

## 7) API Contract

### 7.1 `POST /analyze`

**Request (multipart/form-data)**

* `file`: required; `.csv`, `.tsv`, `.json` (array or NDJSON)
* Query params (optional):

  * `sample_rows` (int, default from `.env`)
  * `model` in `{gpt-5-nano, gpt-5-mini}`

**Response 200 (application/json)**

```json
{
  "decision": {
    "chart": {"type":"bar","score":0.86},
    "title": "Total Sales by Region",
    "x_label": "Region",
    "y_label": "Total Sales",
    "fields_used": ["region","sales"],
    "plot": {
      "x": {"field":"region","type":"nominal"},
      "y": {"field":"sales","type":"quantitative","aggregate":"sum"},
      "series": null
    },
    "justification": "Categories are discrete; bar best communicates comparison."
  },
  "vega_lite": { "$schema": "https://vega.github.io/schema/vega-lite/v5.json", "...": "..." },
  "warnings": []
}
```

**Errors**

* `400` unsupported file or empty body
* `422` LLM output failed schema validation
* `500` unexpected error

**cURL smoke test**

```bash
curl -F "file=@tests/samples/cats_nums.csv" "http://localhost:8000/analyze?sample_rows=200&model=gpt-5-nano" | jq .
```

---

## 8) Pydantic Models (Authoritative)

**models.py**

```python
from typing import List, Optional, Literal, Dict, Any
from pydantic import BaseModel, Field

ChartType = Literal["bar","line","histogram"]  # sprint 1 only

class PlotChannel(BaseModel):
    field: str
    type: Literal["nominal","ordinal","quantitative","temporal"]
    aggregate: Optional[Literal["sum","mean","median","min","max","count"]] = None
    time_unit: Optional[Literal["auto","day","week","month","quarter","year"]] = None
    bin: Optional[bool] = None

class PlotSpec(BaseModel):
    x: PlotChannel
    y: PlotChannel
    series: Optional[PlotChannel] = None

class ChartDecision(BaseModel):
    chart: Dict[str, Any]  # must include {"type": ChartType, "score": float}
    title: str
    x_label: str
    y_label: Optional[str] = ""
    fields_used: List[str]
    plot: PlotSpec
    justification: str

class AnalyzeResponse(BaseModel):
    decision: ChartDecision
    vega_lite: Dict[str, Any]
    warnings: List[str] = []
```

---

## 9) Profiling & Type Inference

**profiling.py**

```python
import pandas as pd
from dateutil.parser import ParserError
from dateutil import parser as dtp

def infer_semantic_type(s: pd.Series) -> str:
    if pd.api.types.is_numeric_dtype(s):
        return "quantitative"
    # try datetime on sample
    sample = s.dropna().astype(str).head(50)
    dt_hits = 0
    for v in sample:
        try:
            dtp.parse(v, fuzzy=False)
            dt_hits += 1
        except (ParserError, ValueError, TypeError):
            pass
    if dt_hits >= max(3, len(sample)//4):
        return "temporal"
    # categorical threshold
    uniq = s.dropna().nunique()
    return "nominal" if uniq <= 50 else "ordinal"

def profile_df(df: pd.DataFrame):
    cols = []
    for name in df.columns:
        s = df[name]
        cols.append({
            "name": name,
            "inferred_type": infer_semantic_type(s),
            "missing": int(s.isna().sum()),
            "unique": int(s.dropna().nunique())
        })
    return {"row_count": int(len(df)), "columns": cols}

def sample_df(df: pd.DataFrame, n: int) -> pd.DataFrame:
    return df.head(n)
```

---

## 10) LLM Call & Prompting

**Behavior:**

* Use `gpt-5-nano` with a strict system prompt; request **only** JSON that fits `ChartDecision`.
* If validation fails, **retry once** with `gpt-5-mini`.
* Allowed chart types in sprint 1: `bar`, `line`, `histogram` (state this in the prompt).

**llm.py (skeleton)**

```python
import os, json, httpx
from typing import Any, Dict

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

SYSTEM_PROMPT = """You output a single JSON object that matches this schema:
ChartDecision = {
  chart: { type: "bar"|"line"|"histogram", score: number (0..1) },
  title: string,
  x_label: string,
  y_label: string,
  fields_used: string[],
  plot: {
    x: { field: string, type: "nominal"|"ordinal"|"quantitative"|"temporal", time_unit?: string, bin?: boolean, aggregate?: string },
    y: { field: string, type: "nominal"|"ordinal"|"quantitative"|"temporal", time_unit?: string, bin?: boolean, aggregate?: string },
    series?: { field: string, type: "nominal"|"ordinal"|"quantitative"|"temporal" }
  },
  justification: string
}
Rules:
- Choose exactly one chart type from: bar, line, histogram.
- Prefer bar for nominal vs numeric comparisons with limited categories.
- Prefer line when x is temporal and y is numeric; set time_unit if needed.
- Prefer histogram for distributions of a single numeric field (set bin=true on the binned channel).
- Return ONLY JSON. No markdown, no commentary.
"""

async def call_llm(model: str, prompt: Dict[str, Any]) -> Dict[str, Any]:
    # Replace with your actual OpenAI client; this shows a generic HTTPX pattern.
    # The important part is: pass system + user content and request JSON-only output.
    headers = {"Authorization": f"Bearer {OPENAI_API_KEY}"}
    payload = {
        "model": model,
        "messages": [
            {"role":"system","content": SYSTEM_PROMPT},
            {"role":"user","content": json.dumps(prompt)}
        ],
        "response_format": {"type": "json_object"}
    }
    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.post("https://api.openai.com/v1/chat/completions", headers=headers, json=payload)
        r.raise_for_status()
        data = r.json()
        raw = data["choices"][0]["message"]["content"]
        return json.loads(raw)
```

**User payload (constructed by backend)**

```json
{
  "allowed_chart_types": ["bar","line","histogram"],
  "columns": [
    {"name":"region","inferred_type":"nominal","missing":0,"unique":8},
    {"name":"sales","inferred_type":"quantitative","missing":3,"unique":740}
  ],
  "row_count": 1200,
  "sample": [
    {"region":"East","sales":120},
    {"region":"West","sales":90}
  ]
}
```

---

## 11) Vega-Lite Assembly

**vega.py**

```python
def decision_to_vegalite(decision_dict: dict) -> dict:
    d = decision_dict
    chart_type = d["chart"]["type"]
    plot = d["plot"]
    base = {
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "title": d["title"],
        "encoding": {},
        "data": {"name": "table"}  # client may bind data later; sprint 1 returns spec only
    }

    def encode_channel(ch):
        enc = {"field": ch["field"], "type": ch["type"]}
        if ch.get("aggregate"): enc["aggregate"] = ch["aggregate"]
        if ch.get("time_unit"): enc["timeUnit"] = ch["time_unit"]
        if ch.get("bin") is True: enc["bin"] = True
        return enc

    if chart_type == "bar":
        base["mark"] = "bar"
        base["encoding"]["x"] = encode_channel(plot["x"])
        base["encoding"]["y"] = encode_channel(plot["y"])
        if plot.get("series"):
            base["encoding"]["color"] = encode_channel(plot["series"])

    elif chart_type == "line":
        base["mark"] = "line"
        base["encoding"]["x"] = encode_channel(plot["x"])
        base["encoding"]["y"] = encode_channel(plot["y"])
        # common line best practice
        base["encoding"]["y"]["scale"] = {"zero": False}
        if plot.get("series"):
            base["encoding"]["color"] = encode_channel(plot["series"])

    elif chart_type == "histogram":
        base["mark"] = "bar"
        # histogram bins on x; y= count
        x = encode_channel(plot["x"])
        if not x.get("bin"): x["bin"] = True
        base["encoding"]["x"] = x
        base["encoding"]["y"] = {"aggregate": "count", "type": "quantitative"}

    else:
        # should not happen in sprint 1 due to prompt restriction
        base["mark"] = "bar"

    return base
```

---

## 12) FastAPI Entry

**app.py**

```python
import io, json, os
import pandas as pd
from fastapi import FastAPI, UploadFile, File, HTTPException, Query
from fastapi.responses import JSONResponse
from pydantic import ValidationError
from dotenv import load_dotenv

from models import AnalyzeResponse, ChartDecision
from profiling import profile_df, sample_df
from llm import call_llm
from vega import decision_to_vegalite

load_dotenv()

MAX_FILE_MB = int(os.getenv("MAX_FILE_MB","10"))
DEFAULT_MODEL = os.getenv("MODEL_DEFAULT","gpt-5-nano")
FALLBACK_MODEL = os.getenv("MODEL_FALLBACK","gpt-5-mini")
DEFAULT_SAMPLE = int(os.getenv("SAMPLE_ROWS","200"))

app = FastAPI(title="Auto Visualization Backend (Sprint 1)")

def _read_df(name: str, content: bytes) -> pd.DataFrame:
    if name.endswith(".csv"):
        return pd.read_csv(io.BytesIO(content))
    if name.endswith(".tsv"):
        return pd.read_csv(io.BytesIO(content), sep="\t")
    if name.endswith(".json"):
        try:
            return pd.read_json(io.BytesIO(content), lines=True)
        except ValueError:
            return pd.read_json(io.BytesIO(content))
    raise HTTPException(status_code=400, detail="Unsupported file type (csv, tsv, json only in sprint 1)")

@app.post("/analyze", response_model=AnalyzeResponse)
async def analyze(
    file: UploadFile = File(...),
    sample_rows: int = Query(DEFAULT_SAMPLE, ge=1, le=2000),
    model: str = Query(DEFAULT_MODEL, pattern="^gpt-5-(nano|mini)$")
):
    try:
        raw = await file.read()
        if len(raw) > MAX_FILE_MB * 1024 * 1024:
            raise HTTPException(status_code=400, detail=f"File too large > {MAX_FILE_MB} MB")
        if not raw:
            raise HTTPException(status_code=400, detail="Empty file")

        df = _read_df(file.filename, raw)

        prof = profile_df(df)
        smpl = sample_df(df, n=sample_rows).to_dict(orient="records")
        prompt = {
            "allowed_chart_types": ["bar","line","histogram"],
            "columns": prof["columns"],
            "row_count": prof["row_count"],
            "sample": smpl
        }

        try:
            llm_out = await call_llm(model=model, prompt=prompt)
        except Exception as e:
            # surface LLM failure clearly
            raise HTTPException(status_code=500, detail=f"LLM call failed: {e}")

        try:
            decision = ChartDecision(**llm_out)
        except ValidationError as ve:
            # fallback once on mini
            if model != FALLBACK_MODEL:
                llm_out = await call_llm(model=FALLBACK_MODEL, prompt=prompt)
                decision = ChartDecision(**llm_out)
            else:
                raise HTTPException(status_code=422, detail=f"Schema validation failed: {ve}")

        vega = decision_to_vegalite(decision.dict())
        resp = AnalyzeResponse(decision=decision, vega_lite=vega, warnings=[])
        return JSONResponse(resp.model_dump())

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

---

## 13) Test Plan (Sprint 1)

**Smoke datasets (`tests/samples/`)**

* `cats_nums.csv`

  ```
  region,sales
  East,120
  West,90
  North,150
  South,80
  ```

  * Expect: `bar` decision.

* `temporal_numeric.csv`

  ```
  date,revenue
  2024-01-01,100
  2024-01-02,102
  2024-01-03,98
  ```

  * Expect: `line` decision; `time_unit` may be omitted for daily.

* `single_numeric.csv`

  ```
  value
  10
  12
  9
  11
  ```

  * Expect: `histogram` decision with `bin=true` on x.

**tests/test_smoke.py (sketch)**

```python
import json, pathlib
from fastapi.testclient import TestClient
from app import app

client = TestClient(app)
samples = pathlib.Path("tests/samples")

def _upload(name):
    p = samples / name
    with p.open("rb") as f:
        return client.post("/analyze", files={"file": (name, f, "text/csv")})

def test_bar():
    r = _upload("cats_nums.csv")
    assert r.status_code == 200
    js = r.json()
    assert js["decision"]["chart"]["type"] == "bar"

def test_line():
    r = _upload("temporal_numeric.csv")
    assert r.status_code == 200
    js = r.json()
    assert js["decision"]["chart"]["type"] == "line"

def test_hist():
    r = _upload("single_numeric.csv")
    assert r.status_code == 200
    js = r.json()
    assert js["decision"]["chart"]["type"] == "histogram"
```

---

## 14) Logging & Error Messages

* Log request start/end with file name and size (omit contents).
* On LLM failure, return `500` with `"LLM call failed: <reason>"`.
* On schema errors, return `422` with `"Schema validation failed: <pydantic message>"`.
* On parsing errors, return `400` with `"Unsupported file type"` or `"Empty file"`.

---

## 15) Performance Targets (Sprint 1)

* Parse + profile + prompt build: **≤ 500 ms** for files ≤ 5 MB.
* LLM latency: uncontrolled; budget **≤ 1.5 s** (nano) typical.
* JSON validation and Vega-Lite assembly: **≤ 50 ms**.

---

## 16) Security & Privacy

* Service binds to `localhost` only.
* Do not persist uploaded files.
* Send only profile + small sample rows to the LLM (no full dataset).
* Never log sample row contents.

---

## 17) Runbook

**Local run**

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # fill OPENAI_API_KEY
uvicorn app:app --reload
```

**Manual smoke test**

```bash
curl -F "file=@tests/samples/cats_nums.csv" http://localhost:8000/analyze | jq .
```

**Common failures**

* `400 Unsupported file type` → ensure extension is csv/tsv/json.
* `422 Schema validation failed` → inspect LLM JSON; confirm prompt strictness.
* `500 LLM call failed` → check API key / network.

---

## 18) Risks & Mitigations

* **LLM returns malformed JSON** → strict `response_format` + fallback to `gpt-5-mini`.
* **Temporal inference false positives** → threshold-based detection using sample window.
* **Large files stall** → cap to 10 MB; sample head(N).
* **Spec rendering mismatch** → keep Sprint 1 spec minimal; verify with online Vega-Lite editor.

---

## 19) Definition of Done (Sprint 1)

* All three smoke tests pass (bar, line, histogram).
* `/analyze` returns a valid Vega-Lite spec for each smoke dataset.
* Clear errors for malformed inputs.
* README includes run instructions and cURL examples.
* Code organized per directory structure; `.env.example` provided.

---

## 20) Post-Sprint Hooks (Parking Lot)

* Enable `column`, `scatter`, `boxplot`, `area`, `pie` with safe rules.
* Add `/render` to accept filters and recompute aggregates without a new LLM call.
* Add Parquet support.
* Return alternates with scores and “why”.
* Basic telemetry counters (local only).

---

**Notes:** Use **Vega-Lite** (not “Vegas”) in code and docs to avoid confusion with schema links.
