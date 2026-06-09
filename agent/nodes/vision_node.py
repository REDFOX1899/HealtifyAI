"""Verify a hydration photo with Gemini Vision and estimate ounces consumed."""
import json
import os
import re

from state import AgentState

VISION_PROMPT = (
    "Analyze this hydration container. Return JSON only: "
    '{"container_type": string, "total_oz": number, "pct_remaining": number, '
    '"oz_consumed": number, "confidence": number between 0 and 1}'
)

FALLBACK = {"oz_consumed": 8, "confidence": 0.3, "container_type": "unknown"}


def _download_image(photo_url: str) -> bytes:
    """Download image bytes from a GCS URL (gs:// or https firebase storage)."""
    if photo_url.startswith("gs://"):
        from google.cloud import storage

        bucket_name, _, blob_path = photo_url[len("gs://"):].partition("/")
        client = storage.Client()
        return client.bucket(bucket_name).blob(blob_path).download_as_bytes()
    import urllib.request

    with urllib.request.urlopen(photo_url) as resp:  # noqa: S310 - trusted GCS URL
        return resp.read()


def _call_gemini(image_bytes: bytes) -> str:
    import google.generativeai as genai

    genai.configure(api_key=os.environ["GEMINI_API_KEY"])
    model = genai.GenerativeModel("gemini-2.0-flash")
    response = model.generate_content(
        [VISION_PROMPT, {"mime_type": "image/jpeg", "data": image_bytes}]
    )
    return response.text


def parse_vision_response(text: str) -> dict:
    """Parse Gemini's JSON reply; fall back to a safe default on any error."""
    try:
        # Strip markdown fences if present and grab the first JSON object.
        match = re.search(r"\{.*\}", text, re.DOTALL)
        data = json.loads(match.group(0)) if match else {}
        return {
            "oz_consumed": float(data["oz_consumed"]),
            "confidence": float(data.get("confidence", 0.5)),
            "container_type": str(data.get("container_type", "unknown")),
        }
    except (ValueError, KeyError, TypeError, AttributeError):
        return dict(FALLBACK)


def vision_node(state: AgentState) -> AgentState:
    try:
        image_bytes = _download_image(state["photo_url"])
        result = parse_vision_response(_call_gemini(image_bytes))
    except Exception:
        result = dict(FALLBACK)
    return {
        **state,
        "oz_logged": result["oz_consumed"],
        "ai_confidence": result["confidence"],
    }
