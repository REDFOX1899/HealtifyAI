"""FastAPI wrapper around the HydrateAI LangGraph agent."""
from typing import Optional

from fastapi import FastAPI
from pydantic import BaseModel

from graph import app as agent_graph
from nodes.vision_node import vision_node

api = FastAPI(title="HydrateAI Agent", version="1.0.0")
# Cloud Run / uvicorn entry point: `uvicorn main:api`


class RunRequest(BaseModel):
    user_id: str
    message: str = ""
    photo_url: Optional[str] = None
    user_context: dict = {}


class VerifyPhotoRequest(BaseModel):
    user_id: str
    photo_url: str


@api.get("/healthz")
def healthz():
    return {"status": "ok"}


@api.post("/run")
def run(req: RunRequest):
    result = agent_graph.invoke(req.model_dump())
    return {
        "coach_reply": result.get("coach_reply", ""),
        "oz_logged": result.get("oz_logged", 0),
        "next_reminder": result.get("next_reminder"),
    }


@api.post("/verify-photo")
def verify_photo(req: VerifyPhotoRequest):
    result = vision_node({"user_id": req.user_id, "photo_url": req.photo_url})
    return {
        "oz_consumed": result.get("oz_logged", 0),
        "confidence": result.get("ai_confidence", 0),
    }
