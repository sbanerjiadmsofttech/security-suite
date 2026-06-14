#!/usr/bin/env bash
# =============================================================================
#  ubuntu_audit.sh — Ubuntu 24.04 LTS Security Audit
#  Checks: known CVEs, local hardening, network exposure, secsuite scan
#  Author: TheSecuredAnalyst (via Security Suite)
# =============================================================================

set -uo pipefail

SECSUITE="$(command -v secsuite 2>/dev/null)"
REPORT_DIR="${HOME}/.secsuite/audit_reports"
REPORT_DATE=$(date +%Y%m%d_%H%M%S)
HTML_REPORT="${REPORT_DIR}/ubuntu_audit_${REPORT_DATE}.html"
LOG_FILE="${REPORT_DIR}/ubuntu_audit_${REPORT_DATE}.log"

mkdir -p "$REPORT_DIR"

# ── Terminal colours ──────────────────────────────────────────────────────────
RED='\033[0;31m'; LRED='\033[1;31m'
GREEN='\033[0;32m'; LGREEN='\033[1;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# ── Counters ──────────────────────────────────────────────────────────────────
CRITICAL=0; HIGH=0; MEDIUM=0; LOW=0; PASS=0

# ── HTML accumulator ──────────────────────────────────────────────────────────
HTML_BODY=""

# ── JSON findings (one per line, written to file at end) ──────────────────────
FINDINGS_JSONL=""
CURRENT_SECTION="General"
JSON_FILE="${REPORT_DIR}/findings_${REPORT_DATE}.json"

json_finding() {
  local sev="$1" msg="$2" detail="${3:-}"
  # escape double quotes for embedding in JSON
  local msg_esc detail_esc
  msg_esc=$(printf '%s' "$msg"    | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  detail_esc=$(printf '%s' "$detail" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  local section_esc
  section_esc=$(printf '%s' "$CURRENT_SECTION" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  FINDINGS_JSONL+='{"severity":"'"$sev"'","section":'"$section_esc"',"message":'"$msg_esc"',"detail":'"$detail_esc"'}'$'\n'
}

# ── Helpers ───────────────────────────────────────────────────────────────────
log()       { echo -e "$*" | tee -a "$LOG_FILE"; }
section()   { CURRENT_SECTION="$1"; log "\n${CYAN}${BOLD}━━━  $1  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; html_section "$1"; }
pass()      { PASS=$((PASS+1));     log "  ${GREEN}[PASS]${NC}  $1"; html_row "PASS"     "$1" "$2"; }
info()      {                       log "  ${BLUE}[INFO]${NC}  $1"; html_row "INFO"     "$1" "$2"; }
low()       { LOW=$((LOW+1));       log "  ${YELLOW}[LOW]${NC}   $1"; html_row "LOW"      "$1" "$2"; json_finding "LOW"      "$1" "$2"; }
medium()    { MEDIUM=$((MEDIUM+1)); log "  ${YELLOW}[MEDIUM]${NC} $1"; html_row "MEDIUM"   "$1" "$2"; json_finding "MEDIUM"   "$1" "$2"; }
high()      { HIGH=$((HIGH+1));     log "  ${RED}[HIGH]${NC}  $1"; html_row "HIGH"     "$1" "$2"; json_finding "HIGH"     "$1" "$2"; }
critical()  { CRITICAL=$((CRITICAL+1)); log "  ${LRED}[CRIT]${NC}  $1"; html_row "CRITICAL" "$1" "$2"; json_finding "CRITICAL" "$1" "$2"; }

html_section() {
  HTML_BODY+="<tr><td colspan='3' class='section'>$1</td></tr>\n"
}
html_row() {
  local sev="$1" msg="$2" detail="${3:-}"
  local color
  case "$sev" in
    CRITICAL) color="#ff4444" ;;
    HIGH)     color="#ff8800" ;;
    MEDIUM)   color="#ffcc00" ;;
    LOW)      color="#99cc00" ;;
    PASS)     color="#00cc44" ;;
    *)        color="#4488ff" ;;
  esac
  HTML_BODY+="<tr><td><span class='badge' style='background:${color}'>${sev}</span></td><td>${msg}</td><td class='detail'>${detail}</td></tr>\n"
}

