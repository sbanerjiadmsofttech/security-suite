# Security Suite - Architecture Documentation

## Overview

Security Suite is a modular, asynchronous Python security testing platform designed for comprehensive security assessments including OSINT, web scanning, API security testing, and compliance checking. The architecture follows clean separation of concerns with pluggable modules and a unified data model.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           User Interface                                 │
├───────────────────────────────────┬───────────────────────────────────┤
│   CLI (typer)                     │  REST API (FastAPI)               │
│   - secsuite scan                 │  - /api/v1/scans                 │
│   - secsuite osint                │  - /api/v1/results               │
│   - secsuite ai analyze           │  - /api/v1/modules               │
└───────────────────────────────────┴───────────────────────────────────┘
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     Core Infrastructure Layer                            │
├─────────────────────────────────────────────────────────────────────────┤
│ • Target Model (domain, IP, URL, email)                                │
│ • Configuration (Pydantic-based settings)                              │
│ • Logging (structured, contextual)                                     │
│ • Error Handling (custom exceptions)                                   │
│ • Caching (filesystem + memory)                                        │
│ • Export (JSON, CSV, HTML, Markdown)                                  │
│ • Tool Management (subprocess, error handling)                         │
└─────────────────────────────────────────────────────────────────────────┘
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    Scanning Modules (Plugin Architecture)                │
├─────────────────────────────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────────────────────────────┐   │
│ │ OSINT (11 modules)                                              │   │
│ │ • DNS Enumeration • WHOIS Lookup • Subdomain Discovery        │   │
│ │ • Port Scanning • Tech Detection • Header Analysis            │   │
│ │ • Email Harvesting • VirusTotal • Shodan • IP Geolocation    │   │
│ └──────────────────────────────────────────────────────────────────┘   │
│ ┌──────────────────────────────────────────────────────────────────┐   │
│ │ Web Scanner (6 modules)                                         │   │
│ │ • Web Crawling • XSS Detection • SQLi Testing                 │   │
│ │ • Directory Bruteforce • SSL Analysis • Nuclei Integration    │   │
│ └──────────────────────────────────────────────────────────────────┘   │
│ ┌──────────────────────────────────────────────────────────────────┐   │
│ │ API Security (4 modules)                                        │   │
│ │ • OpenAPI Parser • Auth Testing • Endpoint Testing            │   │
│ │ • Parameter Fuzzing • BOLA/IDOR Detection                     │   │
│ └──────────────────────────────────────────────────────────────────┘   │
│ ┌──────────────────────────────────────────────────────────────────┐   │
│ │ Compliance (2 modules)                                          │   │
│ │ • OWASP Top 10 Checking • CIS Controls Assessment             │   │
│ └──────────────────────────────────────────────────────────────────┘   │
│ ┌──────────────────────────────────────────────────────────────────┐   │
│ │ Additional Modules                                              │   │
│ │ • Phishing Simulation • Exploit Search • SIEM Integration     │   │
│ │ • Scheduling • AI Analysis & Correlation                      │   │
│ └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           Data Models                                    │
├─────────────────────────────────────────────────────────────────────────┤
│ • Target: domain/IP/URL/email classification                           │
│ • ScanResult: module output with findings                              │
│ • Finding: individual security issue with severity/CVSS              │
│ • Severity: critical, high, medium, low, info                        │
└─────────────────────────────────────────────────────────────────────────┘
```

## Module Structure

### Base Classes

All modules inherit from abstract base classes defining the interface:

```python
# OSINT Module Example
class OSINTModule(ABC):
    async def run(self, target: Target) -> ScanResult:
        """Run scan and return findings"""
        
class WebScannerModule(ABC):
    async def run(self, target: Target) -> ScanResult:
        """Run web security scan"""
```

### Module Execution Flow

```
1. CLI/API Request
   ↓
2. Target Validation & Parsing
   ↓
3. Cache Lookup
   ├─ Cache Hit → Return cached results
   └─ Cache Miss → Continue
   ↓
4. Module Execution (async)
   ├─ Pre-execution checks (tool availability)
   ├─ Run scan logic
   ├─ Handle errors gracefully
   └─ Collect findings
   ↓
5. Result Aggregation
   ├─ Format findings
   ├─ Calculate severity scores
   └─ Add metadata
   ↓
6. Caching (new results)
   ↓
7. Return/Export Results
   ├─ CLI output (Rich formatting)
   ├─ API response (JSON)
   └─ File export (JSON/CSV/HTML/MD)
```

## Data Flow

### Scan Execution Flow

```
User Input
    ↓
    ├─ Target: "example.com"
    ├─ Modules: ["dns", "whois", "tech"]
    └─ Options: {}
    ↓
Cache Check
    ├─ Checksum: SHA256(target + modules)
    ├─ Lookup in ~/.secsuite/cache/
    └─ TTL validation (default 24h)
    ↓
Module Execution (Async)
    ├─ DNS Enum → findings []
    ├─ WHOIS Lookup → findings []
    └─ Tech Detect → findings []
    ↓
