"""Web security scanner module."""

from importlib import import_module
from typing import Any

_MODULE_MAP = {
    "WebCrawler": "modules.webscanner.crawler",
    "XSSScanner": "modules.webscanner.xss_scanner",
    "SQLiScanner": "modules.webscanner.sqli_scanner",
    "DirectoryBruteforcer": "modules.webscanner.dir_bruteforce",
    "SSLAnalyzer": "modules.webscanner.ssl_analyzer",
    "NucleiScanner": "modules.webscanner.nuclei",
}

__all__ = list(_MODULE_MAP)


def __getattr__(name: str) -> Any:
    """Lazily import scanner classes when accessed."""
    if name not in _MODULE_MAP:
        raise AttributeError(f"module {__name__!r} has no attribute {name!r}")

    module = import_module(_MODULE_MAP[name])
    return getattr(module, name)