ver_lt() {
  # ver_lt "installed_version" "fixed_version" — returns 0 (true) if installed < fixed
  [ "$(printf '%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ] && [ "$1" != "$2" ]
}

# ── Banner ────────────────────────────────────────────────────────────────────
clear
log "${CYAN}${BOLD}"
log "  ██████╗ ███████╗ ██████╗███████╗██╗   ██╗██╗████████╗███████╗"
log "  ██╔════╝██╔════╝██╔════╝██╔════╝██║   ██║██║╚══██╔══╝██╔════╝"
log "  ███████╗█████╗  ██║     ███████╗██║   ██║██║   ██║   █████╗  "
log "  ╚════██║██╔══╝  ██║     ╚════██║██║   ██║██║   ██║   ██╔══╝  "
log "  ███████║███████╗╚██████╗███████║╚██████╔╝██║   ██║   ███████╗"
log "  ╚══════╝╚══════╝ ╚═════╝╚══════╝ ╚═════╝ ╚═╝   ╚═╝   ╚══════╝${NC}"
log "${BOLD}  Ubuntu 24.04 LTS Security Audit  —  $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
log "${DIM}  Report: $HTML_REPORT${NC}"
log "${DIM}  Log:    $LOG_FILE${NC}\n"

# =============================================================================
# 1. SYSTEM INFORMATION
# =============================================================================
section "1. SYSTEM INFORMATION"

HOSTNAME=$(hostname)
KERNEL=$(uname -r)
OS=$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')
UPTIME=$(uptime -p)
LAST_BOOT=$(who -b 2>/dev/null | awk '{print $3,$4}')
CPU=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
MEM=$(free -h | awk '/Mem/{print $2}')
IP=$(hostname -I | awk '{print $1}')

info "Hostname:    $HOSTNAME"              ""
info "OS:          $OS"                    ""
info "Kernel:      $KERNEL"                ""
info "IP Address:  $IP"                    ""
info "Uptime:      $UPTIME (boot: $LAST_BOOT)" ""
info "CPU:         $CPU"                   ""
info "RAM:         $MEM"                   ""

# =============================================================================
# 2. CVE VERSION CHECKS
# =============================================================================
section "2. KNOWN CVE VERSION CHECKS"

# ── CVE-2024-6387 : regreSSHion (OpenSSH RCE) ─────────────────────────────────
SSH_SERVER_VER=$(dpkg -l openssh-server 2>/dev/null | awk '/^ii/{print $3}' | head -1)
if [[ -z "$SSH_SERVER_VER" ]]; then
  pass "CVE-2024-6387 (regreSSHion): openssh-server not installed" "No remote SSH attack surface"
else
  # Fixed in 1:9.8p1-1 (Ubuntu: 1:9.6p1-3ubuntu13.5 backport patch)
  # Ubuntu backported the fix to 1:9.6p1-3ubuntu13.5
  SSH_EPOCH_VER=$(echo "$SSH_SERVER_VER" | grep -oP '\d+\.\d+p\d+' | head -1)
  SSH_UBUNTU_REV=$(echo "$SSH_SERVER_VER" | grep -oP 'ubuntu\K[\d.]+' | head -1)
  FIXED_MINOR=5
  if [[ "${SSH_UBUNTU_REV%%.*}" -ge "${FIXED_MINOR}" ]]; then
    pass "CVE-2024-6387 (regreSSHion): openssh-server ${SSH_SERVER_VER} — patched" "Ubuntu backport >= 13.5"
  else
    critical "CVE-2024-6387 (regreSSHion): openssh-server ${SSH_SERVER_VER} — VULNERABLE" \
      "Race condition RCE (CVSS 8.1). Upgrade: sudo apt install --only-upgrade openssh-server"
  fi
fi

# ── CVE-2024-47176 / 47076 / 47175 / 47177 : CUPS Remote Code Execution ──────
CUPS_VER=$(dpkg -l cups 2>/dev/null | awk '/^ii/{print $3}' | head -1)
CUPSD_ACTIVE=$(systemctl is-active cups 2>/dev/null || echo "inactive")
CUPSBROWSE_ACTIVE=$(systemctl is-active cups-browsed 2>/dev/null || echo "inactive")

if [[ "$CUPSBROWSE_ACTIVE" == "active" ]]; then
  # Check if cups-browsed is listening on UDP 631
  CUPS_UDP=$(ss -ulnp4 | grep ':631' || true)
  # Fixed in cups 2.4.7-1.2ubuntu7.3 for Ubuntu 24.04
  CUPS_EPOCH=$(echo "$CUPS_VER" | grep -oP '[\d.]+ubuntu\K[\d.]+' | head -1)
  if [[ -n "$CUPS_VER" ]]; then
    # Extract ubuntu revision number (e.g., 7.9 from 2.4.7-1.2ubuntu7.9)
    CUPS_UREV=$(echo "$CUPS_VER" | grep -oP 'ubuntu7\.\K\d+' | head -1)
    if [[ -n "$CUPS_UREV" && "$CUPS_UREV" -ge 3 ]]; then
      pass "CVE-2024-47176 (CUPS RCE): cups ${CUPS_VER} — patched" \
        "cups-browsed active but cups version patched (ubuntu7.${CUPS_UREV} >= ubuntu7.3)"
      medium "cups-browsed service is running — consider disabling if not needed" \
        "sudo systemctl disable --now cups-browsed  (reduces attack surface)"
    else
      critical "CVE-2024-47176 (CUPS RCE): cups ${CUPS_VER} — VULNERABLE" \
        "cups-browsed active. Unauthenticated RCE via UDP 631. Patch: sudo apt upgrade cups cups-browsed"
    fi
  fi
else
  pass "CVE-2024-47176 (CUPS RCE): cups-browsed is not running" "No attack surface for this CVE"
fi

# ── CVE-2024-3094 : XZ backdoor ───────────────────────────────────────────────
XZ_VER=$(dpkg -l xz-utils 2>/dev/null | awk '/^ii/{print $3}' | head -1)
if [[ "$XZ_VER" == *"really5.4"* ]]; then
  pass "CVE-2024-3094 (XZ backdoor): xz-utils ${XZ_VER} — safe" \
    "Ubuntu shipped 5.6.1+really5.4.5: backdoored binary replaced with 5.4.5"
elif [[ "$XZ_VER" == 5.6.[01]* ]]; then
  critical "CVE-2024-3094 (XZ backdoor): xz-utils ${XZ_VER} — BACKDOORED" \
    "CRITICAL: OpenSSH private key exfiltration backdoor. Remove and reinstall immediately."
else
  pass "CVE-2024-3094 (XZ backdoor): xz-utils ${XZ_VER} — not affected" ""
fi

# ── CVE-2023-4911 : Looney Tunables (glibc buffer overflow) ───────────────────
GLIBC_VER=$(dpkg -l libc6:amd64 2>/dev/null | awk '/^ii/{print $3}' | head -1)
GLIBC_UREV=$(echo "$GLIBC_VER" | grep -oP 'ubuntu8\.\K\d+' | head -1)
if [[ -n "$GLIBC_UREV" && "$GLIBC_UREV" -ge 3 ]]; then
  pass "CVE-2023-4911 (Looney Tunables): libc6 ${GLIBC_VER} — patched" \
    "Fixed in ubuntu8.3, installed ubuntu8.${GLIBC_UREV}"
else
  high "CVE-2023-4911 (Looney Tunables): libc6 ${GLIBC_VER} — VULNERABLE" \
    "Local privilege escalation via ld.so buffer overflow. Upgrade: sudo apt upgrade libc6"
fi

# ── CVE-2024-1086 : Linux kernel nf_tables use-after-free ────────────────────
KVER_MAJOR=$(uname -r | cut -d. -f1)
KVER_MINOR=$(uname -r | cut -d. -f2)
KVER_PATCH=$(uname -r | cut -d. -f3 | cut -d- -f1)
# Fixed in 6.6.14 / 6.7.2 / 6.8+ (Ubuntu 24.04 ships 6.8 and is patched)
if [[ "$KVER_MAJOR" -eq 6 && "$KVER_MINOR" -ge 8 ]]; then
  pass "CVE-2024-1086 (kernel nf_tables UAF): kernel ${KERNEL} — patched" \
    "Ubuntu 24.04 ships kernel 6.8+ with fix included"
elif [[ "$KVER_MAJOR" -eq 6 && "$KVER_MINOR" -eq 6 && "$KVER_PATCH" -ge 14 ]]; then
  pass "CVE-2024-1086 (kernel nf_tables UAF): kernel ${KERNEL} — patched" ""
else
  high "CVE-2024-1086 (kernel nf_tables UAF): kernel ${KERNEL} — check required" \
    "Local privilege escalation. Verify: sudo apt upgrade linux-image-generic"
fi

# ── CVE-2023-32629 / CVE-2023-2640 : Ubuntu overlayfs privesc ────────────────
# Fixed in Ubuntu kernel 6.2.0-1017.17 / 6.5.0-14.14 / 6.8+
if [[ "$KVER_MAJOR" -eq 6 && "$KVER_MINOR" -ge 8 ]]; then
  pass "CVE-2023-32629/2640 (overlayfs privesc): kernel ${KERNEL} — patched" \
    "Fixes included in Ubuntu 6.8+ kernels"
else
  high "CVE-2023-32629/2640 (Ubuntu overlayfs privesc): kernel ${KERNEL} — verify" \
    "Ubuntu-specific overlay FS privilege escalation. Update kernel."
fi

# ── CVE-2024-21626 : runc container escape (Leaky Vessels) ───────────────────
RUNC_VER=$(runc --version 2>/dev/null | awk 'NR==1{print $3}' || dpkg -l runc 2>/dev/null | awk '/^ii/{print $3}')
if [[ -z "$RUNC_VER" ]]; then
  info "CVE-2024-21626 (runc Leaky Vessels): runc not installed" ""
else
  # Fixed in runc 1.1.12
  if ver_lt "$RUNC_VER" "1.1.12"; then
    high "CVE-2024-21626 (runc Leaky Vessels): runc ${RUNC_VER} — VULNERABLE" \
      "Container escape via file descriptor leak. Fix: sudo apt upgrade runc"
  else
    pass "CVE-2024-21626 (runc Leaky Vessels): runc ${RUNC_VER} — patched" ""
  fi
fi

# ── CVE-2024-32002 : Git recursive clone hooks ────────────────────────────────
GIT_VER=$(git --version 2>/dev/null | awk '{print $3}')
if [[ -n "$GIT_VER" ]]; then
  if ver_lt "$GIT_VER" "2.45.1"; then
    medium "CVE-2024-32002 (Git hooks on clone): git ${GIT_VER} — check" \
      "Malicious repos can execute hooks on git clone. Patch: sudo apt upgrade git"
  else
    pass "CVE-2024-32002 (Git hooks on clone): git ${GIT_VER} — patched" ""
  fi
fi

# ── Snap CVE check ────────────────────────────────────────────────────────────
SNAPD_VER=$(dpkg -l snapd 2>/dev/null | awk '/^ii/{print $3}' | head -1)
if [[ -n "$SNAPD_VER" ]]; then
  info "snapd ${SNAPD_VER} installed — monitor USN advisories for snap sandbox escapes" ""
fi

# ── Unpatched packages ────────────────────────────────────────────────────────
UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo 0)
if [[ "$UPGRADABLE" -gt 0 ]]; then
  medium "${UPGRADABLE} upgradable packages (may include security patches)" \
    "Run: sudo apt update && sudo apt upgrade"