Result Aggregation
    ├─ Deduplicate findings
    ├─ Score by severity
    └─ Add timestamps
    ↓
Output Formatting
    ├─ Console (Rich table)
    ├─ JSON (machine readable)
    ├─ HTML (report)
    └─ Markdown (documentation)
```

### Finding Severity Classification

```
CRITICAL (10.0x)
├─ RCE vulnerabilities
├─ Authentication bypass
└─ Data exfiltration

HIGH (7.0x)
├─ SQL Injection
├─ XSS vulnerabilities
└─ Sensitive data exposure

MEDIUM (4.0x)
├─ CSRF
├─ Weak encryption
└─ Outdated libraries

LOW (2.0x)
├─ Banner grabbing
└─ Misconfiguration

INFO (0.5x)
└─ Informational findings
```

## Key Components

### 1. Core Package (`core/`)

#### `config.py`
- Pydantic-based settings management
- Environment variable loading from `.env`
- API keys and authentication tokens
- Network and rate limiting settings

#### `models.py`
- `Target`: Parses and classifies input (domain/IP/URL/email)
- `ScanResult`: Container for module output
- `Finding`: Individual security issue
- `Severity`: Enum for finding severity

#### `logger.py`
- Structured logging with context
- Log levels: DEBUG, INFO, WARNING, ERROR, CRITICAL
- Contextual logger instances per module

#### `cache.py`
- SHA256-based cache keys (target + modules + options)
- Dual storage: memory cache + filesystem (JSON)
- TTL-based expiration (default 24 hours)
- Automatic cleanup of expired entries

#### `exporters.py`
- Pluggable exporter architecture
- Formats: JSON, CSV, HTML (with styling), Markdown
- Summary statistics and severity breakdown
- Timestamp and metadata preservation

#### `exceptions.py`
- Custom exception hierarchy
- Tool execution errors with graceful fallbacks
- Configuration and validation errors

#### `tools.py`
- External tool discovery and management
- Subprocess execution with timeout handling
- Error recovery for missing tools
- Tool availability caching

### 2. CLI Package (`cli/`)

#### `main.py`
- Typer-based command structure
- Commands: scan, osint, webscanner, api, ai, report, schedule, cache
- Rich formatting for console output
- Async execution support

### 3. Modules Package (`modules/`)

#### OSINT (`osint/`)
- DNS enumeration with zone transfer detection
- WHOIS lookups with registrar details
- Subdomain discovery (multiple sources)
- Port scanning (nmap integration)
- Technology detection (frameworks, CMS)
- HTTP header analysis
- Email harvesting
- VirusTotal, Shodan integrations

#### Web Scanner (`webscanner/`)
- Web crawling with link discovery
- XSS vulnerability detection
- SQL injection testing
- Directory bruteforce with common wordlists
- SSL/TLS certificate analysis
- Protocol vulnerability scanning

#### API Security (`apisec/`)
- OpenAPI/Swagger specification parsing
- Endpoint security testing
- JWT vulnerability detection
- Rate limiting checks
- BOLA/IDOR detection
- Parameter fuzzing with anomaly detection

#### Compliance (`compliance/`)
- OWASP Top 10 control checks
- CIS Controls assessment
- Custom policy evaluation

#### AI (`ai/`)
- Multi-provider support (Anthropic, OpenAI, Ollama)
- Finding correlation and deduplication
- Attack chain identification (MITRE ATT&CK)
- Remediation recommendations
- Executive summary generation

#### Additional Modules
- **Phishing**: Templates, campaigns, tracking, landing pages
- **Exploit**: SearchSploit and Metasploit integration
- **SIEM**: Splunk HEC, Elasticsearch, Syslog, webhooks
- **Scheduler**: Cron-based scan scheduling

### 4. API Package (`api/`)

#### `server.py`
- FastAPI application factory
- CORS middleware configuration
- Router registration

#### `models.py`
- Pydantic models for API requests/responses
- `ScanRequest`: Input validation
- `ScanResponse`: Standardized output
- `FindingResponse`: Finding details

#### `routers/`

**`health.py`**
- Health check endpoint (`GET /health`)
- System status monitoring

**`scans.py`**
- `POST /api/v1/scans`: Create and queue scan
- `GET /api/v1/scans/{id}`: Get scan details
- `GET /api/v1/scans`: List scans (paginated)
- `DELETE /api/v1/scans/{id}`: Delete scan
- Background task execution with async/await

**`results.py`**
- `GET /api/v1/results/scans/{id}/findings`: Get findings
- `GET /api/v1/results/scans/{id}/export/json`: Export as JSON
- `GET /api/v1/results/scans/{id}/export/csv`: Export as CSV
- `GET /api/v1/results/summary`: Summary statistics

**`modules.py`**
- `GET /api/v1/modules`: List all modules
- `GET /api/v1/modules/{category}`: Get by category
- Module capabilities and options

### 5. Dashboard Package (`dashboard/`)

- FastAPI-based web UI
- Real-time scan monitoring
- Findings visualization
- Scan history and statistics
- One-click scanning

## Design Patterns

### 1. Abstract Base Classes (ABC)

Modules define clear contracts:

```python
from abc import ABC, abstractmethod

