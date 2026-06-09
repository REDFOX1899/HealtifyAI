"""Generate a short, warm coach reply with Gemini."""
import os

from state import AgentState

SYSTEM_PROMPT = (
    "You are a friendly, encouraging ADHD hydration coach. "
    "Be brief (2-3 sentences max). Reference their streak. Never shame. "
    "Use their first name. Celebrate wins warmly."
)


def _call_gemini(prompt: str) -> str:
    import google.generativeai as genai

    genai.configure(api_key=os.environ["GEMINI_API_KEY"])
    model = genai.GenerativeModel(
        "gemini-2.0-flash", system_instruction=SYSTEM_PROMPT
    )
    return model.generate_content(prompt).text.strip()


def build_user_prompt(state: AgentState) -> str:
    ctx = state.get("user_context", {})
    parts = [
        f"User name: {ctx.get('name', 'friend')}",
        f"Current streak: {ctx.get('streak', 0)} days",
        f"Oz logged today: {ctx.get('oz_today', 0)}",
        f"Daily goal: {ctx.get('daily_goal', 64)} oz",
    ]
    if state.get("oz_logged"):
        parts.append(f"They just logged: {state['oz_logged']} oz")
    if state.get("message"):
        parts.append(f"Their message: {state['message']}")
    return "\n".join(parts)


def coach_node(state: AgentState) -> AgentState:
    try:
        reply = _call_gemini(build_user_prompt(state))
    except Exception:
        name = state.get("user_context", {}).get("name", "friend")
        reply = f"Nice check-in, {name}! Every sip counts — keep that streak alive. 💧"
    return {**state, "coach_reply": reply}
