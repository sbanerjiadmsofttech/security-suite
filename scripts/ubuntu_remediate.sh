#!/usr/bin/env bash
# =============================================================================
#  ubuntu_remediate.sh — LLM-driven remediation companion
#  Reads latest audit findings → asks local Ollama to generate fix commands
#  → prompts for confirmation before executing anything
#
#  Usage:
#    bash ubuntu_remediate.sh                        # uses qwen2.5:7b
#    bash ubuntu_remediate.sh --model llama3.1       # override model
#    bash ubuntu_remediate.sh --dry-run              # show commands, don't run
#    bash ubuntu_remediate.sh --severity CRITICAL    # only fix CRITICAL items
#    bash ubuntu_remediate.sh --findings /path/to/findings.json
# =============================================================================

set -uo pipefail

SECSUITE="$(command -v secsuite 2>/dev/null)"
REPORT_DIR="${HOME}/.secsuite/audit_reports"
FINDINGS_FILE="${REPORT_DIR}/latest_findings.json"
REMEDIATION_LOG="${REPORT_DIR}/remediation_$(date +%Y%m%d_%H%M%S).log"
OLLAMA_URL="http://localhost:11434"
MODEL="qwen2.5:7b"
DRY_RUN=false
SEV_FILTER=""   # empty = all actionable severities

# ── Parse arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)       MODEL="$2";          shift 2 ;;
    --findings)    FINDINGS_FILE="$2";  shift 2 ;;
    --dry-run)     DRY_RUN=true;        shift   ;;
    --severity)    SEV_FILTER="${2^^}"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; LRED='\033[1;31m'; GREEN='\033[0;32m'; LGREEN='\033[1;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

sev_color() {
  case "$1" in
    CRITICAL) printf '%s' "$LRED"   ;;
    HIGH)     printf '%s' "$RED"    ;;
    MEDIUM)   printf '%s' "$YELLOW" ;;
    LOW)      printf '%s' "$BLUE"   ;;
    *)        printf '%s' "$NC"     ;;
  esac
}

log_action() { echo "[$(date '+%H:%M:%S')] $*" >> "$REMEDIATION_LOG"; }

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║         SecSuite LLM Remediation Assistant          ║"
echo "  ╚══════════════════════════════════════════════════════╝${NC}"
echo -e "  Model : ${BOLD}${MODEL}${NC}  |  Ollama: ${OLLAMA_URL}"
echo -e "  Mode  : $(${DRY_RUN} && echo "${YELLOW}DRY RUN — no changes will be made${NC}" || echo "${GREEN}LIVE${NC}")"
[[ -n "$SEV_FILTER" ]] && echo -e "  Filter: severity = ${BOLD}${SEV_FILTER}${NC}"
echo

# ── Verify dependencies ───────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  echo -e "${RED}python3 required but not found.${NC}"; exit 1
fi

if ! curl -s "${OLLAMA_URL}/api/tags" &>/dev/null; then
  echo -e "${RED}Ollama not reachable at ${OLLAMA_URL}${NC}"
  echo -e "${DIM}Start it with: ollama serve${NC}"; exit 1
fi

if [[ ! -f "$FINDINGS_FILE" ]]; then
  echo -e "${RED}No findings file found at: ${FINDINGS_FILE}${NC}"
  echo -e "${DIM}Run ubuntu_audit.sh first to generate findings.${NC}"; exit 1
fi

# ── Verify model is available ─────────────────────────────────────────────────
AVAILABLE_MODELS=$(curl -s "${OLLAMA_URL}/api/tags" | python3 -c "
import sys,json
data=json.load(sys.stdin)
print('\n'.join(m['name'] for m in data.get('models',[])))
" 2>/dev/null)

if ! echo "$AVAILABLE_MODELS" | grep -qF "$MODEL"; then
  echo -e "${YELLOW}Model '${MODEL}' not found. Available models:${NC}"
  echo "$AVAILABLE_MODELS" | sed 's/^/  /'
  echo
  read -rp "$(echo -e "${BOLD}Enter model name to use:${NC} ")" MODEL
  echo
fi

mkdir -p "$REPORT_DIR"
log_action "=== Remediation session started | model=$MODEL | dry_run=$DRY_RUN ==="

# ── Load findings ─────────────────────────────────────────────────────────────
AUDIT_DATE=$(python3 -c "import json; d=json.load(open('$FINDINGS_FILE')); print(d.get('audit_date','unknown'))" 2>/dev/null)
HOSTNAME_AUD=$(python3 -c "import json; d=json.load(open('$FINDINGS_FILE')); print(d.get('hostname','unknown'))" 2>/dev/null)

echo -e "  ${DIM}Audit date : ${AUDIT_DATE}${NC}"
echo -e "  ${DIM}Host       : ${HOSTNAME_AUD}${NC}"
echo -e "  ${DIM}Log        : ${REMEDIATION_LOG}${NC}"
echo

# Extract actionable findings (CRITICAL, HIGH, MEDIUM) sorted by severity weight
FINDINGS_JSON=$(python3 << 'PYEOF'
import json, sys

SEVERITY_ORDER = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3}
SEV_FILTER = __import__('os').environ.get('SEV_FILTER', '')

with open(__import__('os').environ['FINDINGS_FILE']) as f:
    data = json.load(f)

findings = data.get('findings', [])

# Filter severity
if SEV_FILTER:
    findings = [f for f in findings if f['severity'] == SEV_FILTER]
else:
    findings = [f for f in findings if f['severity'] in ('CRITICAL', 'HIGH', 'MEDIUM')]

# Sort: CRITICAL first
findings.sort(key=lambda x: SEVERITY_ORDER.get(x['severity'], 99))

print(json.dumps(findings))
PYEOF
)

