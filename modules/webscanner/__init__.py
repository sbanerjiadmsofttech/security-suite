"""Web security scanner module."""

from modules.webscanner.crawler import WebCrawler
from modules.webscanner.xss_scanner import XSSScanner
from modules.webscanner.sqli_scanner import SQLiScanner
from modules.webscanner.dir_bruteforce import DirectoryBruteforcer
from modules.webscanner.ssl_analyzer import SSLAnalyzer
from modules.webscanner.nuclei import NucleiScanner

__all__ = [
    "WebCrawler",
    "XSSScanner",
    "SQLiScanner",
    "DirectoryBruteforcer",
    "SSLAnalyzer",
    "NucleiScanner",
]
