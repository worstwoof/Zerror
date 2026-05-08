from __future__ import annotations

from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field


ArtifactType = Literal[
    "interactive_html",
    "physics_scene_spec",
    "geogebra_scene",
    "manim_job",
    "manim_video",
    "text_explanation",
    "image_analysis",
    "chart_spec",
    "code_snippet",
    "study_card",
    "timeline",
]


class ReviewPlan(BaseModel):
    next_review_in_days: int = Field(..., ge=0)
    focus: str
    schedule: List[int] = Field(default_factory=list)


class SimilarQuestion(BaseModel):
    prompt: str
    answer_outline: str = ""


class RichArtifact(BaseModel):
    artifact_type: ArtifactType
    title: str
    description: str
    mime_type: str = "text/plain"
    content: str


class AnalysisRequest(BaseModel):
    question_text: str = Field(..., min_length=1)
    subject: str = Field(default="通用")
    user_answer: str = ""
    wrong_reason_hint: str = ""
    enable_subject_extensions: bool = True


class AnalysisResponse(BaseModel):
    question_text: str
    cleaned_question: str
    scene_brief: str = ""
    subject: str
    knowledge_points: List[str] = Field(default_factory=list)
    solution_summary: str
    solution_steps: List[str] = Field(default_factory=list)
    mistake_diagnosis: str
    review_plan: ReviewPlan
    similar_questions: List[SimilarQuestion] = Field(default_factory=list)
    rich_artifacts: List[RichArtifact] = Field(default_factory=list)
    source: Literal["text", "image"] = "text"
    raw_model_output: str = ""


class OCRResponse(BaseModel):
    raw_text: str
    normalized_text: str
    blocks: List[Dict[str, Any]] = Field(default_factory=list)


class ImageAnalysisResponse(AnalysisResponse):
    ocr: OCRResponse


AnalysisJobStatus = Literal[
    "pending",
    "processing",
    "partial_success",
    "completed",
    "failed",
    "need_retry",
]


class ImageAnalysisJobResponse(BaseModel):
    job_id: str
    status: AnalysisJobStatus
    progress: int = Field(default=0, ge=0, le=100)
    message: str = ""
    error: str = ""
    created_at: float
    updated_at: float
    ocr: Optional[OCRResponse] = None
    result: Optional[ImageAnalysisResponse] = None
    partial_result: Optional[ImageAnalysisResponse] = None


class PhysicsAnimationRequest(BaseModel):
    cleaned_question: str = Field(..., min_length=1)
    scene_brief: str = ""
    subject: str = Field(default="物理")
    knowledge_points: List[str] = Field(default_factory=list)
    solution_summary: str = ""
    solution_steps: List[str] = Field(default_factory=list)


class PhysicsAnimationResponse(BaseModel):
    subject: str
    artifact: Optional[RichArtifact] = None
    generated: bool = False
    reason: str = ""