class OSINTModule(ABC):
    name: str
    description: str
    
    @abstractmethod
    async def run(self, target: Target) -> ScanResult:
        pass
    
    def create_result(self, target: Target) -> ScanResult:
        return ScanResult(target=target, module=f"osint.{self.name}")
```

### 2. Pluggable Module Architecture

New modules can be added by:
1. Inheriting from base class
2. Implementing required methods
3. Registering in module registry

### 3. Factory Pattern

Result exporters:
```python
exporters = {
    "json": JSONExporter,
    "csv": CSVExporter,
    "html": HTMLExporter,
}
exporter = exporters[format](result)
exporter.export(output_path)
```

### 4. Decorator Pattern

Error handling decorators:
```python
@handle_tool_error("nmap", fallback_value=[])
async def scan_ports(target):
    # Implementation
```

### 5. Singleton Pattern

Global cache instance:
```python
def get_cache() -> ScanCache:
    global _cache_instance
    if _cache_instance is None:
        _cache_instance = ScanCache()
    return _cache_instance
```

### 6. Strategy Pattern

Export strategies (JSON, CSV, HTML, Markdown) implement common interface.

## Error Handling Strategy

```
Try Execution
    ↓
    ├─ Tool Not Found
    │  └─ Log warning, return empty findings, continue
    ├─ Network Error
    │  └─ Retry with exponential backoff
    ├─ Invalid Input
    │  └─ Raise ValidationError, exit gracefully
    └─ Unexpected Error
       └─ Log error, return partial results
```

## Caching Strategy

```
Cache Key = SHA256(target + sorted(modules) + options)

Cache Entry:
├─ Checksum (for key)
├─ Target (for lookup)
├─ Modules (for lookup)
├─ Result Data (findings)
├─ Created At (timestamp)
├─ Expires At (TTL)
└─ Options (parameters)

Storage:
├─ Memory Cache (fast, lost on restart)
└─ Disk Cache (~/.secsuite/cache/, persistent)

Hit Rate = Memory Hit || Disk Hit
Miss Rate = No valid entry
```

## Performance Considerations

### Async/Await
- All I/O operations are asynchronous
- Enables scanning multiple targets concurrently
- Scales to thousands of concurrent requests

### Caching
- Checksum-based cache invalidation
- TTL-based expiration
- Dual-layer caching (memory + disk)

### Module Optimization
- Lazy module loading
- Tool availability checking upfront
- Graceful degradation on missing tools

### Database
- In-memory for API (add persistence for production)
- Filesystem cache for results

## Testing Strategy

### Unit Tests
- Individual module functionality
- Cache operations (get, set, expire)
- Export formats
- Error handling

### Integration Tests
- End-to-end scan execution
- API endpoint testing
- Module interaction testing

### Coverage
- Configured for 80%+ coverage
- HTML reports in `htmlcov/`
- Command: `pytest --cov=core --cov=modules tests/`

## Security Considerations

### API Security
- CORS enabled (configure for production)
- Input validation via Pydantic
- Error messages don't leak sensitive info

### Data Protection
- Cache results are plaintext (for production: encrypt)
- API runs on localhost:8080 (restrict network access)
- No authentication by default (add JWT/API keys)

### Tool Security
- Subprocess execution with timeout
- Command injection prevention via list arguments
- Error logging without credential leakage

## Deployment Considerations

### Production Checklist
- [ ] Set `SECSUITE_DEBUG=false`
- [ ] Configure API authentication (JWT, API keys)
- [ ] Restrict CORS origins
- [ ] Use persistent database instead of in-memory
- [ ] Encrypt cache entries
- [ ] Set up monitoring and alerting
- [ ] Configure external tool dependencies
- [ ] Set resource limits (max scans, timeout)
- [ ] Enable result retention policies
- [ ] Set up log aggregation

### Scaling
- Horizontal: Run multiple API instances behind load balancer
- Vertical: Increase concurrency limits, optimize modules
- Queue: Add task queue (Celery, RQ) for long-running scans

## Future Enhancements

1. **Database Integration**: Replace in-memory storage with PostgreSQL/MongoDB
2. **Authentication**: JWT, OAuth2, API keys
3. **Reporting**: PDF generation, scheduled reports
4. **Notifications**: Email, Slack, Teams integration
5. **Orchestration**: Docker/Kubernetes support
6. **CI/CD**: Jenkins, GitLab CI integration
7. **Advanced Analytics**: Machine learning for findings correlation
8. **Multi-tenancy**: Support for multiple organizations
9. **Web Console**: Advanced web dashboard with real-time updates
10. **Custom Modules**: Plugin system for third-party modules