else
  pass "All packages up to date" ""
fi

# =============================================================================
# 3. NETWORK EXPOSURE
# =============================================================================
section "3. NETWORK EXPOSURE"

# ── UFW Firewall ──────────────────────────────────────────────────────────────
UFW_STATUS=$(ufw status 2>/dev/null | head -1 || echo "unknown")
if echo "$UFW_STATUS" | grep -qi "active"; then
  pass "UFW firewall: ${UFW_STATUS}" ""
else
  high "UFW firewall is INACTIVE — host is fully exposed to network" \
    "Enable: sudo ufw enable && sudo ufw default deny incoming && sudo ufw allow ssh"
fi

# ── Network-facing TCP services ───────────────────────────────────────────────
log "\n  ${BOLD}Network-exposed TCP ports (0.0.0.0 / ::):${NC}"
EXPOSED_TCP=$(ss -tlnp4 2>/dev/null | awk 'NR>1 && $4 !~ /^127\./ && $4 !~ /^192\.168\.122\./ {print $4, $6}')
while IFS= read -r line; do
  PORT=$(echo "$line" | grep -oP ':\K\d+')
  PROC=$(echo "$line" | grep -oP 'users:\(\("?\K[^"]+')
  case "$PORT" in
    22)   info "  Port 22/tcp (SSH): ${PROC}" "" ;;
    80)   medium "  Port 80/tcp (HTTP): ${PROC} — plaintext web traffic exposed" \
            "Consider HTTPS redirect and reviewing what is served" ;;
    443)  info   "  Port 443/tcp (HTTPS): ${PROC}" "" ;;
    8000|8001) medium "  Port ${PORT}/tcp (dev server?): ${PROC} — exposed to network" \
            "Dev servers should not bind 0.0.0.0 in production" ;;
    7070) medium "  Port 7070/tcp: ${PROC} — unusual port exposed to network" \
            "Identify this service: ss -tlnp | grep 7070" ;;
    902)  info   "  Port 902/tcp (VMware Auth): ${PROC}" \
            "VMware agent port — restrict if not needed remotely" ;;
    *)    medium "  Port ${PORT}/tcp: ${PROC} — exposed to network" \
            "Verify this service should be publicly accessible" ;;
  esac
