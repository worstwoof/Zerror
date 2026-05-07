from __future__ import annotations

from typing import Any, Dict, Literal

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from backend.app.rendering.geogebra_renderer import build_geogebra_scene
from backend.app.services.render_jobs import create_manim_job, get_manim_job


router = APIRouter(prefix="/api/v1/render", tags=["render"])


class RenderSceneRequest(BaseModel):
    scene_spec: Dict[str, Any] = Field(default_factory=dict)


class GeoGebraRenderResponse(BaseModel):
    artifact_type: Literal["geogebra_scene"] = "geogebra_scene"
    title: str = "GeoGebra 交互图"
    mime_type: str = "application/json"
    content: Dict[str, Any]


class ManimJobResponse(BaseModel):
    job_id: str
    status: Literal["pending", "running", "succeeded", "failed"]
    progress: int = Field(default=0, ge=0, le=100)
    video_url: str = ""
    duration: float | None = None
    thumbnail_url: str | None = None
    message: str = ""
    error: str = ""


@router.post("/geogebra", response_model=GeoGebraRenderResponse)
def render_geogebra(request: RenderSceneRequest) -> GeoGebraRenderResponse:
    payload = build_geogebra_scene(request.scene_spec)
    return GeoGebraRenderResponse(content=payload)


@router.post("/manim", response_model=ManimJobResponse)
def create_manim_render_job(request: RenderSceneRequest) -> ManimJobResponse:
    job = create_manim_job(request.scene_spec)
    return _job_response(job)


@router.get("/manim/{job_id}", response_model=ManimJobResponse)
def get_manim_render_job(job_id: str) -> ManimJobResponse:
    job = get_manim_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Manim job not found.")
    return _job_response(job)


def _job_response(job: Dict[str, Any]) -> ManimJobResponse:
    return ManimJobResponse(
        job_id=str(job.get("job_id") or ""),
        status=str(job.get("status") or "pending"),  # type: ignore[arg-type]
        progress=int(job.get("progress") or 0),
        video_url=str(job.get("video_url") or ""),
        duration=job.get("duration"),
        thumbnail_url=job.get("thumbnail_url"),
        message=str(job.get("message") or ""),
        error=str(job.get("error") or ""),
    )

