"""Base class for OSINT modules."""

from abc import ABC, abstractmethod
from typing import Any

from core.models import Target, ScanResult
from core.logger import get_logger


class OSINTModule(ABC):
    """Abstract base class for OSINT modules."""

    name: str = "base"
    description: str = "Base OSINT module"

    def __init__(self):
        self.logger = get_logger(f"osint.{self.name}")

    @abstractmethod
    async def run(self, target: Target) -> ScanResult:
        """Execute the OSINT module against a target.

        Args:
            target: The target to investigate

        Returns:
            ScanResult containing findings
        """
        pass

    def create_result(self, target: Target) -> ScanResult:
        """Create a new ScanResult for this module."""
        return ScanResult(target=target, module=f"osint.{self.name}")