TOTAL=$(echo "$FINDINGS_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")

if [[ "$TOTAL" -eq 0 ]]; then
  echo -e "${GREEN}No actionable findings in the specified severity range. Nothing to remediate.${NC}"
  exit 0
fi

echo -e "${BOLD}Found ${TOTAL} finding(s) to remediate.${NC}"
echo -e "${DIM}Controls: [y] apply  [n] skip  [e] edit command  [s] ask follow-up  [q] quit${NC}"
echo

APPLIED=0; SKIPPED=0; EDITED=0

# ── ask_ollama <prompt> ───────────────────────────────────────────────────────
ask_ollama() {
  local prompt="$1"
  local response
  response=$(curl -s "${OLLAMA_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "
import json, sys
payload = {
    'model': '${MODEL}',
    'prompt': sys.argv[1],
    'stream': False,
    'options': {'temperature': 0.1, 'num_predict': 400}
}
print(json.dumps(payload))
" "$prompt")" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('response','').strip())" 2>/dev/null)
  echo "$response"
}

# ── Strip markdown fences from LLM output ────────────────────────────────────
clean_command() {
  python3 -c "
import sys, re
text = sys.stdin.read().strip()
# Remove markdown code blocks
text = re.sub(r'\`\`\`(?:bash|sh)?\s*', '', text)
text = re.sub(r'\`\`\`', '', text)
# Remove single backtick wrapping
text = text.strip('\`')
# Take only the first non-empty meaningful line(s) — stop at explanations
lines = []
for line in text.splitlines():
    l = line.strip()
    if not l: continue
    # Stop if we hit a prose explanation after getting a command
    if lines and not l.startswith('#') and not any(l.startswith(c) for c in ['sudo','apt','systemctl','sed','echo','chmod','chown','ufw','sysctl','rm','cp','mv','nano','vi','redis','mysql','pg','docker','git']):
        if len(lines) >= 1:
            break
    lines.append(l)
print('\n'.join(lines))
"
}

