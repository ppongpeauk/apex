# Backend Sprint 1

Implements the FastAPI backend described in the Sprint 1 PRD. Provides a single `/analyze` endpoint to upload a dataset, profile the columns, call an LLM to select an appropriate chart, and return a Vega-Lite specification.

## Setup

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Configuration

The LLM service is configured in `llm.py`. By default, it's set up for Ollama with gemma3:1b:

```python
LLM_BASE_URL = "http://localhost:11434/v1"  # Ollama local API
LLM_API_KEY = "ollama"  # Dummy key for local Ollama
LLM_MODEL = "gemma3:1b"  # Model to use
```

To use OpenAI instead, uncomment and modify these lines:

```python
# LLM_BASE_URL = "https://api.openai.com/v1"
# LLM_API_KEY = os.getenv("OPENAI_API_KEY")  # Use the real key from .env
# LLM_MODEL = "gpt-5-nano"
```

## Run

```bash
uvicorn app:app --reload
```

## Smoke Test

```bash
curl -F "file=@tests/samples/cats_nums.csv" "http://localhost:8000/analyze?sample_rows=200" | jq .
```

## Data Processing

The backend automatically converts all ingested data to Parquet format for improved performance:

- **Supported formats**: CSV, TSV, JSON, Parquet
- **Automatic conversion**: Non-Parquet files are converted to Parquet format
- **Benefits**: Better type inference, compression, and columnar storage
- **Caching**: Parquet data is cached for instant retrieval on subsequent requests

## Caching

The backend includes SQLite-based caching for improved performance:

- **Cache Hit**: If the same file is uploaded again, the cached Vega-Lite output is returned instantly
- **Cache Miss**: The system processes the file, calls the LLM, and caches the result
- **Cache Management**: Use the cache management endpoints to inspect and clear the cache

### Cache Endpoints

- `GET /cache/stats` - Get cache statistics (total entries, cache file location)
- `DELETE /cache/clear` - Clear all cached entries

### Cache Performance

- First request: ~4-5 seconds (LLM call)
- Subsequent requests for same file: ~0.7 seconds (cache hit)
- Cache is stored in `cache.db` in the backend directory