done <<< "$EXPOSED_TCP"

# ── Redis unauthenticated ─────────────────────────────────────────────────────
REDIS_PING=$(redis-cli -h 127.0.0.1 -p 6379 ping 2>/dev/null || echo "")
REDIS_PASS=$(redis-cli -h 127.0.0.1 -p 6379 CONFIG GET requirepass 2>/dev/null | tail -1 || echo "")
if [[ "$REDIS_PING" == "PONG" ]]; then
  if [[ -z "$REDIS_PASS" || "$REDIS_PASS" == "requirepass" ]]; then
    critical "Redis (127.0.0.1:6379) running WITHOUT authentication" \
      "Any local process can read/write Redis data. Set: requirepass in /etc/redis/redis.conf — sudo systemctl restart redis"
  else
    pass "Redis (127.0.0.1:6379): password authentication enabled" ""
  fi
  # Check if Redis is also bound to a non-loopback interface
  REDIS_BIND=$(grep -E '^bind' /etc/redis/redis.conf 2>/dev/null || echo "")
  if echo "$REDIS_BIND" | grep -qvE '127\.0\.0\.1|::1|localhost'; then
    high "Redis bind config may expose to network: ${REDIS_BIND}" \
      "Ensure Redis is only accessible on localhost"
  fi
fi

# ── MySQL exposure ────────────────────────────────────────────────────────────
MYSQL_LISTEN=$(ss -tlnp4 | grep ':3306' || true)
if [[ -n "$MYSQL_LISTEN" ]]; then
  MYSQL_ADDR=$(echo "$MYSQL_LISTEN" | awk '{print $4}')
  if echo "$MYSQL_ADDR" | grep -q '0\.0\.0\.0'; then
    high "MySQL exposed on 0.0.0.0:3306 — accessible from network" \
      "Restrict: bind-address = 127.0.0.1 in /etc/mysql/mysql.conf.d/mysqld.cnf"
  else
    pass "MySQL bound to localhost only (${MYSQL_ADDR})" ""
  fi
fi

# ── PostgreSQL exposure ───────────────────────────────────────────────────────
PG_LISTEN=$(ss -tlnp4 | grep ':5432' || true)
if [[ -n "$PG_LISTEN" ]]; then
  PG_ADDR=$(echo "$PG_LISTEN" | awk '{print $4}')
  if echo "$PG_ADDR" | grep -q '0\.0\.0\.0'; then
    high "PostgreSQL exposed on 0.0.0.0:5432 — accessible from network" \
      "Restrict listen_addresses = 'localhost' in postgresql.conf"
  else
    pass "PostgreSQL bound to localhost only (${PG_ADDR})" ""
  fi
fi

# ── Anonymous/world-readable mDNS ────────────────────────────────────────────
MDNS=$(ss -ulnp4 | grep ':5353' || true)
if [[ -n "$MDNS" ]]; then
  info "mDNS (port 5353 UDP) is active — leaks hostname/service info on LAN" \
    "Can be used for reconnaissance. Disable avahi-daemon if not needed."
fi

# =============================================================================
# 4. KERNEL HARDENING
# =============================================================================
section "4. KERNEL HARDENING"

check_sysctl() {
  local key="$1" expected="$2" msg_pass="$3" msg_fail="$4" sev="${5:-medium}"
  local val
  val=$(sysctl -n "$key" 2>/dev/null || echo "unavailable")
  if [[ "$val" == "$expected" ]]; then
    pass "${msg_pass} (${key}=${val})" ""
  else
    $sev "${msg_fail} (${key}=${val}, expected ${expected})" \
      "Fix: sudo sysctl -w ${key}=${expected}  — persist in /etc/sysctl.d/99-hardening.conf"
  fi
}

check_sysctl "kernel.randomize_va_space"    "2" "ASLR full randomisation enabled"          "ASLR not fully enabled"        medium
check_sysctl "kernel.yama.ptrace_scope"     "1" "ptrace scope restricted to parent process" "ptrace unrestricted — allows process inspection attacks" medium
check_sysctl "kernel.unprivileged_bpf_disabled" "2" "Unprivileged BPF disabled" \
  "Unprivileged eBPF enabled — kernel exploit surface increased" high
check_sysctl "kernel.kptr_restrict"         "2" "Kernel pointer restriction enabled"        "Kernel pointers exposed in /proc — aids exploit development" medium
check_sysctl "net.ipv4.tcp_syncookies"      "1" "SYN cookie protection enabled"             "SYN flood protection disabled"  medium
check_sysctl "net.ipv4.conf.all.accept_redirects" "0" "ICMP redirect acceptance disabled"  "ICMP redirects accepted — routing manipulation risk"  medium
check_sysctl "net.ipv4.conf.all.send_redirects"   "0" "ICMP redirect sending disabled"     "This host sends ICMP redirects — potential routing issue" low
check_sysctl "net.ipv4.conf.all.rp_filter" "1" "Reverse path filtering enabled (spoofing protection)" "Reverse path filtering disabled — IP spoofing possible" medium
check_sysctl "fs.protected_symlinks"        "1" "Symlink attack protection enabled"         "Symlink protection disabled — /tmp race condition attacks possible" medium
check_sysctl "fs.protected_hardlinks"       "1" "Hardlink attack protection enabled"        "Hardlink protection disabled" medium
check_sysctl "kernel.dmesg_restrict"        "1" "dmesg restricted to root"                  "dmesg unrestricted — kernel addresses exposed to users" low

# ── Unprivileged user namespaces ──────────────────────────────────────────────
USERNS=$(sysctl -n kernel.unprivileged_userns_clone 2>/dev/null || echo "unavailable")
if [[ "$USERNS" == "1" ]]; then
  medium "Unprivileged user namespace cloning ENABLED (kernel.unprivileged_userns_clone=1)" \
    "Required by Chrome/Docker but increases kernel attack surface. Disable if not needed: sysctl -w kernel.unprivileged_userns_clone=0"
