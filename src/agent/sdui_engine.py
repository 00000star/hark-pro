"""
Server-Driven UI (SDUI) Compiler for Action Buttons & Dynamic Panels.
Compiles user intent and proactive background events into declarative UI contracts.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class ActionButtonContract(BaseModel):
    id: str
    headline: str
    verb: str
    accent_hex: str = "#0A84FF"
    target_workflow: str
    payload: Dict[str, Any]
    requires_biometric_auth: bool = True


class PanelWidgetSpec(BaseModel):
    widget_type: str  # "metric_ring", "sparkline", "data_table", "status_card"
    title: str
    data_binding: str
    target_value: Optional[float] = None
    unit: Optional[str] = None
    color: str = "#0A84FF"


class DynamicPanelContract(BaseModel):
    panel_id: str
    title: str
    refresh_cron: str
    connectors_required: List[str]
    layout: Dict[str, Any]
    widgets: List[PanelWidgetSpec]
    scoped_agent_prompt: str


class SDUICompiler:
    """
    Translates unstructured proactive events and user prompts into structured
    declarative contracts consumed by the mobile client renderer.
    """

    @staticmethod
    def compile_bill_action(biller: str, amount: float, due_date: str) -> ActionButtonContract:
        return ActionButtonContract(
            id=f"act_bill_{biller.lower()}",
            headline=f"{biller} Payment Due ({due_date})",
            verb=f"Pay ${amount:.2f}",
            target_workflow="automated_bill_payment",
            payload={
                "biller": biller,
                "amount": amount,
                "workflow_handler": "handoff",
            },
            requires_biometric_auth=True,
        )

    @staticmethod
    def compile_panel(
        panel_id: str,
        title: str,
        widgets: List[PanelWidgetSpec],
        sub_agent_prompt: str,
        connectors: Optional[List[str]] = None,
    ) -> DynamicPanelContract:
        return DynamicPanelContract(
            panel_id=panel_id,
            title=title,
            refresh_cron="0 */4 * * *",
            connectors_required=connectors or [],
            layout={"type": "grid", "columns": len(widgets)},
            widgets=widgets,
            scoped_agent_prompt=sub_agent_prompt,
        )
