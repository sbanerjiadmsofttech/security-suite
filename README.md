# Security Suite

[![CI](https://github.com/53cur3dL34rn/security-suite/actions/workflows/ci.yml/badge.svg)](https://github.com/53cur3dL34rn/security-suite/actions/workflows/ci.yml)
[![Python 3.10+](https://img.shields.io/badge/python-3.10%2B-blue.svg)](https://www.python.org/downloads/)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

A comprehensive open-source security tools suite for OSINT reconnaissance, web security testing, API security assessment, and compliance checking with AI-powered analysis.

## Features

### OSINT Module
- DNS enumeration and zone transfer detection
- WHOIS lookup with registrar details
- Subdomain discovery
- Port scanning (nmap integration)
- Technology detection (frameworks, CMS, servers)
- HTTP header analysis
- Email harvesting
- VirusTotal integration
- Shodan integration

### Web Scanner Module
- Web crawling and link discovery
- XSS (Cross-Site Scripting) detection
- SQL injection testing
- Directory bruteforce
- SSL/TLS analysis (certificate, protocols, vulnerabilities)
- Nuclei template scanning

### API Security Module
- OpenAPI/Swagger specification parsing
- Endpoint security testing
- Authentication bypass testing
- JWT vulnerability detection
- Rate limiting checks
- BOLA/IDOR detection
- Parameter fuzzing

### SIEM Integration
- Splunk HEC export
- Elasticsearch bulk export
- Syslog (UDP/TCP/TLS) with RFC5424/RFC3164
- Webhook notifications (Slack, Discord, PagerDuty)
- CEF and LEEF format support

### Scheduled Scans
- Cron-based recurring assessments
- Multiple frequency options (hourly, daily, weekly, monthly)
- Persistent job history
- Automatic result storage

### Web Dashboard
- Real-time scan monitoring
- Findings visualization by severity
- Scan history and statistics
- Schedule management
- One-click target scanning

### AI Analysis
- Multi-provider support (Anthropic, OpenAI, Ollama)
- Local LLM support (LLaMA, Qwen, Mistral)
- Finding correlation and prioritization
- Remediation recommendations
- Executive summary generation

### Additional Modules
- Exploit search (SearchSploit/Exploit-DB)
- Phishing simulation for security awareness
- OWASP Top 10 compliance checking
- CIS Controls assessment

## Installation

```bash
# Clone the repository
git clone https://github.com/53cur3dL34rn/security-suite.git
cd security-suite

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install base package
pip install -e .

# Install with all optional dependencies
pip install -e ".[all]"

# Or install specific extras
pip install -e ".[dev]"       # Development tools
pip install -e ".[ai]"        # AI providers (OpenAI, Anthropic)
pip install -e ".[dashboard]" # Web dashboard (FastAPI, uvicorn)
```

## Configuration

Create a `.env` file in the project root (copy from `.env.example`):

```env
# Core Settings
SECSUITE_DEBUG=false
SECSUITE_DATA_DIR=~/.secsuite

# API Keys (optional - enables enhanced features)
SECSUITE_SHODAN_API_KEY=your_shodan_key
SECSUITE_VIRUSTOTAL_API_KEY=your_virustotal_key
SECSUITE_HUNTER_API_KEY=your_hunter_key

# AI Providers (choose one or more)
SECSUITE_ANTHROPIC_API_KEY=your_anthropic_key
SECSUITE_OPENAI_API_KEY=your_openai_key
SECSUITE_OLLAMA_BASE_URL=http://localhost:11434

# SIEM Integration (optional)
SECSUITE_SPLUNK_URL=https://splunk.example.com:8088
SECSUITE_SPLUNK_TOKEN=your_hec_token
SECSUITE_ELASTICSEARCH_URL=http://localhost:9200
```

## CLI Usage

### OSINT Reconnaissance

```bash
# DNS enumeration
secsuite osint dns example.com

# WHOIS lookup
secsuite osint whois example.com

# Subdomain discovery
secsuite osint subdomains example.com

# HTTP header analysis
secsuite osint headers https://example.com

# Port scanning (requires nmap)
secsuite osint ports 192.168.1.1

# Technology detection
secsuite osint tech https://example.com

# Email harvesting
secsuite osint emails example.com

# VirusTotal lookup (requires API key)
secsuite osint vt example.com

# Shodan lookup (requires API key)
secsuite osint shodan 8.8.8.8

# Full OSINT scan (all modules)
secsuite osint full example.com
```

### Web Security Scanning

```bash
# Web crawling
secsuite scan crawl https://example.com

# XSS detection
secsuite scan xss "https://example.com/search?q=test"

# SQL injection testing
secsuite scan sqli "https://example.com/product?id=1"

# Directory bruteforce
secsuite scan dirs https://example.com

# SSL/TLS analysis
secsuite scan ssl example.com

# Nuclei scanning (requires nuclei)
secsuite scan nuclei https://example.com
```

### API Security Testing

```bash
# Scan API from OpenAPI spec
secsuite api scan https://api.example.com/openapi.json

# Scan with authentication
secsuite api scan spec.yaml --auth-header "Authorization: Bearer token"

# Fuzz API endpoints
secsuite api fuzz https://api.example.com/openapi.json

# Test authentication mechanisms
secsuite api auth-test https://api.example.com --auth-header "Authorization: Bearer token"
```

### AI-Powered Analysis

```bash
# Analyze findings with AI (uses configured provider)
secsuite ai analyze results.json

# Use specific provider
secsuite ai analyze results.json --provider anthropic
secsuite ai analyze results.json --provider openai
secsuite ai analyze results.json --provider ollama --model llama3

# Generate remediation report
secsuite ai remediate results.json --output remediation.md
```

### SIEM Integration

```bash
# Test SIEM connection
secsuite siem test splunk
secsuite siem test elasticsearch
secsuite siem test syslog --host 192.168.1.100 --port 514

# Export findings to SIEM
secsuite siem export results.json --backend splunk
secsuite siem export results.json --backend elasticsearch --index security-findings
```

### Scheduled Scans

```bash
# Create a scheduled scan
secsuite schedule create "Daily Web Scan" example.com --frequency daily --modules dns,headers,ssl

# List schedules
secsuite schedule list

# Run a schedule immediately
secsuite schedule run <schedule-id>

# Delete a schedule
secsuite schedule delete <schedule-id>

# Start scheduler daemon
secsuite schedule start
```

### Web Dashboard

```bash
# Start the dashboard
secsuite dashboard --port 8080

# Access at http://localhost:8080
```

### Exploit Search

```bash
# Search for exploits
secsuite exploit search "apache 2.4"
secsuite exploit search "CVE-2021-44228"
```

### Phishing Simulation (Authorized Testing Only)

```bash
# List email templates
secsuite phish templates

# Start phishing server
secsuite phish server --port 8080
```

## Output Formats

```bash
# JSON output
secsuite osint dns example.com --output json

# Save to file
secsuite osint full example.com --output-file report.json

# Generate HTML report
secsuite report generate results.json --format html --output report.html
```

## External Dependencies

Some features require external tools:

| Tool | Feature | Installation |
|------|---------|--------------|
| nmap | Port scanning | `apt install nmap` |
| nuclei | Vulnerability scanning | [nuclei releases](https://github.com/projectdiscovery/nuclei) |
| searchsploit | Exploit search | `apt install exploitdb` |

## Local LLM Setup (Ollama)

For AI analysis without cloud APIs:

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull a model
ollama pull llama3
ollama pull qwen2.5
ollama pull mistral

# Use with secsuite
secsuite ai analyze results.json --provider ollama --model llama3
```

## Project Structure

```
security-suite/
├── cli/                 # CLI commands (Typer)
├── core/                # Shared models, config, logging
├── modules/
│   ├── osint/          # OSINT tools
│   ├── webscanner/     # Web security scanners
│   ├── apisec/         # API security testing
│   ├── exploit/        # Exploit search
│   ├── phishing/       # Phishing simulation
│   ├── compliance/     # Compliance checking
│   ├── ai/             # AI analysis
│   ├── siem/           # SIEM integration
│   └── scheduler/      # Scheduled scans
├── dashboard/          # Web UI (FastAPI)
├── tests/              # Test suite
├── .env.example        # Environment template
└── pyproject.toml      # Package configuration
```

## Development

```bash
# Install dev dependencies
pip install -e ".[dev]"

# Run tests
pytest

# Run with coverage
pytest --cov=core --cov=modules

# Lint code
ruff check .

# Type checking
mypy core modules
```

## License

AGPL-3.0 - See LICENSE file for details.

## Disclaimer

This tool is intended for **authorized security testing** and **educational purposes only**.

- Always obtain proper written authorization before testing systems you do not own
- Phishing simulations should only be conducted as part of approved security awareness programs
- The developers are not responsible for misuse of this software
- Comply with all applicable laws and regulations in your jurisdiction

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linting
5. Submit a pull request

## Support

- Issues: GitHub Issues
- Documentation: See USAGE.md for detailed examples