else
  pass "Unprivileged user namespace cloning disabled" ""
fi

# ── Core dumps ────────────────────────────────────────────────────────────────
CORE_PATTERN=$(cat /proc/sys/kernel/core_pattern 2>/dev/null)
HARD_CORE=$(ulimit -Hc 2>/dev/null || echo "unavailable")
if [[ "$HARD_CORE" == "0" ]]; then
  pass "Core dumps disabled via ulimit" ""
else
  low "Core dumps may be enabled (hard limit: ${HARD_CORE}) — core pattern: ${CORE_PATTERN}" \
    "Core dumps can leak sensitive memory. Add to /etc/security/limits.conf: * hard core 0"
fi

# ── Secure Boot ──────────────────────────────────────────────────────────────
SB=$(mokutil --sb-state 2>/dev/null || echo "unavailable")
if echo "$SB" | grep -qi "enabled"; then
  pass "Secure Boot: enabled" ""
elif echo "$SB" | grep -qi "disabled"; then
  low "Secure Boot: disabled" "Enable in BIOS/UEFI to prevent unsigned bootloader attacks"
else
  info "Secure Boot status: ${SB}" ""
fi

# =============================================================================
# 5. FILESYSTEM SECURITY
# =============================================================================
section "5. FILESYSTEM SECURITY"

# ── SUID / SGID binaries ──────────────────────────────────────────────────────
log "  ${BOLD}Scanning for SUID/SGID binaries (non-standard)...${NC}"
KNOWN_SUID=(
  /usr/bin/sudo /usr/bin/su /usr/bin/passwd /usr/bin/chfn /usr/bin/chsh
  /usr/bin/newgrp /usr/bin/gpasswd /usr/bin/mount /usr/bin/umount
  /usr/bin/ping /usr/bin/fusermount3 /usr/lib/dbus-1.0/dbus-daemon-launch-helper
  /usr/lib/openssh/ssh-keysign /usr/sbin/pppd /usr/bin/pkexec
  /usr/bin/at /usr/lib/x86_64-linux-gnu/utempter/utempter
  /usr/lib/polkit-1/polkit-agent-helper-1 /sbin/unix_chkpwd
  /usr/bin/write /usr/bin/wall /usr/bin/expiry /usr/bin/chage
  /usr/bin/ssh-agent /usr/lib/snapd/snap-confine
)
SUID_FINDINGS=()
while IFS= read -r f; do
  known=false
  for k in "${KNOWN_SUID[@]}"; do
    [[ "$f" == "$k" ]] && known=true && break
  done
  $known || SUID_FINDINGS+=("$f")
done < <(find /usr /bin /sbin /opt -xdev -perm /4000 -o -perm /2000 2>/dev/null | sort)

