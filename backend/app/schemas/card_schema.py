from __future__ import annotations

from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field


ArtifactType = Literal[
    "interactive_html",
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


class PracticePaperSourceError(BaseModel):
    id: str
    subject: str = ""
    topic: str = ""
    question: str = ""
    reason: str = ""
    tags: List[str] = Field(default_factory=list)
    my_answer: str = ""
    ai_analysis: str = ""


class PracticePaperRequest(BaseModel):
    errors: List[PracticePaperSourceError] = Field(default_factory=list)
    question_count: int = Field(default=10, ge=3, le=50)
    selected_subjects: List[str] = Field(default_factory=list)
    strategy_label: str = "薄弱点突破"
    include_answer_key: bool = True


class PracticeQuestion(BaseModel):
    id: str
    type: str = "简答题"
    subject: str = ""
    topic: str = ""
    stem: str
    options: List[str] = Field(default_factory=list)
    answer: str
    answer_index: Optional[int] = None
    solution_outline: str = ""
    reason_hint: str = ""
    difficulty: str = "中等"
    estimated_minutes: int = Field(default=4, ge=1, le=30)
    source_error_ids: List[str] = Field(default_factory=list)


class PracticePaperResponse(BaseModel):
    title: str
    subtitle: str = ""
    subject_focus: List[str] = Field(default_factory=list)
    topic_focus: List[str] = Field(default_factory=list)
    strategy_label: str
    estimated_minutes: int = Field(default=20, ge=1)
    handout_overview: str
    learning_targets: List[str] = Field(default_factory=list)
    warmup_notes: List[str] = Field(default_factory=list)
    questions: List[PracticeQuestion] = Field(default_factory=list)
    answer_key: List[str] = Field(default_factory=list)
    printable_html: str = ""
    raw_model_output: str = ""
