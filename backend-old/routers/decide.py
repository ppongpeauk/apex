"""Decide route to obtain chart decisions."""

from fastapi import APIRouter, Depends

from ..dependencies import get_decider
from ..models.decide import DecideRequest, DecideResponse
from ..services import LLMDecider


router = APIRouter(prefix="/decide", tags=["decide"])


@router.post("", response_model=DecideResponse)
async def decide(
    request: DecideRequest,
    decider: LLMDecider = Depends(get_decider),
) -> DecideResponse:
    payload = request.model_dump()
    decision = await decider.decide(payload, prefer_model=request.prefer_model)
    return DecideResponse(decision=decision)