# ── confirm_and_run <command> <finding_msg> <severity> ───────────────────────
confirm_and_run() {
  local cmd="$1" msg="$2" sev="$3"
  local color
  color=$(sev_color "$sev")

  echo -e "\n  ${color}[${sev}]${NC} ${BOLD}${msg}${NC}"
  echo -e "  ${DIM}─────────────────────────────────────────────────────────${NC}"
  echo -e "  ${CYAN}Suggested command:${NC}"
  echo -e "  ${BOLD}${cmd}${NC}"
  echo

  if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY RUN] Would execute the above command.${NC}"
    log_action "DRY_RUN | $sev | $msg | CMD: $cmd"
    SKIPPED=$((SKIPPED+1))
    return
  fi

  while true; do
    read -rp "$(echo -e "  ${BOLD}Apply? [y/n/e/s/q]:${NC} ")" choice
    case "${choice,,}" in
      y)
        echo -e "  ${GREEN}Executing...${NC}"
        log_action "APPLY | $sev | $msg | CMD: $cmd"
        if eval "$cmd"; then
          echo -e "  ${LGREEN}Done.${NC}"
          log_action "SUCCESS | $cmd"
        else
          echo -e "  ${RED}Command returned non-zero exit. Check output above.${NC}"
          log_action "FAILED | $cmd"
        fi
        APPLIED=$((APPLIED+1))
        break ;;
      n)
        echo -e "  ${DIM}Skipped.${NC}"
        log_action "SKIP | $sev | $msg"
        SKIPPED=$((SKIPPED+1))
        break ;;
      e)
        echo -e "  ${DIM}Edit the command (blank = keep original):${NC}"
        read -rp "  > " new_cmd
        if [[ -n "$new_cmd" ]]; then
          cmd="$new_cmd"
        fi
        echo -e "  ${CYAN}Updated command:${NC} ${BOLD}${cmd}${NC}"
        EDITED=$((EDITED+1))
        # loop back to ask again
        ;;
      s)
        read -rp "$(echo -e "  ${BOLD}Follow-up question:${NC} ")" followup
        echo -e "  ${DIM}Asking ${MODEL}...${NC}"
        FOLLOW_RESP=$(ask_ollama "Ubuntu 24.04 security context. Finding: '${msg}'. Follow-up question: ${followup}. Be concise.")
        echo -e "\n  ${CYAN}${MODEL}:${NC} ${FOLLOW_RESP}\n"
        ;;
      q)
        echo -e "\n  ${YELLOW}Quitting remediation session.${NC}"
        log_action "USER QUIT after $APPLIED applied, $SKIPPED skipped"
        echo -e "\n  ${BOLD}Session summary:${NC} Applied=${APPLIED}  Skipped=${SKIPPED}  Log=${REMEDIATION_LOG}"
        exit 0 ;;
      *)
        echo -e "  ${DIM}Invalid choice. Use y/n/e/s/q${NC}" ;;
    esac
  done
}

# ── Main remediation loop ─────────────────────────────────────────────────────
INDEX=0
while IFS= read -r finding; do
  SEV=$(echo "$finding"    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['severity'])")
  MSG=$(echo "$finding"    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['message'])")
  DETAIL=$(echo "$finding" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('detail',''))")
  SECTION=$(echo "$finding" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('section',''))")
  INDEX=$((INDEX+1))

  color=$(sev_color "$SEV")
  echo -e "${DIM}─── Finding ${INDEX}/${TOTAL} ─────────────────────────────────────────────────${NC}"
  echo -e "  Section: ${SECTION}"

  # Build prompt for Ollama
  PROMPT="You are a Linux security engineer. System: Ubuntu 24.04 LTS.

Security finding: ${MSG}
Hint from audit tool: ${DETAIL}

Task: Provide the EXACT shell command(s) to remediate this finding on Ubuntu 24.04.
Rules:
- Output ONLY the shell command(s), no explanations, no markdown formatting
- Use 'sudo' where root is required
- NEVER suggest opening an editor (nano, vi, vim, gedit) — use sed, tee, or echo to make file changes
- Prefer non-destructive, reversible commands where possible
- If multiple commands are needed, put each on its own line
- If the fix requires manual intervention or rebooting, start with: # MANUAL:"

  echo -e "  ${DIM}Asking ${MODEL} for remediation...${NC}"
  RAW_CMD=$(ask_ollama "$PROMPT")
  CMD=$(echo "$RAW_CMD" | clean_command)

  if [[ -z "$CMD" ]]; then
    echo -e "  ${YELLOW}Model returned no command. Falling back to audit hint.${NC}"
    CMD="${DETAIL:-# No automatic fix available — review manually}"
  fi

  # If LLM flagged it as manual, just inform and skip
  if [[ "$CMD" == "# MANUAL:"* ]]; then
    echo -e "  ${YELLOW}Manual intervention required:${NC}"
    echo -e "  ${DIM}${CMD#\# MANUAL:}${NC}"
    log_action "MANUAL | $SEV | $MSG"
    SKIPPED=$((SKIPPED+1))
    echo
    continue
  fi

  confirm_and_run "$CMD" "$MSG" "$SEV"
  echo

done < <(echo "$FINDINGS_JSON" | python3 -c "
import json, sys
findings = json.load(sys.stdin)
for f in findings:
    print(json.dumps(f))
")

# ── Final summary ─────────────────────────────────────────────────────────────
echo -e "\n${CYAN}${BOLD}━━━  REMEDIATION COMPLETE  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${LGREEN}Applied : ${APPLIED}${NC}"
echo -e "  ${YELLOW}Skipped : ${SKIPPED}${NC}"
echo -e "  ${BLUE}Edited  : ${EDITED}${NC}"
echo -e "\n  ${DIM}Full session log: ${REMEDIATION_LOG}${NC}"
echo -e "  ${DIM}Re-run audit to verify: secsuite audit run${NC}\n"

log_action "=== Session ended | applied=$APPLIED skipped=$SKIPPED ==="