if [[ ${#SUID_FINDINGS[@]} -eq 0 ]]; then
  pass "No unexpected SUID/SGID binaries found outside known list" ""
else
  for f in "${SUID_FINDINGS[@]}"; do
    medium "Unexpected SUID/SGID binary: ${f}" \
      "Investigate: ls -la ${f}  — Remove SUID if not needed: sudo chmod -s ${f}"
  done
fi

# ── World-writable files in /etc ──────────────────────────────────────────────
WW_ETC=$(find /etc -xdev -maxdepth 3 -perm /o+w -not -type l 2>/dev/null | head -20)
if [[ -z "$WW_ETC" ]]; then
  pass "No world-writable files found in /etc" ""
else
  while IFS= read -r f; do
    high "World-writable file in /etc: ${f}" \
      "Fix permissions: sudo chmod o-w ${f}"
  done <<< "$WW_ETC"
fi

# ── /etc/passwd and /etc/shadow permissions ────────────────────────────────────
PASSWD_PERM=$(stat -c "%a %U %G" /etc/passwd 2>/dev/null)
SHADOW_PERM=$(stat -c "%a %U %G" /etc/shadow 2>/dev/null)

[[ "$PASSWD_PERM" =~ ^644 ]] && pass "/etc/passwd permissions: ${PASSWD_PERM}" "" || \
  high "/etc/passwd permissions unusual: ${PASSWD_PERM}" "Expected 644 root root"
[[ "$SHADOW_PERM" =~ ^[06][04][04] ]] && pass "/etc/shadow permissions: ${SHADOW_PERM}" "" || \
  critical "/etc/shadow permissions too open: ${SHADOW_PERM}" \
    "Expected 640 or 000. Fix: sudo chmod 640 /etc/shadow"

# ── /tmp noexec ───────────────────────────────────────────────────────────────
TMP_OPTS=$(findmnt -no OPTIONS /tmp 2>/dev/null || echo "")
if echo "$TMP_OPTS" | grep -q 'noexec'; then
  pass "/tmp mounted with noexec" ""
else
  medium "/tmp not mounted with noexec — exploits can be staged and executed from /tmp" \
    "Add to /etc/fstab: tmpfs /tmp tmpfs defaults,nosuid,nodev,noexec,mode=1777 0 0"
fi

# ── Sticky bit on /tmp ────────────────────────────────────────────────────────
TMP_STICKY=$(stat -c "%a" /tmp 2>/dev/null)
if [[ "${TMP_STICKY:0:1}" == "1" ]]; then
  pass "/tmp sticky bit set (${TMP_STICKY})" ""
else
  high "/tmp does NOT have sticky bit — users can delete each other's files" \
    "Fix: sudo chmod 1777 /tmp"
fi

# =============================================================================
# 6. USER AND AUTH SECURITY
# =============================================================================
section "6. USER AND AUTHENTICATION SECURITY"

# ── Accounts with UID 0 ───────────────────────────────────────────────────────
UID0=$(awk -F: '$3==0{print $1}' /etc/passwd)
UID0_COUNT=$(echo "$UID0" | wc -l)
if [[ "$UID0_COUNT" -eq 1 && "$UID0" == "root" ]]; then
  pass "Only root has UID 0" ""
else
  critical "Multiple accounts with UID 0: ${UID0}" \
    "Remove extra root-equivalent accounts immediately"
fi

# ── Accounts with empty passwords ────────────────────────────────────────────
EMPTY_PASS=$(awk -F: '($2 == "" || $2 == "!!" || $2 == "*") && NR>1 {print $1}' /etc/shadow 2>/dev/null || echo "")
# Filter only truly empty (no hash at all)
TRULY_EMPTY=$(awk -F: '$2 == "" {print $1}' /etc/shadow 2>/dev/null || echo "")
if [[ -z "$TRULY_EMPTY" ]]; then
  pass "No accounts with empty passwords" ""
else
  critical "Accounts with empty passwords: ${TRULY_EMPTY}" \
    "Set passwords immediately: sudo passwd <username>"
fi

# ── Sudoers NOPASSWD ──────────────────────────────────────────────────────────
NOPASSWD=$(grep -rh 'NOPASSWD' /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -v '^#' || true)
if [[ -z "$NOPASSWD" ]]; then
  pass "No NOPASSWD entries in sudoers" ""
else
  while IFS= read -r line; do
    medium "sudoers NOPASSWD entry: ${line}" \
      "NOPASSWD allows sudo without password — review if this is intentional"
  done <<< "$NOPASSWD"
fi

# ── Users in sudo/admin groups ────────────────────────────────────────────────
SUDO_USERS=$(getent group sudo 2>/dev/null | cut -d: -f4)
log "  ${DIM}sudo group members: ${SUDO_USERS}${NC}"

# ── SSH config hardening ──────────────────────────────────────────────────────
SSHD_CFG="/etc/ssh/sshd_config"
if [[ -f "$SSHD_CFG" ]]; then
  ROOT_LOGIN=$(sshd -T 2>/dev/null | grep -i 'permitrootlogin' | awk '{print $2}' || grep -iE '^PermitRootLogin' "$SSHD_CFG" | awk '{print $2}')
  EMPTY_PASS_SSH=$(sshd -T 2>/dev/null | grep -i 'permitemptypasswords' | awk '{print $2}' || grep -iE '^PermitEmptyPasswords' "$SSHD_CFG" | awk '{print $2}')
  PASSWD_AUTH=$(sshd -T 2>/dev/null | grep -i 'passwordauthentication' | awk '{print $2}' || grep -iE '^PasswordAuthentication' "$SSHD_CFG" | awk '{print $2}')
  X11_FWD=$(sshd -T 2>/dev/null | grep -i 'x11forwarding' | awk '{print $2}' || grep -iE '^X11Forwarding' "$SSHD_CFG" | awk '{print $2}')

  [[ "${ROOT_LOGIN,,}" =~ ^(no|prohibit-password)$ ]] && \
    pass "SSH PermitRootLogin: ${ROOT_LOGIN}" "" || \
    high "SSH PermitRootLogin: ${ROOT_LOGIN:-not set} — root login may be allowed" \
      "Set: PermitRootLogin no  in /etc/ssh/sshd_config"

  [[ "${EMPTY_PASS_SSH,,}" == "no" ]] && \
    pass "SSH PermitEmptyPasswords: no" "" || \
    critical "SSH PermitEmptyPasswords: ${EMPTY_PASS_SSH:-not set}" \
      "Set: PermitEmptyPasswords no  in /etc/ssh/sshd_config"

  [[ "${PASSWD_AUTH,,}" == "no" ]] && \
    pass "SSH PasswordAuthentication: no (key-only)" "" || \
    medium "SSH PasswordAuthentication: ${PASSWD_AUTH:-yes} — password logins enabled" \
      "Prefer key-only auth: PasswordAuthentication no"

  [[ "${X11_FWD,,}" == "no" ]] && \
    pass "SSH X11Forwarding: disabled" "" || \
    low "SSH X11Forwarding: ${X11_FWD:-yes} — enabled (attack surface for X11 hijacking)" \
      "Set: X11Forwarding no  in /etc/ssh/sshd_config"
else
  info "SSH server not installed — skipping sshd_config checks" ""
fi

# ── Recent failed logins ──────────────────────────────────────────────────────
FAILED=$(lastb 2>/dev/null | head -10 || journalctl -n 20 _SYSTEMD_UNIT=ssh.service 2>/dev/null | grep "Failed" | tail -10 || echo "")
if [[ -n "$FAILED" ]]; then
  FAIL_COUNT_SSH=$(echo "$FAILED" | wc -l)
  info "Recent failed login attempts: ${FAIL_COUNT_SSH} entries in lastb/journal" \
    "Review: sudo lastb | head -20"
fi

# ── fail2ban ──────────────────────────────────────────────────────────────────
if systemctl is-active fail2ban &>/dev/null; then
  pass "fail2ban is active — brute-force protection enabled" ""
else
  medium "fail2ban is not running" \
    "Install and enable: sudo apt install fail2ban && sudo systemctl enable --now fail2ban"
fi

# =============================================================================
# 7. SERVICE HARDENING
# =============================================================================
section "7. SERVICE HARDENING"

# ── Unattended upgrades ───────────────────────────────────────────────────────
if dpkg -l unattended-upgrades &>/dev/null && systemctl is-enabled unattended-upgrades &>/dev/null; then
  pass "unattended-upgrades enabled — automatic security patches active" ""
else
  medium "unattended-upgrades not enabled" \
    "Enable automatic security updates: sudo apt install unattended-upgrades && sudo dpkg-reconfigure -plow unattended-upgrades"
fi

# ── AppArmor ──────────────────────────────────────────────────────────────────
AA_STATUS=$(apparmor_status 2>/dev/null | head -3 || aa-status 2>/dev/null | head -3 || echo "unavailable")
if echo "$AA_STATUS" | grep -qi "profiles are in enforce mode"; then
  ENFORCE_N=$(echo "$AA_STATUS" | grep -oP '\d+ profiles are in enforce' | grep -oP '\d+')
  pass "AppArmor enabled — ${ENFORCE_N} profiles in enforce mode" ""
elif echo "$AA_STATUS" | grep -qi "apparmor module is loaded"; then
  medium "AppArmor loaded but check enforce vs. complain mode count" \
    "Review: sudo apparmor_status"
else
  high "AppArmor not active or unavailable" \
    "Enable: sudo systemctl enable --now apparmor"
fi

# ── CUPS service necessity ────────────────────────────────────────────────────
if systemctl is-active cups &>/dev/null; then
  info "CUPS printing service active — disable if no printers needed" \
    "sudo systemctl disable --now cups cups-browsed  (reduces attack surface)"
fi

# ── Docker security ───────────────────────────────────────────────────────────
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  # Check if Docker socket is world-readable
  DOCKER_SOCK_PERM=$(stat -c "%a %G" /var/run/docker.sock 2>/dev/null || echo "")
  DOCKER_GROUP=$(getent group docker 2>/dev/null | cut -d: -f4)
  if [[ -n "$DOCKER_GROUP" ]]; then
    info "Docker group members (equivalent to root): ${DOCKER_GROUP}" \
      "Docker group membership = effective root. Remove non-essential users."
  fi

  # Check if any containers are running in privileged mode
  PRIV_CONTAINERS=$(docker ps --quiet 2>/dev/null | xargs -r docker inspect --format '{{.Name}} privileged={{.HostConfig.Privileged}}' 2>/dev/null | grep 'privileged=true' || true)
  if [[ -n "$PRIV_CONTAINERS" ]]; then
    high "Privileged Docker containers running: ${PRIV_CONTAINERS}" \
      "Privileged containers have full host access. Remove --privileged flag."
  else
    pass "No privileged Docker containers detected" ""
  fi
fi

# ── Cron world-writable scripts ───────────────────────────────────────────────
WW_CRON=$(find /etc/cron* /var/spool/cron 2>/dev/null -perm /o+w -not -type l | head -10)
if [[ -z "$WW_CRON" ]]; then
  pass "No world-writable cron scripts found" ""
else
  while IFS= read -r f; do
    high "World-writable cron file: ${f}" "Fix: sudo chmod o-w ${f}"
  done <<< "$WW_CRON"
fi

# =============================================================================
# 8. SECSUITE NETWORK SCANS
# =============================================================================
section "8. SECSUITE NETWORK SCANS"

if [[ -z "$SECSUITE" ]]; then
  high "secsuite not found in PATH" "Activate the virtual environment: source venv/bin/activate"
else
  log "\n  ${CYAN}[secsuite] Scanning localhost open ports...${NC}"
  SS_PORTS=$("$SECSUITE" osint ports 127.0.0.1 --type quick 2>/dev/null | tail -30 || echo "scan failed")
  if echo "$SS_PORTS" | grep -qi "error\|failed"; then
    info "secsuite port scan encountered issues — check nmap installation" ""
  else
    while IFS= read -r line; do
      if echo "$line" | grep -qiE 'open|finding|HIGH|MEDIUM|CRITICAL'; then
        log "  ${DIM}${line}${NC}"
      fi
    done <<< "$SS_PORTS"
    info "secsuite port scan completed — full results in log" "See $LOG_FILE"
  fi

  # ── HTTP headers on port 80 ──────────────────────────────────────────────────
  if ss -tlnp4 | grep -q ':80 '; then
    log "\n  ${CYAN}[secsuite] Analysing HTTP security headers on localhost:80...${NC}"
    SS_HEADERS=$("$SECSUITE" osint headers http://localhost 2>/dev/null | grep -iE 'finding|missing|HIGH|MEDIUM|LOW|CRITICAL|header' | head -30 || echo "")
    if [[ -n "$SS_HEADERS" ]]; then
      while IFS= read -r line; do
        log "  ${DIM}${line}${NC}"
        if echo "$line" | grep -qiE 'HIGH|CRITICAL'; then
          high "secsuite header finding: ${line}" "Check http://localhost headers"
        elif echo "$line" | grep -qiE 'MEDIUM'; then
          medium "secsuite header finding: ${line}" ""
        fi
      done <<< "$SS_HEADERS"
    fi
  fi

  # ── SSL check on port 443 ─────────────────────────────────────────────────────
  if ss -tlnp4 | grep -q ':443 '; then
    log "\n  ${CYAN}[secsuite] Checking SSL/TLS on localhost:443...${NC}"
    SS_SSL=$("$SECSUITE" scan ssl localhost 2>/dev/null | grep -iE 'finding|HIGH|MEDIUM|LOW|CRITICAL|tls|ssl' | head -20 || echo "")
    [[ -n "$SS_SSL" ]] && info "secsuite SSL findings logged" "$SS_SSL"
  fi

  # ── DNS check (pick the first external-looking hostname if any) ───────────────
  if [[ "$(hostname -f 2>/dev/null)" != "localhost" ]]; then
    FQDN=$(hostname -f 2>/dev/null)
    log "\n  ${CYAN}[secsuite] Running DNS enumeration on ${FQDN}...${NC}"
    "$SECSUITE" osint dns "$FQDN" 2>/dev/null | tail -20 >> "$LOG_FILE" || true
    info "secsuite DNS enumeration on ${FQDN} — results in log" ""
  fi

  # ── Password generator test ───────────────────────────────────────────────────
  log "\n  ${CYAN}[secsuite] Sample strong password generation:${NC}"
  SAMPLE_PASS=$("$SECSUITE" password generate --count 3 2>/dev/null)
  log "${DIM}${SAMPLE_PASS}${NC}"
fi

# =============================================================================
# 9. SUMMARY
# =============================================================================
section "9. AUDIT SUMMARY"

log ""
log "  ${BOLD}┌─────────────────────────────────────────┐${NC}"
log "  ${BOLD}│           FINDINGS SUMMARY              │${NC}"
log "  ${BOLD}├─────────────────────────────────────────┤${NC}"
log "  ${LRED}${BOLD}│  CRITICAL : ${CRITICAL}${NC}"
log "  ${RED}│  HIGH     : ${HIGH}${NC}"
log "  ${YELLOW}│  MEDIUM   : ${MEDIUM}${NC}"
log "  ${YELLOW}│  LOW      : ${LOW}${NC}"
log "  ${GREEN}│  PASS     : ${PASS}${NC}"
log "  ${BOLD}└─────────────────────────────────────────┘${NC}"
log ""
log "  ${BOLD}Top priorities:${NC}"
[[ $CRITICAL -gt 0 ]] && log "  ${LRED}→ Address CRITICAL findings immediately (system at risk)${NC}"
[[ $HIGH -gt 0 ]]     && log "  ${RED}→ Remediate HIGH findings before next maintenance window${NC}"
[[ $MEDIUM -gt 0 ]]   && log "  ${YELLOW}→ Plan MEDIUM fixes in next sprint${NC}"

# =============================================================================
# 10. HTML REPORT
# =============================================================================
cat > "$HTML_REPORT" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SecSuite — Ubuntu Security Audit ${REPORT_DATE}</title>
<style>
  :root { --bg: #0d1117; --bg2: #161b22; --border: #30363d; --text: #c9d1d9; --muted: #6e7681; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: var(--bg); color: var(--text); font-family: 'Segoe UI', system-ui, sans-serif; font-size: 14px; padding: 2rem; }
  h1 { color: #58a6ff; font-size: 1.6rem; margin-bottom: 0.25rem; }
  .meta { color: var(--muted); font-size: 0.85rem; margin-bottom: 2rem; }
  .summary { display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 2rem; }
  .score-box { background: var(--bg2); border: 1px solid var(--border); border-radius: 8px; padding: 1rem 1.5rem; text-align: center; min-width: 110px; }
  .score-box .num { font-size: 2.2rem; font-weight: 700; }
  .score-box .lbl { font-size: 0.8rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; }
  .c-critical { color: #ff4444; } .c-high { color: #ff8800; } .c-medium { color: #ffcc00; }
  .c-low { color: #99cc00; } .c-pass { color: #00cc44; }
  table { width: 100%; border-collapse: collapse; background: var(--bg2); border-radius: 8px; overflow: hidden; margin-bottom: 2rem; }
  th { background: #1c2128; color: var(--muted); text-align: left; padding: 0.6rem 1rem; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; }
  td { padding: 0.55rem 1rem; border-top: 1px solid var(--border); vertical-align: top; }
  tr:hover td { background: #1c2128; }
  td.section { background: #1c2128; color: #58a6ff; font-weight: 700; font-size: 0.95rem; padding: 0.8rem 1rem; border-top: 2px solid var(--border); }
  td.detail { font-size: 0.82rem; color: var(--muted); }
  .badge { display: inline-block; padding: 0.2em 0.55em; border-radius: 4px; color: #000; font-size: 0.72rem; font-weight: 700; }
  footer { color: var(--muted); font-size: 0.8rem; text-align: center; margin-top: 2rem; }
</style>
</head>
<body>
<h1>SecSuite — Ubuntu Security Audit</h1>
<p class="meta">Host: <b>${HOSTNAME}</b> &nbsp;|&nbsp; ${OS} &nbsp;|&nbsp; Kernel: ${KERNEL} &nbsp;|&nbsp; ${REPORT_DATE//_/ }</p>
<div class="summary">
  <div class="score-box"><div class="num c-critical">${CRITICAL}</div><div class="lbl">Critical</div></div>
  <div class="score-box"><div class="num c-high">${HIGH}</div><div class="lbl">High</div></div>
  <div class="score-box"><div class="num c-medium">${MEDIUM}</div><div class="lbl">Medium</div></div>
  <div class="score-box"><div class="num c-low">${LOW}</div><div class="lbl">Low</div></div>
  <div class="score-box"><div class="num c-pass">${PASS}</div><div class="lbl">Pass</div></div>
</div>
<table>
<thead><tr><th style="width:110px">Severity</th><th>Finding</th><th style="width:40%">Remediation</th></tr></thead>
<tbody>
$(echo -e "$HTML_BODY")
</tbody>
</table>
<footer>Generated by secsuite audit run — Security Suite v0.1.0 — TheSecuredAnalyst</footer>
</body>
</html>
HTMLEOF

# ── Write JSON findings file ──────────────────────────────────────────────────
{
  printf '{\n'
  printf '  "audit_date": "%s",\n' "$(date -Iseconds)"
  printf '  "hostname": "%s",\n'   "$HOSTNAME"
  printf '  "os": "%s",\n'         "$OS"
  printf '  "kernel": "%s",\n'     "$KERNEL"
  printf '  "summary": {"critical":%d,"high":%d,"medium":%d,"low":%d,"pass":%d},\n' \
    "$CRITICAL" "$HIGH" "$MEDIUM" "$LOW" "$PASS"
  printf '  "findings": [\n'
  # Convert JSONL to comma-separated JSON array
  echo "$FINDINGS_JSONL" | python3 -c "
import sys, json
lines = [l for l in sys.stdin.read().splitlines() if l.strip()]
objs  = [json.loads(l) for l in lines]
print(',\n'.join('    ' + json.dumps(o) for o in objs))
"
  printf '\n  ]\n}\n'
} > "$JSON_FILE"

# keep a stable symlink so the remediate script always finds the latest
ln -sf "$JSON_FILE" "${REPORT_DIR}/latest_findings.json"

log "\n${GREEN}${BOLD}  HTML report saved:${NC} ${HTML_REPORT}"
log "${GREEN}${BOLD}  JSON findings saved:${NC} ${JSON_FILE}"
log "${GREEN}${BOLD}  Text log saved:${NC}    ${LOG_FILE}\n"
log "${DIM}  Open report:   xdg-open \"${HTML_REPORT}\"${NC}"
log "${DIM}  Run remediate: secsuite audit remediate${NC}\n"
