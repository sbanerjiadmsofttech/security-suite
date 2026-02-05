# Security Suite - Usage Guide

## Table of Contents
1. [Installation](#installation)
2. [Configuration](#configuration)
3. [Quick Start](#quick-start)
4. [Module Reference](#module-reference)
5. [AI Integration](#ai-integration)
6. [Report Generation](#report-generation)
7. [Advanced Usage](#advanced-usage)
8. [Future Enhancements](#future-enhancements)

---

## Installation

### Prerequisites
- Python 3.11+
- nmap (optional, for port scanning)
- Ollama (optional, for local AI)

### Install from source
```bash
cd security-suite
python3 -m venv venv
source venv/bin/activate
pip install -e .
```

### Verify installation
```bash
secsuite version
secsuite --help
```

---

## Configuration

### Step 1: Create your .env file
```bash
cp .env.example .env
```

### Step 2: Add your API keys (optional)
Edit `.env` and add any API keys you have:

```env
# For cloud AI (choose one)
SECSUITE_ANTHROPIC_API_KEY=sk-ant-api03-xxxxx
SECSUITE_OPENAI_API_KEY=sk-xxxxx

# For enhanced scanning
SECSUITE_SHODAN_API_KEY=xxxxx
SECSUITE_VIRUSTOTAL_API_KEY=xxxxx
```

### Step 3: Verify configuration
```bash
secsuite config
```

### Using Local AI (No API Key Required)
```bash
# Install Ollama: https://ollama.ai
# Pull a model
ollama pull llama3
ollama pull mistral

# Use with Security Suite
secsuite ai ask "What is XSS?" -p llama3
```

---

## Quick Start

### 1. Basic Security Assessment
```bash
# Quick scan with AI analysis (using local LLM)
secsuite ai analyze example.com -p llama3 --quick

# Full scan with all modules
secsuite ai analyze example.com -p llama3
```

### 2. OSINT Reconnaissance
```bash
# DNS enumeration
secsuite osint dns example.com

# Port scanning (requires nmap)
secsuite osint ports example.com

# Technology detection
secsuite osint tech example.com

# All OSINT modules
secsuite osint dns example.com
secsuite osint whois example.com
secsuite osint subdomains example.com
secsuite osint headers example.com
secsuite osint tech example.com
secsuite osint ports example.com
```

### 3. Web Security Scanning
```bash
# SSL/TLS analysis
secsuite scan ssl example.com

# Directory bruteforce
secsuite scan dirs https://example.com

# Full web scan
secsuite scan full https://example.com
```

### 4. Generate Reports
```bash
# HTML report
secsuite report html example.com -o report.html

# HTML report with AI analysis
secsuite report html example.com -o report.html --ai -p llama3

# JSON report (for integration)
secsuite report json example.com -o report.json
```

---

## Module Reference

### OSINT Module
| Command | Description |
|---------|-------------|
| `osint dns <target>` | DNS record enumeration |
| `osint whois <target>` | WHOIS lookup |
| `osint subdomains <target>` | Subdomain discovery |
| `osint headers <target>` | HTTP header analysis |
| `osint tech <target>` | Technology fingerprinting |
| `osint ports <target>` | Port scanning (nmap) |
| `osint shodan <target>` | Shodan lookup (API key required) |
| `osint virustotal <target>` | VirusTotal lookup (API key required) |

### Web Scanner Module
| Command | Description |
|---------|-------------|
| `scan crawl <url>` | Web crawler |
| `scan xss <url>` | XSS vulnerability scanner |
| `scan sqli <url>` | SQL injection scanner |
| `scan dirs <url>` | Directory bruteforce |
| `scan ssl <target>` | SSL/TLS analysis |
| `scan nuclei <url>` | Nuclei vulnerability scanner |
| `scan full <url>` | Run all web scans |

### AI Copilot Module
| Command | Description |
|---------|-------------|
| `ai providers` | List available LLM providers |
| `ai analyze <target>` | Full security analysis with AI |
| `ai ask "<question>"` | Ask security questions |
| `ai executive <target>` | Generate executive summary |
| `ai correlate <target>` | Correlate findings, detect attack chains |

### Report Module
| Command | Description |
|---------|-------------|
| `report html <target>` | Generate HTML report |
| `report json <target>` | Generate JSON report |
| `report remediation "<finding>"` | Get remediation guidance |

### Phishing Module (for authorized testing only)
| Command | Description |
|---------|-------------|
| `phish create` | Create phishing campaign |
| `phish list` | List campaigns |
| `phish start <id>` | Start tracking server |
| `phish stats <id>` | View campaign statistics |

### Exploit Module
| Command | Description |
|---------|-------------|
| `exploit search "<query>"` | Search exploits (SearchSploit) |
| `exploit msf-search "<query>"` | Search Metasploit modules |

---

## AI Integration

### Supported Providers

| Provider | Type | API Key Required | Command |
|----------|------|------------------|---------|
| Anthropic Claude | Cloud | Yes | `-p anthropic` |
| OpenAI GPT | Cloud | Yes | `-p openai` |
| Ollama (LLaMA, Qwen, Mistral) | Local | No | `-p llama3` / `-p ollama` |
| OpenAI-compatible | Custom | Varies | `-p openai-compatible` |

### Using Local Models (Recommended for Privacy)
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull models
ollama pull llama3
ollama pull mistral:7b
ollama pull qwen2.5

# Use with secsuite
secsuite ai ask "Explain OWASP Top 10" -p llama3
secsuite ai analyze target.com -p mistral
secsuite ai analyze target.com -p ollama -m qwen2.5
```

### Model Shortcuts
```bash
# These shortcuts auto-select Ollama models:
secsuite ai ask "..." -p llama3    # Uses llama3
secsuite ai ask "..." -p mistral   # Uses mistral
secsuite ai ask "..." -p qwen      # Uses qwen2.5
secsuite ai ask "..." -p codellama # Uses codellama
secsuite ai ask "..." -p deepseek  # Uses deepseek-coder-v2
```

### Using Cloud Providers
```bash
# Set API key in .env or environment
export SECSUITE_ANTHROPIC_API_KEY=sk-ant-xxxxx

# Use Claude
secsuite ai analyze target.com -p anthropic
```

---

## Report Generation

### HTML Reports
```bash
# Basic report
secsuite report html target.com

# With custom title
secsuite report html target.com -t "Q1 Security Assessment"

# With AI analysis
secsuite report html target.com --ai -p llama3

# Custom output path
secsuite report html target.com -o ~/reports/assessment.html
```

### JSON Reports (for CI/CD integration)
```bash
secsuite report json target.com -o results.json

# Parse with jq
cat results.json | jq '.risk_summary'
cat results.json | jq '.findings[] | select(.severity == "critical")'
```

### Remediation Guidance
```bash
# Get fix instructions for specific vulnerabilities
secsuite report remediation "sql injection"
secsuite report remediation "xss"
secsuite report remediation "security headers"
secsuite report remediation "ssl certificate"
```

---

## Advanced Usage

### Scripting & Automation
```python
import asyncio
from core.models import Target
from modules.osint import DNSEnumerator, PortScanner
from modules.ai import SecurityCopilot

async def scan_target(domain: str):
    target = Target.from_string(domain)

    # Run scans
    dns = DNSEnumerator()
    ports = PortScanner()

    dns_result = await dns.run(target)
    port_result = await ports.run(target)

    # AI analysis
    copilot = SecurityCopilot(provider="llama3")
    copilot.load_scan_results([dns_result, port_result])

    analysis = await copilot.analyze()
    print(analysis)

asyncio.run(scan_target("example.com"))
```

### CI/CD Integration
```yaml
# .github/workflows/security-scan.yml
name: Security Scan
on: [push]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install secsuite
        run: pip install ./security-suite
      - name: Run scan
        run: secsuite report json ${{ vars.TARGET }} -o results.json
      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: security-report
          path: results.json
```

### Parallel Scanning
```bash
# Scan multiple targets
for target in target1.com target2.com target3.com; do
  secsuite report json $target -o "${target}.json" &
done
wait
```

---

## Future Enhancements

### Planned Features
- [ ] **Cloud scanning** - AWS, GCP, Azure security checks
- [ ] **Container security** - Docker/Kubernetes scanning
- [ ] **API security** - OpenAPI/Swagger endpoint testing
- [ ] **Dependency scanning** - SBOM and vulnerability detection
- [ ] **Network mapping** - Visual attack surface diagrams
- [ ] **Scheduled scans** - Cron-based recurring assessments
- [ ] **Alerting** - Slack/Discord/Email notifications
- [ ] **Dashboard** - Web UI for results visualization

### Potential Integrations
- [ ] **Burp Suite** - Import/export findings
- [ ] **OWASP ZAP** - Proxy integration
- [ ] **Nessus/OpenVAS** - Vulnerability scanner import
- [ ] **Jira/GitHub Issues** - Ticket creation
- [ ] **SIEM** - Log forwarding (Splunk, ELK)
- [ ] **Terraform** - Infrastructure security scanning

### How to Contribute
1. Fork the repository
2. Create a feature branch
3. Add your module in `modules/`
4. Write tests in `tests/`
5. Submit a pull request

---

## Troubleshooting

### Common Issues

**"Ollama error: model not found"**
```bash
# Pull the model first
ollama pull llama3
ollama list  # Verify it's installed
```

**"API key not configured"**
```bash
# Check your .env file exists and has correct values
cat .env | grep API_KEY

# Or set directly
export SECSUITE_ANTHROPIC_API_KEY=your-key-here
```

**"nmap not found"**
```bash
# Install nmap
sudo apt install nmap  # Debian/Ubuntu
brew install nmap      # macOS
```

**Permission errors on scans**
```bash
# Some scans require elevated privileges
sudo secsuite osint ports target.com
```

---

## Legal Disclaimer

This tool is intended for **authorized security testing only**. Always ensure you have written permission before scanning any target. Unauthorized scanning may violate laws including:

- Computer Fraud and Abuse Act (US)
- Computer Misuse Act (UK)
- Similar laws in other jurisdictions

The developers are not responsible for misuse of this tool.
