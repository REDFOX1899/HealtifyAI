"""Shared state passed between LangGraph nodes."""
from typing import Optional, TypedDict


class AgentState(TypedDict, total=False):
    user_id: str
    message: str
    photo_url: Optional[str]
    intent: str  # 'photo' | 'question' | 'checkin'
    oz_logged: float
    ai_confidence: float
    coach_reply: str
    next_reminder: str  # ISO timestamp
    streak_delta: int
    user_context: dict  # {name, streak, oz_today, daily_goal, ...}
