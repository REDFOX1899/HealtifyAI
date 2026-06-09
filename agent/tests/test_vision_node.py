import sys
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from nodes.vision_node import parse_vision_response, vision_node  # noqa: E402

VALID_GEMINI_REPLY = (
    '```json\n{"container_type": "bottle", "total_oz": 32, '
    '"pct_remaining": 25, "oz_consumed": 24, "confidence": 0.91}\n```'
)


def test_valid_photo_returns_correct_oz():
    with patch("nodes.vision_node._download_image", return_value=b"fake-jpeg"), patch(
        "nodes.vision_node._call_gemini", return_value=VALID_GEMINI_REPLY
    ):
        state = vision_node({"user_id": "u1", "photo_url": "gs://bucket/photo.jpg"})
    assert state["oz_logged"] == 24
    assert state["ai_confidence"] == 0.91


def test_malformed_gemini_response_falls_back_to_8oz():
    with patch("nodes.vision_node._download_image", return_value=b"fake-jpeg"), patch(
        "nodes.vision_node._call_gemini", return_value="sorry, I can't help with that"
    ):
        state = vision_node({"user_id": "u1", "photo_url": "gs://bucket/photo.jpg"})
    assert state["oz_logged"] == 8
    assert state["ai_confidence"] == 0.3


def test_parse_handles_missing_fields():
    assert parse_vision_response('{"container_type": "mug"}')["oz_consumed"] == 8
    assert parse_vision_response("not json at all")["confidence"] == 0.3
