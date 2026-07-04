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
    solution_steps: List[str] = Field(default_factory=list)
    diagram_svg: str = ""
    diagram_caption: str = ""
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
    concept_review: List[str] = Field(default_factory=list)
    formula_cards: List[str] = Field(default_factory=list)
    method_models: List[str] = Field(default_factory=list)
    worked_examples: List[str] = Field(default_factory=list)
    common_traps: List[str] = Field(default_factory=list)
    questions: List[PracticeQuestion] = Field(default_factory=list)
    answer_key: List[str] = Field(default_factory=list)
    printable_html: str = ""
    raw_model_output: str = ""


class LectureHandoutRequest(BaseModel):
    prompt: str = Field(..., min_length=1)
    subject: str = ""
    topic: str = ""
    client_job_id: str = ""


class LectureHandoutSection(BaseModel):
    title: str
    body: str = ""
    bullets: List[str] = Field(default_factory=list)


class LectureHandoutExample(BaseModel):
    title: str = ""
    source: str = ""
    stem: str = ""
    answer: str = ""
    analysis: str = ""
    solution_steps: List[str] = Field(default_factory=list)
    notes: List[str] = Field(default_factory=list)


class LectureHandoutModelCard(BaseModel):
    title: str
    feature: str = ""
    logic: str = ""
    procedure: List[str] = Field(default_factory=list)
    secondary_conclusions: List[str] = Field(default_factory=list)
    examples: List[LectureHandoutExample] = Field(default_factory=list)
    notes: List[str] = Field(default_factory=list)
    traps: List[str] = Field(default_factory=list)


class LectureHandoutSummaryTable(BaseModel):
    title: str = ""
    headers: List[str] = Field(default_factory=list)
    rows: List[List[str]] = Field(default_factory=list)


class LectureHandoutResponse(BaseModel):
    title: str
    subtitle: str = ""
    subject: str = ""
    topic: str = ""
    overview: str = ""
    exam_analysis: str = ""
    knowledge_map: List[str] = Field(default_factory=list)
    sections: List[LectureHandoutSection] = Field(default_factory=list)
    model_cards: List[LectureHandoutModelCard] = Field(default_factory=list)
    secondary_conclusions: List[str] = Field(default_factory=list)
    example_walkthroughs: List[LectureHandoutExample] = Field(default_factory=list)
    summary_tables: List[LectureHandoutSummaryTable] = Field(default_factory=list)
    key_points: List[str] = Field(default_factory=list)
    formula_cards: List[str] = Field(default_factory=list)
    method_notes: List[str] = Field(default_factory=list)
    common_traps: List[str] = Field(default_factory=list)
    recap_checklist: List[str] = Field(default_factory=list)
    printable_html: str = ""
    raw_model_output: str = ""


LectureHandoutJobStatus = Literal["pending", "processing", "completed", "failed"]


class LectureHandoutJobResponse(BaseModel):
    job_id: str
    status: LectureHandoutJobStatus
    progress: int = Field(default=0, ge=0, le=100)
    message: str = ""
    error: str = ""
    created_at: float
    updated_at: float
    result: Optional[LectureHandoutResponse] = None


AssistantMode = Literal[
    "quick_answer",
    "error_memory",
    "knowledge_link",
    "exam_sprint",
]


class AssistantMemoryContext(BaseModel):
    total_errors: int = 0
    pending_review_count: int = 0
    mastered_count: int = 0
    weakest_subject: str = ""
    weakest_topic: str = ""
    weakest_subject_pending_count: int = 0
    weakest_topic_pending_count: int = 0
    subject_distribution: Dict[str, int] = Field(default_factory=dict)


class AssistantChatRequest(BaseModel):
    message: str = Field(..., min_length=1)
    mode: AssistantMode = "quick_answer"
    context: AssistantMemoryContext = Field(default_factory=AssistantMemoryContext)
    errors: List[PracticePaperSourceError] = Field(default_factory=list)


class AssistantChatSection(BaseModel):
    title: str
    body: str = ""
    bullets: List[str] = Field(default_factory=list)


class AssistantChatResponse(BaseModel):
    mode: AssistantMode
    title: str
    summary: str
    sections: List[AssistantChatSection] = Field(default_factory=list)
    linked_knowledge: List[str] = Field(default_factory=list)
    follow_up_prompts: List[str] = Field(default_factory=list)
    sprint_minutes: int = Field(default=0, ge=0, le=180)
    fallback: bool = False
    raw_model_output: str = ""
