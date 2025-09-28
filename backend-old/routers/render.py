"""Render route to produce Vega-Lite specs."""

from fastapi import APIRouter, Depends

from ..dependencies import get_composer, get_executor
from ..models.render import RenderRequest, RenderResponse
from ..services import Composer, TransformExecutor


router = APIRouter(prefix="/render", tags=["render"])


@router.post("", response_model=RenderResponse)
async def render(
    request: RenderRequest,
    executor: TransformExecutor = Depends(get_executor),
    composer: Composer = Depends(get_composer),
) -> RenderResponse:
    df, meta = executor.execute(
        request.path,
        request.decision,
        filters=request.filters,
        limit_rows=request.limit_rows,
    )
    data_values = df.to_dicts()
    spec = composer.compose(request.decision, data_values)
    return RenderResponse(vega_lite=spec, data=data_values, meta=meta)
