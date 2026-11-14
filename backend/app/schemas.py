from datetime import date, datetime
from typing import Literal
from uuid import UUID
from zoneinfo import ZoneInfo

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class Data(BaseModel):
    model_config = ConfigDict(extra="forbid")


class TaskData(Data):
    title: str = Field(min_length=1, max_length=500)
    notes: str = Field(default="", max_length=10000)
    parent_id: UUID | None = None
    order: int = Field(default=0, ge=0)
    is_done: bool = False
    due: datetime | None = None
    priority: Literal["low", "medium", "high"] = "medium"
    category: Literal["study", "work", "personal", "health", "finance", "home", "other"] = "study"
    estimated_minutes: int = Field(default=30, ge=1, le=10080)
    focus_minutes: int = Field(default=25, ge=5, le=90)
    break_minutes: int = Field(default=5, ge=0, le=30)
    remind: bool = False
    repeat_rule: Literal["none", "daily", "weekly"] = "none"
    is_stuck: bool = False
    @field_validator("due")
    @classmethod
    def aware(cls, value):
        if value is not None and value.tzinfo is None:
            raise ValueError("due requires timezone")
        return value


class ContextData(Data):
    text: str = Field(min_length=1, max_length=2000)
    source: Literal["user", "handoff", "assumption"] = "user"
    confirmed: bool = True
    scope: Literal["personal", "goal", "day", "conversation"] = "personal"
    scope_id: str | None = Field(default=None, max_length=100)
    valid_until: datetime | None = None
    @model_validator(mode="after")
    def valid_scope(self):
        if self.scope != "personal" and not self.scope_id:
            raise ValueError("scope_id required")
        if self.valid_until and self.valid_until.tzinfo is None:
            raise ValueError("valid_until requires timezone")
        return self


class ProfileData(Data):
    language: Literal["vi", "en"] = "vi"
    timezone: str = "Asia/Bangkok"
    @field_validator("timezone")
    @classmethod
    def zone(cls, value):
        try:
            ZoneInfo(value)
        except (KeyError, ValueError):
            raise ValueError("invalid timezone") from None
        return value


class Window(Data):
    start: int = Field(ge=0, lt=1440)
    end: int = Field(gt=0, le=1440)
    @model_validator(mode="after")
    def ordered(self):
        if self.end <= self.start:
            raise ValueError("window end must follow start")
        return self


class Day(Data):
    windows: list[Window] = Field(default_factory=list, max_length=8)
    commitment: int = Field(default=60, ge=0, le=1440)
    @model_validator(mode="after")
    def separate(self):
        ordered = sorted(self.windows, key=lambda w: w.start)
        if any(a.end > b.start for a, b in zip(ordered, ordered[1:])):
            raise ValueError("overlapping windows")
        return self


class WeekData(Data):
    # Monday = 0, Sunday = 6, unlike Foundation's weekday numbering.
    days: list[Day] = Field(min_length=7, max_length=7)


class CommitmentData(Data):
    day: date
    minutes: int = Field(ge=0, le=1440)


class FocusData(Data):
    task_id: UUID | None = None
    planned_id: UUID | None = None
    task_title: str = Field(max_length=500)
    started_at: datetime
    finished_at: datetime | None = None
    focus_seconds: int = Field(ge=0, le=86400)
    outcome: Literal["done", "more_time", "stuck", "ended"] = "ended"
    @model_validator(mode="after")
    def times(self):
        for value in (self.started_at, self.finished_at):
            if value and value.tzinfo is None:
                raise ValueError("timezone required")
        if self.finished_at and self.finished_at < self.started_at:
            raise ValueError("invalid interval")
        if self.finished_at and self.focus_seconds > (self.finished_at-self.started_at).total_seconds()+2:
            raise ValueError("focus exceeds elapsed time")
        return self


KINDS = {"task": TaskData, "context": ContextData, "profile": ProfileData,
         "week": WeekData, "commitment": CommitmentData, "focus": FocusData}


class Operation(Data):
    operation_id: UUID
    entity_type: Literal["task", "context", "profile", "week", "commitment", "focus"]
    entity_id: UUID
    action: Literal["upsert", "delete"]
    expected_version: int = Field(ge=0)
    payload: dict = Field(default_factory=dict)


class Push(Data):
    operations: list[Operation] = Field(max_length=100)


class MessageInput(Data):
    text: str = Field(default="", max_length=12000)
    force_proposal: bool = False
    draft: dict | None = None


class Step(Data):
    title: str = Field(min_length=1, max_length=500)
    estimated_minutes: int = Field(ge=1, le=480)
    focus_minutes: int = Field(default=25, ge=5, le=90)
    break_minutes: int = Field(default=5, ge=0, le=30)


class ContextUpdate(Data):
    text: str = Field(min_length=1, max_length=2000)
    evidence: str = Field(min_length=1, max_length=2000)
    scope: Literal["personal", "day", "conversation"] = "conversation"


class PlanTurn(Data):
    type: Literal["question", "plan"]
    message: str = Field(max_length=4000)
    quick_replies: list[str] = Field(default_factory=list, max_length=4)
    title: str = Field(default="", max_length=500)
    steps: list[Step] = Field(default_factory=list, max_length=12)
    later: list[str] = Field(default_factory=list, max_length=12)
    based_on: list[str] = Field(default_factory=list, max_length=12)
    assumptions: list[str] = Field(default_factory=list, max_length=12)
    context_updates: list[ContextUpdate] = Field(default_factory=list, max_length=8)
    @model_validator(mode="after")
    def meaningful(self):
        if self.type == "plan" and not self.steps:
            raise ValueError("plan needs steps")
        return self
