"""LangGraph wiring: intake → (vision if photo) → coach → scheduler."""
from langgraph.graph import END, StateGraph

from nodes.coach_node import coach_node
from nodes.intake_node import intake_node
from nodes.scheduler_node import scheduler_node
from nodes.vision_node import vision_node
from state import AgentState


def route_after_intake(state: AgentState) -> str:
    return "vision" if state.get("intent") == "photo" else "coach"


def build_graph():
    graph = StateGraph(AgentState)
    graph.add_node("intake", intake_node)
    graph.add_node("vision", vision_node)
    graph.add_node("coach", coach_node)
    graph.add_node("scheduler", scheduler_node)

    graph.set_entry_point("intake")
    graph.add_conditional_edges(
        "intake", route_after_intake, {"vision": "vision", "coach": "coach"}
    )
    graph.add_edge("vision", "coach")
    graph.add_edge("coach", "scheduler")
    graph.add_edge("scheduler", END)
    return graph.compile()


app = build_graph()
