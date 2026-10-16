"""
Server-Driven UI (SDUI) Compiler for Action Buttons & Dynamic Panels.
Compiles user intent and proactive background events into declarative UI contracts.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class ActionButtonContract(BaseModel):
    id: str
    type: str = "action_button"
    headline: str
    verb: str
    accent_hex: str = "#0A84FF"
    target_workflow: str
    payload: Dict[str, Any] = Field(default_factory=dict)
    requires_biometric_auth: bool = True


class PanelWidgetSpec(BaseModel):
    widget_type: str  # "metric_ring", "sparkline", "data_table", "status_card", "interactive_metrics"
    title: str
    data_binding: str
    target_value: Optional[float] = None
    unit: Optional[str] = None
    trend: Optional[str] = None
    color: str = "#0A84FF"


class DynamicPanelContract(BaseModel):
    panel_id: str
    type: str = "dynamic_panel"
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
            id=f"act_bill_{biller.lower().replace(' ', '_')}",
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

    @classmethod
    def compile_for_prompt(cls, prompt: str) -> Dict[str, Any]:
        """Compiles a natural language task prompt into a mobile-ready SDUI contract."""
        lower = prompt.lower()
        if any(k in lower for k in ("flight", "delta", "seat", "check-in", "checkin")):
            return ActionButtonContract(
                id="widget_flight_checkin",
                headline="Delta DL 412 Check-In Ready",
                verb="Confirm Seat 14A",
                accent_hex="#002244",
                target_workflow="delta_checkin_flow",
                payload={"flight": "DL 412", "seat": "14A", "passenger": "Brett"},
                requires_biometric_auth=True,
            ).model_dump()
        if any(k in lower for k in ("bill", "electric", "pge", "pg&e", "pay")):
            return cls.compile_bill_action("PG&E", 84.20, "Tomorrow").model_dump()
        if any(k in lower for k in ("pizza", "food", "doordash", "order")):
            return ActionButtonContract(
                id="widget_doordash_cart",
                headline="Tony's Pizza Napoletana Cart Ready",
                verb="Place Order ($32.50)",
                accent_hex="#FF3008",
                target_workflow="doordash_checkout",
                payload={"restaurant": "Tony's Pizza", "total": 32.50},
                requires_biometric_auth=True,
            ).model_dump()
        if any(k in lower for k in ("nutrition", "health", "panel", "calorie")):
            return cls.compile_panel(
                panel_id="widget_health_panel",
                title="Active Daily Calories",
                widgets=[
                    PanelWidgetSpec(
                        widget_type="interactive_metrics",
                        title="Caloric Target Burn",
                        data_binding="health.calories.active",
                        target_value=2400.0,
                        unit="kcal",
                        trend="+12% vs last week",
                        color="#FF2D55",
                    )
                ],
                sub_agent_prompt=prompt,
                connectors=["apple_health", "strava"],
            ).model_dump()
        return ActionButtonContract(
            id="widget_general_handoff",
            headline="Execute Autonomous Workflow",
            verb="Launch Handoff",
            accent_hex="#00E5FF",
            target_workflow="general_automation",
            payload={"query": prompt},
            requires_biometric_auth=False,
        ).model_dump()
