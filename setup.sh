#!/usr/bin/env bash
# =============================================================================
#  Security Suite — Automated Setup Script for Linux
#  Run:  bash setup.sh
#  Options:
#    --no-ollama        Skip Ollama installation
#    --model <name>     Ollama model to pull (default: llama3.2)
#    --no-extras        Skip nmap / nuclei / searchsploit
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
step()    { echo -e "\n${BOLD}━━━  $*  ━━━${RESET}"; }

# ── Argument parsing ─────────────────────────────────────────────────────────
INSTALL_OLLAMA=true
INSTALL_EXTRAS=true
OLLAMA_MODEL="llama3.2"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-ollama)   INSTALL_OLLAMA=false ;;
    --no-extras)   INSTALL_EXTRAS=false ;;
    --model)       OLLAMA_MODEL="$2"; shift ;;
    *) warn "Unknown option: $1" ;;
  esac
  shift
done

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${CYAN}"
cat << 'EOF'
   ____            ____        _ __
  / __/__ ___     / __/_ __(_) /____
 _\ \/ -_) __/   _\ \/ // / / __/ -_)
/___/\__/\__/   /___/\_,_/_/\__/\__/

       =[ SecSuite v0.1.0 - Linux Setup ]=
EOF
echo -e "${RESET}"

# ── Confirm we are in the right directory ─────────────────────────────────────
if [[ ! -f "pyproject.toml" ]]; then
  error "Run this script from inside the security-suite directory."
  error "  cd security-suite && bash setup.sh"
  exit 1
fi

# ── Detect package manager ────────────────────────────────────────────────────
step "Detecting Linux distribution"
PKG_MGR=""
if   command -v apt-get &>/dev/null; then PKG_MGR="apt"
elif command -v dnf      &>/dev/null; then PKG_MGR="dnf"
elif command -v yum      &>/dev/null; then PKG_MGR="yum"
elif command -v pacman   &>/dev/null; then PKG_MGR="pacman"
else
  warn "No supported package manager found. Manual installs may be needed."
fi

pkg_install() {
  local pkg="$1"
  info "Installing $pkg …"
  case "$PKG_MGR" in
    apt)    sudo apt-get install -y "$pkg" ;;
    dnf)    sudo dnf install -y "$pkg" ;;
    yum)    sudo yum install -y "$pkg" ;;
    pacman) sudo pacman -S --noconfirm "$pkg" ;;
    *)      warn "Cannot auto-install $pkg — please install it manually." ;;
  esac
}

pkg_update() {
  case "$PKG_MGR" in
    apt)    sudo apt-get update -y ;;
    dnf|yum) : ;;   # DNF/YUM refresh automatically
    pacman) sudo pacman -Sy ;;
  esac
}

# ── Python 3.10+ ──────────────────────────────────────────────────────────────
step "Checking Python 3.10+"

PYTHON=""
for candidate in python3.12 python3.11 python3.10 python3; do
  if command -v "$candidate" &>/dev/null; then
    ver=$("$candidate" -c 'import sys; print(sys.version_info[:2])')
    if "$candidate" -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' 2>/dev/null; then
      PYTHON="$candidate"
      success "Found $($PYTHON --version)"
      break
    fi
  fi
done

if [[ -z "$PYTHON" ]]; then
  warn "Python 3.10+ not found. Attempting to install …"
  pkg_update
  case "$PKG_MGR" in
    apt)
      sudo apt-get install -y software-properties-common
      if ! apt-cache show python3.11 &>/dev/null 2>&1; then
        sudo add-apt-repository -y ppa:deadsnakes/ppa && sudo apt-get update -y
      fi
      pkg_install python3.11
      pkg_install python3.11-venv
      pkg_install python3.11-distutils
      PYTHON="python3.11"
      ;;
    dnf) pkg_install python3.11; PYTHON="python3.11" ;;
    yum) pkg_install python3; PYTHON="python3" ;;
    pacman) pkg_install python; PYTHON="python3" ;;
    *)
      error "Please install Python 3.10+ manually from https://www.python.org/downloads/"
      exit 1 ;;
  esac
  success "Installed $($PYTHON --version)"
fi

# ── pip ───────────────────────────────────────────────────────────────────────
step "Checking pip"
if ! "$PYTHON" -m pip --version &>/dev/null; then
  warn "pip not found for $PYTHON — installing …"
  case "$PKG_MGR" in
    apt) pkg_install python3-pip ;;
    dnf|yum) pkg_install python3-pip ;;
    pacman) pkg_install python-pip ;;
    *) "$PYTHON" -m ensurepip --upgrade ;;
  esac
fi
success "pip $("$PYTHON" -m pip --version | awk '{print $2}')"

# ── Git ───────────────────────────────────────────────────────────────────────
step "Checking Git"
if ! command -v git &>/dev/null; then
  warn "Git not found — installing …"
  pkg_install git
fi
success "Git $(git --version | awk '{print $3}')"

# ── curl ──────────────────────────────────────────────────────────────────────
if ! command -v curl &>/dev/null; then
  pkg_install curl
