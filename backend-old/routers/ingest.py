"""Ingest route for dataset profiling."""

from fastapi import APIRouter, Depends

from ..dependencies import get_profiler
from ..models import IngestRequest, IngestResponse
from ..services import DataProfiler


router = APIRouter(prefix="/ingest", tags=["ingest"])


@router.post("", response_model=IngestResponse)
async def ingest(
    request: IngestRequest,
    profiler: DataProfiler = Depends(get_profiler),
) -> IngestResponse:
    return profiler.profile(request)
