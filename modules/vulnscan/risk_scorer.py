"""Risk scoring for vulnerability scan findings."""

from __future__ import annotations

_SEVERITY_WEIGHTS = {"CRITICAL": 10, "HIGH": 7, "MEDIUM": 4, "LOW": 2, "UNKNOWN": 1}

SEVERITY_COLOR = {
    "CRITICAL": "bold red",
    "HIGH": "red",
    "MEDIUM": "yellow",
    "LOW": "green",
    "MINIMAL": "dim green",
    "NONE": "dim",
    "UNKNOWN": "dim",
}


def calculate_risk_score(cve_details: list[dict]) -> tuple[int, str]:
    """
    Calculate an absolute risk score (0–100) from a list of CVE dicts.

    Uses absolute weight accumulation (not ratio-based) so that having
    more CVEs always increases the score rather than normalizing it away.

    10 CRITICAL = 100 (cap). Each additional CVE contributes up to that cap.
    """
    if not cve_details:
        return 0, "NONE"

    total = sum(
        _SEVERITY_WEIGHTS.get(c.get("severity", "UNKNOWN"), 1)
        for c in cve_details
    )
    score = min(int(total * 10), 100)

    if score >= 80:
        level = "CRITICAL"
    elif score >= 60:
        level = "HIGH"
    elif score >= 40:
        level = "MEDIUM"
    elif score >= 20:
        level = "LOW"
    else:
        level = "MINIMAL"

    return score, level


class RiskScorer:
    """Stateless risk scoring helper."""

    @staticmethod
    def score(cve_details: list[dict]) -> tuple[int, str]:
        return calculate_risk_score(cve_details)

    @staticmethod
    def color(level: str) -> str:
        return SEVERITY_COLOR.get(level.upper(), "white")
