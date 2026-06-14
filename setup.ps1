#Requires -Version 5.1
<#
.SYNOPSIS
    Security Suite - Automated Setup Script for Windows

.DESCRIPTION
    Checks your environment and installs everything needed to run Security Suite:
    Python 3.11, Git, virtual environment, all Python dependencies, Ollama, and
    a recommended AI model. Run once after cloning the repository.

.PARAMETER NoOllama
    Skip Ollama installation.

.PARAMETER NoExtras
    Skip optional tools (nmap).

.PARAMETER Model
    Ollama model to pull (default: llama3.2).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File setup.ps1
    powershell -ExecutionPolicy Bypass -File setup.ps1 -Model qwen2.5
    powershell -ExecutionPolicy Bypass -File setup.ps1 -NoOllama
#>

param(
    [switch]$NoOllama,
    [switch]$NoExtras,
    [string]$Model = "llama3.2"
)

$ErrorActionPreference = "Stop"

# ── Colours ───────────────────────────────────────────────────────────────────
function Write-Info    { Write-Host "[INFO]  $args" -ForegroundColor Cyan }
function Write-Ok      { Write-Host "[OK]    $args" -ForegroundColor Green }
function Write-Warn    { Write-Host "[WARN]  $args" -ForegroundColor Yellow }
function Write-Err     { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-Step    { Write-Host "`n=== $args ===" -ForegroundColor White }

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Host @"

   ____            ____        _ __
  / __/__ ___     / __/_ __(_) /____
 _\ \/ -_) __/   _\ \/ // / / __/ -_)
/___/\__/\__/   /___/\_,_/_/\__/\__/

       =[ SecSuite v0.1.0 - Windows Setup ]=

"@ -ForegroundColor Cyan

# ── Must be inside the repo directory ─────────────────────────────────────────
if (-not (Test-Path "pyproject.toml")) {
    Write-Err "Run this script from inside the security-suite directory."
    Write-Err "  cd security-suite"
    Write-Err "  powershell -ExecutionPolicy Bypass -File setup.ps1"
    exit 1
}

# ── Helper: check if a command exists ─────────────────────────────────────────
function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# ── Helper: install via winget ────────────────────────────────────────────────
function Install-Via-Winget {
    param([string]$PackageId, [string]$Label)
    if (-not (Test-Command "winget")) {
        Write-Warn "winget not available. Please install $Label manually."
        return $false
    }
    Write-Info "Installing $Label via winget ..."
    try {
        winget install --id $PackageId --silent --accept-package-agreements --accept-source-agreements
        return $true
    } catch {
        Write-Warn "winget install failed for $Label. Please install it manually."
        return $false
    }
}

# ── Refresh PATH in current session ───────────────────────────────────────────
function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# ── winget availability ────────────────────────────────────────────────────────
Write-Step "Checking winget (Windows Package Manager)"
if (Test-Command "winget") {
    Write-Ok "winget is available."
} else {
    Write-Warn "winget not found. You may need to install packages manually."
    Write-Warn "winget is built into Windows 10 (2004+) and Windows 11."
    Write-Warn "Download App Installer from the Microsoft Store if missing."
}

# ── Python 3.10+ ──────────────────────────────────────────────────────────────
Write-Step "Checking Python 3.10+"

$PythonExe = $null

# Try candidates in order: py launcher, then direct commands
$candidates = @("py", "python3", "python")
foreach ($cmd in $candidates) {
    if (Test-Command $cmd) {
        try {
            $ver = & $cmd --version 2>&1
            $match = [regex]::Match($ver, '(\d+)\.(\d+)')
            if ($match.Success) {
                $major = [int]$match.Groups[1].Value
                $minor = [int]$match.Groups[2].Value
                if ($major -ge 3 -and $minor -ge 10) {
                    $PythonExe = $cmd
                    Write-Ok "Found: $ver"
                    break
                }
            }
        } catch {}
    }
}

# Try py launcher with explicit version
if (-not $PythonExe -and (Test-Command "py")) {
    foreach ($v in @("3.12", "3.11", "3.10")) {
        try {
            $ver = & py "-$v" --version 2>&1
            if ($ver -match "Python 3") {
                $PythonExe = "py -$v"
                Write-Ok "Found via py launcher: $ver"
                break
            }
        } catch {}
    }
}

if (-not $PythonExe) {
    Write-Warn "Python 3.10+ not found. Installing Python 3.11 ..."
    $installed = Install-Via-Winget "Python.Python.3.11" "Python 3.11"
    if ($installed) {
        Refresh-Path
        Start-Sleep -Seconds 2
        # Try again after install
        if (Test-Command "py") {
            $PythonExe = "py -3.11"
        } elseif (Test-Command "python") {
            $PythonExe = "python"
        } else {
            Write-Err "Python installed but not found in PATH."
            Write-Err "Please restart PowerShell and re-run this script."
            exit 1
        }
        Write-Ok "Python installed: $( & python --version 2>&1 )"
    } else {
        Write-Err "Could not install Python automatically."
        Write-Err "Download it from https://www.python.org/downloads/"
        Write-Err "Make sure to check 'Add Python to PATH' during installation."
        exit 1
    }
}

# Normalise: turn "py -3.11" into an executable + arg array we can use with &
$PythonCmd = $PythonExe.Split(" ")[0]
$PythonArgs = $PythonExe.Split(" ")[1..99]   # may be empty

# ── Git ───────────────────────────────────────────────────────────────────────
Write-Step "Checking Git"
if (Test-Command "git") {
    $gitVer = git --version
    Write-Ok $gitVer
} else {
    Write-Warn "Git not found. Installing ..."
    $installed = Install-Via-Winget "Git.Git" "Git"
    if ($installed) {
        Refresh-Path
        Write-Ok "Git installed."
    } else {
        Write-Warn "Git not installed. Download from https://git-scm.com/download/win"
    }
}