fi

# ── Virtual environment ───────────────────────────────────────────────────────
step "Setting up Python virtual environment"
if [[ -d "venv" ]]; then
  info "Virtual environment already exists — reusing it."
else
  "$PYTHON" -m venv venv
  success "Created virtual environment."
fi

# Activate
source venv/bin/activate
success "Activated: $(which python) ($(python --version))"

# ── Upgrade pip inside venv ───────────────────────────────────────────────────
python -m pip install --quiet --upgrade pip setuptools wheel

# ── Install Security Suite ────────────────────────────────────────────────────
step "Installing Security Suite and all dependencies"
pip install -e ".[all]" --quiet
success "Security Suite installed."

# ── Optional external tools ───────────────────────────────────────────────────
if [[ "$INSTALL_EXTRAS" == "true" ]]; then
  step "Installing optional security tools"

  # nmap
  if ! command -v nmap &>/dev/null; then
    info "Installing nmap …"
    pkg_install nmap && success "nmap installed." || warn "nmap install failed — port scanning will be limited."
  else
    success "nmap already installed."
  fi

  # searchsploit / exploitdb
  if ! command -v searchsploit &>/dev/null; then
    info "Attempting to install exploitdb (searchsploit) …"
    case "$PKG_MGR" in
      apt)
        if apt-cache show exploitdb &>/dev/null 2>&1; then
          pkg_install exploitdb && success "exploitdb installed."
        else
          warn "exploitdb not in apt repos — install manually: https://github.com/offensive-security/exploit-database"
        fi
        ;;
      *)
        warn "Install exploitdb manually from: https://github.com/offensive-security/exploit-database"
        ;;
    esac
  else
    success "searchsploit already installed."
  fi
fi

# ── Ollama ────────────────────────────────────────────────────────────────────
if [[ "$INSTALL_OLLAMA" == "true" ]]; then
  step "Setting up Ollama (local AI)"

  if command -v ollama &>/dev/null; then
    success "Ollama already installed: $(ollama --version 2>/dev/null || echo 'version unknown')"
  else
    info "Downloading and installing Ollama …"
    if curl -fsSL https://ollama.com/install.sh | sh; then
      success "Ollama installed."
    else
      warn "Ollama install failed. Install manually from https://ollama.com/download"
      INSTALL_OLLAMA=false
    fi
  fi

  if [[ "$INSTALL_OLLAMA" == "true" ]]; then
    # Start Ollama if not already running
    if ! pgrep -x ollama &>/dev/null; then
      info "Starting Ollama server in background …"
      nohup ollama serve &>/dev/null &
      sleep 3
    fi

    # Pull the default model
    info "Pulling model: $OLLAMA_MODEL (this may take a few minutes on first run) …"
    if ollama pull "$OLLAMA_MODEL"; then
      success "Model $OLLAMA_MODEL ready."
    else
      warn "Model pull failed. You can pull it later with: ollama pull $OLLAMA_MODEL"
    fi
  fi
fi

# ── .env file ─────────────────────────────────────────────────────────────────
step "Creating .env configuration"
if [[ -f ".env" ]]; then
  info ".env already exists — skipping."
else
  if [[ -f ".env.example" ]]; then
    cp .env.example .env
    success "Created .env from .env.example"
    info "Edit .env to add optional API keys (Shodan, VirusTotal, Anthropic, OpenAI)."
  else
    cat > .env << 'ENVEOF'
# Security Suite Configuration
# Uncomment and fill in any keys you have — everything is optional

# SECSUITE_ANTHROPIC_API_KEY=sk-ant-api03-xxxxx
# SECSUITE_OPENAI_API_KEY=sk-xxxxx
# SECSUITE_SHODAN_API_KEY=xxxxx
# SECSUITE_VIRUSTOTAL_API_KEY=xxxxx

# Optional: Protect the REST API with a key
# SECSUITE_API_KEY=change-me
ENVEOF
    success "Created .env template."
  fi
fi

# ── Verify installation ───────────────────────────────────────────────────────
step "Verifying installation"
if secsuite version &>/dev/null; then
  success "secsuite CLI is working."
else
  warn "secsuite command not found in PATH."
  info "To activate the environment in a new shell, run:"
  info "  source venv/bin/activate"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  Security Suite setup complete!${RESET}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${BOLD}Activate environment (new terminals):${RESET}"
echo -e "    source venv/bin/activate"
echo ""
echo -e "  ${BOLD}Start the REST API server:${RESET}"
echo -e "    secsuite serve"
echo -e "    # then open http://localhost:8000/docs"
echo ""
echo -e "  ${BOLD}Run a quick scan:${RESET}"
echo -e "    secsuite osint dns example.com"
echo ""
echo -e "  ${BOLD}Use local AI (no API key needed):${RESET}"
echo -e "    secsuite ai ask 'What is SQL injection?' --provider ollama --model $OLLAMA_MODEL"
echo ""
echo -e "  ${BOLD}See all commands:${RESET}"
echo -e "    secsuite --help"
echo ""
