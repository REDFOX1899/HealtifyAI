"""Rule-based adaptive reminder scheduler.

Looks at the user's last 7 check-in timestamps, finds their most common
active hours, and schedules the next reminder at the next active hour.
Falls back to +3 hours when there's no pattern yet.
"""
from collections import Counter
from datetime import datetime, timedelta, timezone

from state import AgentState


def _load_recent_checkins(user_id: str) -> list:
    """Fetch the user's last 7 check-in timestamps from Firestore."""
    from google.cloud import firestore

    db = firestore.Client()
    docs = (
        db.collection("users")
        .document(user_id)
        .collection("messages")
        .where("sender", "==", "user")
        .order_by("timestamp", direction=firestore.Query.DESCENDING)
        .limit(7)
        .stream()
    )
    return [d.to_dict()["timestamp"] for d in docs if d.to_dict().get("timestamp")]


def compute_next_reminder(checkins: list, now: datetime | None = None) -> datetime:
    now = now or datetime.now(timezone.utc)
    hours = [ts.hour for ts in checkins if hasattr(ts, "hour")]
    if len(hours) < 3:
        return now + timedelta(hours=3)

    active_hours = sorted(h for h, _ in Counter(hours).most_common(3))
    for hour in active_hours:
        candidate = now.replace(minute=0, second=0, microsecond=0).replace(hour=hour)
        if candidate > now:
            return candidate
    # All active hours have passed today — use the earliest one tomorrow.
    return (now + timedelta(days=1)).replace(
        hour=active_hours[0], minute=0, second=0, microsecond=0
    )


def scheduler_node(state: AgentState) -> AgentState:
    try:
        checkins = _load_recent_checkins(state["user_id"])
    except Exception:
        checkins = []
    next_reminder = compute_next_reminder(checkins)
    return {**state, "next_reminder": next_reminder.isoformat()}