# ── Virtual environment ───────────────────────────────────────────────────────
Write-Step "Setting up Python virtual environment"
if (Test-Path "venv") {
    Write-Info "Virtual environment already exists — reusing."
} else {
    Write-Info "Creating virtual environment ..."
    & $PythonCmd @PythonArgs -m venv venv
    Write-Ok "Virtual environment created."
}

# Activate
$ActivateScript = "venv\Scripts\Activate.ps1"
if (-not (Test-Path $ActivateScript)) {
    Write-Err "Could not find $ActivateScript — venv creation may have failed."
    exit 1
}
. .\venv\Scripts\Activate.ps1
Write-Ok "Activated: $(python --version)"

# Upgrade pip
Write-Info "Upgrading pip ..."
python -m pip install --quiet --upgrade pip setuptools wheel

# ── Install Security Suite ────────────────────────────────────────────────────
Write-Step "Installing Security Suite and all dependencies"
Write-Info "This may take a few minutes ..."
pip install -e ".[all]" --quiet
Write-Ok "Security Suite installed."

# ── nmap (optional) ───────────────────────────────────────────────────────────
if (-not $NoExtras) {
    Write-Step "Installing optional tools"
    if (Test-Command "nmap") {
        Write-Ok "nmap already installed."
    } else {
        Write-Info "Installing nmap (for port scanning) ..."
        $installed = Install-Via-Winget "Insecure.Nmap" "nmap"
        if ($installed) {
            Refresh-Path
            Write-Ok "nmap installed."
        } else {
            Write-Warn "nmap not installed. Port scanning will be unavailable."
            Write-Warn "Install manually from https://nmap.org/download.html"
        }
    }
}

# ── Ollama ────────────────────────────────────────────────────────────────────
if (-not $NoOllama) {
    Write-Step "Setting up Ollama (local AI — no internet needed after setup)"

    if (Test-Command "ollama") {
        Write-Ok "Ollama already installed."
    } else {
        Write-Info "Installing Ollama ..."
        $installed = Install-Via-Winget "Ollama.Ollama" "Ollama"
        if ($installed) {
            Refresh-Path
            Start-Sleep -Seconds 3
            Write-Ok "Ollama installed."
        } else {
            Write-Warn "Could not auto-install Ollama."
            Write-Warn "Download from https://ollama.com/download/windows and re-run this script."
            $NoOllama = $true
        }
    }

    if (-not $NoOllama) {
        # On Windows, Ollama runs as a background app / tray icon after install.
        # Give it a moment to start, then pull the model.
        Write-Info "Waiting for Ollama service to be ready ..."
        $ready = $false
        for ($i = 0; $i -lt 10; $i++) {
            try {
                $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -TimeoutSec 2 -ErrorAction SilentlyContinue
                $ready = $true
                break
            } catch {
                Start-Sleep -Seconds 2
            }
        }

        if (-not $ready) {
            Write-Warn "Ollama service did not start automatically."
            Write-Warn "Open Ollama from the Start Menu, then run:"
            Write-Warn "  ollama pull $Model"
        } else {
            Write-Info "Pulling model: $Model (may take several minutes on first run) ..."
            try {
                ollama pull $Model
                Write-Ok "Model '$Model' is ready."
            } catch {
                Write-Warn "Model pull failed. Pull it later with: ollama pull $Model"
            }
        }
    }
}

# ── .env file ─────────────────────────────────────────────────────────────────
Write-Step "Creating .env configuration"
if (Test-Path ".env") {
    Write-Info ".env already exists — skipping."
} elseif (Test-Path ".env.example") {
    Copy-Item ".env.example" ".env"
    Write-Ok "Created .env from .env.example"
    Write-Info "Edit .env to add optional API keys (Shodan, VirusTotal, Anthropic, OpenAI)."
} else {
    @"
# Security Suite Configuration
# Uncomment and fill in any keys you have - everything is optional

# SECSUITE_ANTHROPIC_API_KEY=sk-ant-api03-xxxxx
# SECSUITE_OPENAI_API_KEY=sk-xxxxx
# SECSUITE_SHODAN_API_KEY=xxxxx
# SECSUITE_VIRUSTOTAL_API_KEY=xxxxx

# Optional: Protect the REST API with a key
# SECSUITE_API_KEY=change-me
"@ | Out-File -FilePath ".env" -Encoding utf8
    Write-Ok "Created .env template."
}

# ── Verify ────────────────────────────────────────────────────────────────────
Write-Step "Verifying installation"
try {
    secsuite version 2>&1 | Out-Null
    Write-Ok "secsuite CLI is working."
} catch {
    Write-Warn "secsuite command not found. Activate the environment first:"
    Write-Warn "  .\venv\Scripts\Activate.ps1"
}

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  Security Suite setup complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Activate environment (new PowerShell windows):" -ForegroundColor White
Write-Host "    .\venv\Scripts\Activate.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Start the REST API server:" -ForegroundColor White
Write-Host "    secsuite serve" -ForegroundColor Cyan
Write-Host "    # then open http://localhost:8000/docs in your browser" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Run a quick scan:" -ForegroundColor White
Write-Host "    secsuite osint dns example.com" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Use local AI (no API key needed):" -ForegroundColor White
Write-Host "    secsuite ai ask 'What is SQL injection?' --provider ollama --model $Model" -ForegroundColor Cyan
Write-Host ""
Write-Host "  See all commands:" -ForegroundColor White
Write-Host "    secsuite --help" -ForegroundColor Cyan
Write-Host ""
