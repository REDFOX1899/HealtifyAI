import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from graph import build_graph  # noqa: E402
from nodes.scheduler_node import compute_next_reminder, scheduler_node  # noqa: E402

COACH_PATCH = patch("nodes.coach_node._call_gemini", return_value="Great job, Sam!")
SCHED_PATCH = patch("nodes.scheduler_node._load_recent_checkins", return_value=[])


def test_photo_intent_routes_through_vision_node():
    with COACH_PATCH, SCHED_PATCH, patch(
        "nodes.vision_node._download_image", return_value=b"img"
    ), patch(
        "nodes.vision_node._call_gemini",
        return_value='{"oz_consumed": 16, "confidence": 0.8}',
    ) as vision_call:
        result = build_graph().invoke(
            {"user_id": "u1", "message": "", "photo_url": "gs://b/p.jpg"}
        )
    assert vision_call.called
    assert result["intent"] == "photo"
    assert result["oz_logged"] == 16
    assert result["coach_reply"] == "Great job, Sam!"


def test_text_intent_skips_vision_node():
    with COACH_PATCH, SCHED_PATCH, patch(
        "nodes.vision_node._call_gemini"
    ) as vision_call:
        result = build_graph().invoke(
            {"user_id": "u1", "message": "just drank a glass of water"}
        )
    assert not vision_call.called
    assert result["intent"] == "checkin"
    assert "oz_logged" not in result or not result["oz_logged"]


def test_question_intent_classified():
    with COACH_PATCH, SCHED_PATCH:
        result = build_graph().invoke(
            {"user_id": "u1", "message": "how much should I drink today?"}
        )
    assert result["intent"] == "question"


def test_scheduler_always_returns_future_timestamp():
    with SCHED_PATCH:
        state = scheduler_node({"user_id": "u1"})
    assert datetime.fromisoformat(state["next_reminder"]) > datetime.now(timezone.utc)


def test_scheduler_uses_active_hour_pattern():
    now = datetime(2026, 6, 9, 8, 30, tzinfo=timezone.utc)
    checkins = [
        datetime(2026, 6, d, h, 0, tzinfo=timezone.utc)
        for d, h in [(2, 10), (3, 10), (4, 10), (5, 15), (6, 15), (7, 20), (8, 10)]
    ]
    nxt = compute_next_reminder(checkins, now=now)
    assert nxt.hour == 10  # most common active hour still ahead today
    assert nxt > now


def test_scheduler_defaults_to_plus_3_hours_without_pattern():
    now = datetime(2026, 6, 9, 8, 30, tzinfo=timezone.utc)
    assert compute_next_reminder([], now=now) == now + timedelta(hours=3)
