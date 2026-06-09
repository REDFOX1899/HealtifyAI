"""Classify the user's intent: photo check-in, question, or text check-in."""
from state import AgentState

QUESTION_KEYWORDS = (
    "how", "what", "when", "why", "where", "who", "can i", "should i",
    "is it", "do i", "does", "am i",
)


def intake_node(state: AgentState) -> AgentState:
    if state.get("photo_url"):
        intent = "photo"
    else:
        message = (state.get("message") or "").strip().lower()
        if "?" in message or any(message.startswith(k) for k in QUESTION_KEYWORDS):
            intent = "question"
        else:
            intent = "checkin"
    return {**state, "intent": intent}
