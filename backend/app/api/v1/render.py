from __future__ import annotations

from typing import Any, Dict, Literal
from urllib.parse import urlparse

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from backend.app.rendering.geogebra_renderer import build_geogebra_scene
from backend.app.services.render_jobs import (
    create_manim_job,
    discard_manim_artifacts,
    get_manim_job,
    retain_manim_artifacts,
)


router = APIRouter(prefix="/api/v1/render", tags=["render"])


class RenderSceneRequest(BaseModel):
    scene_spec: Dict[str, Any] = Field(default_factory=dict)


class ManimArtifactLifecycleRequest(BaseModel):
    job_ids: list[str] = Field(default_factory=list)
    video_urls: list[str] = Field(default_factory=list)


class ManimArtifactLifecycleResponse(BaseModel):
    retained: int = 0
    deleted: int = 0
    deferred: int = 0
    job_ids: list[str] = Field(default_factory=list)


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
    absolute_video_url: str = ""
    updated_at: float | None = None
    diagnostics: Dict[str, Any] = Field(default_factory=dict)


@router.post("/geogebra", response_model=GeoGebraRenderResponse)
def render_geogebra(request: RenderSceneRequest) -> GeoGebraRenderResponse:
    payload = build_geogebra_scene(request.scene_spec)
    return GeoGebraRenderResponse(content=payload)


@router.post("/manim", response_model=ManimJobResponse)
def create_manim_render_job(
    request: Request,
    payload: RenderSceneRequest,
) -> ManimJobResponse:
    job = create_manim_job(payload.scene_spec)
    return _job_response(job, request)


@router.post("/manim/jobs/retain", response_model=ManimArtifactLifecycleResponse)
def retain_manim_render_artifacts(
    payload: ManimArtifactLifecycleRequest,
) -> ManimArtifactLifecycleResponse:
    result = retain_manim_artifacts(
        job_ids=payload.job_ids,
        video_urls=payload.video_urls,
    )
    return ManimArtifactLifecycleResponse(
        retained=int(result.get("retained") or 0),
        job_ids=list(result.get("job_ids") or []),
    )


@router.post("/manim/jobs/cleanup", response_model=ManimArtifactLifecycleResponse)
def cleanup_manim_render_artifacts(
    payload: ManimArtifactLifecycleRequest,
) -> ManimArtifactLifecycleResponse:
    result = discard_manim_artifacts(
        job_ids=payload.job_ids,
        video_urls=payload.video_urls,
    )
    return ManimArtifactLifecycleResponse(
        deleted=int(result.get("deleted") or 0),
        deferred=int(result.get("deferred") or 0),
        job_ids=list(result.get("job_ids") or []),
    )


@router.get("/manim/{job_id}", response_model=ManimJobResponse)
def get_manim_render_job(job_id: str, request: Request) -> ManimJobResponse:
    job = get_manim_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Manim job not found.")
    return _job_response(job, request)


def _job_response(job: Dict[str, Any], request: Request) -> ManimJobResponse:
    video_url = str(job.get("video_url") or "")
    return ManimJobResponse(
        job_id=str(job.get("job_id") or ""),
        status=str(job.get("status") or "pending"),  # type: ignore[arg-type]
        progress=int(job.get("progress") or 0),
        video_url=video_url,
        duration=job.get("duration"),
        thumbnail_url=job.get("thumbnail_url"),
        message=str(job.get("message") or ""),
        error=str(job.get("error") or ""),
        absolute_video_url=_absolute_url(request, video_url),
        updated_at=job.get("updated_at"),
        diagnostics=job.get("diagnostics")
        if isinstance(job.get("diagnostics"), dict)
        else {},
    )


def _absolute_url(request: Request, video_url: str) -> str:
    if not video_url:
        return ""
    if _is_absolute_http_url(video_url):
        return video_url
    return f"{str(request.base_url).rstrip('/')}/{video_url.lstrip('/')}"


def _is_absolute_http_url(value: str) -> bool:
    parsed = urlparse(value)
    return parsed.scheme in {"http", "https"} and bool(parsed.netloc)
