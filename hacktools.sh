#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════╗
#  ██╗  ██╗ █████╗  ██████╗██╗  ██╗████████╗ ██████╗  ██████╗ ██╗      ███████╗
#  ██║  ██║██╔══██╗██╔════╝██║ ██╔╝╚══██╔══╝██╔═══██╗██╔═══██╗██║      ██╔════╝
#  ███████║███████║██║     █████╔╝    ██║   ██║   ██║██║   ██║██║      ███████╗
#  ██╔══██║██╔══██║██║     ██╔═██╗    ██║   ██║   ██║██║   ██║██║      ╚════██║
#  ██║  ██║██║  ██║╚██████╗██║  ██╗   ██║   ╚██████╔╝╚██████╔╝███████╗ ███████║
#  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝  ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝ ╚══════╝
#
#      💀  Hacking Tools Installer for Fedora  💀
#      Categories mirror the official Kali Linux menu
#      FOR LEGAL USE ONLY — authorised pentest / CTF / security research
#
#   Version: 1.0
#   Requires: Fedora 39+ · DNF · sudo
# ╚══════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ─── Log file ─────────────────────────────────────────────────────────────────
LOG_FILE="$HOME/hacktools_log_$(date +%Y%m%d_%H%M%S).txt"

# ─── sudo keepalive ───────────────────────────────────────────────────────────
_sudo_keepalive() {
    while true; do sudo -n true; sleep 55; done 2>/dev/null &
    _SUDO_KA_PID=$!
    trap 'kill "$_SUDO_KA_PID" 2>/dev/null; tput cnorm 2>/dev/null || true' EXIT
}

# ─── Spinner ──────────────────────────────────────────────────────────────────
run_with_spinner() {
    local label="$1"; shift
    local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    PYTHONUNBUFFERED=1 "$@" >> "$LOG_FILE" 2>&1 &
    local cmd_pid=$!
    tput civis 2>/dev/null || true
    while kill -0 "$cmd_pid" 2>/dev/null; do
        local char="${spin_chars:$(( i % ${#spin_chars} )):1}"
        printf "  ${CYAN}%s${NC} %s\r" "$char" "$label"
        sleep 0.1
        (( i++ )) || true
    done
    tput cnorm 2>/dev/null || true
    printf "  %-60s\r" ""
    wait "$cmd_pid"
}

# ─── Helpers ──────────────────────────────────────────────────────────────────
_ok()     { echo -e "${GREEN}  ✓${NC} $*"; }
_warn()   { echo -e "${YELLOW}  !${NC} $*"; }
_err()    { echo -e "${RED}  ✗${NC} $*"; }
_info()   { echo -e "${CYAN}  ›${NC} $*"; }
_header() { echo -e "\n${RED}━━  $*  ━━${NC}\n"; }
_sep()    { echo -e "  ${CYAN}──────────────────────────────────────────────${NC}"; }

log()     { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; }

check_command() { command -v "$1" &>/dev/null; }

confirm_action() {
    local response
    read -rp "  $1 [y/N]: " response
    [[ "$response" =~ ^[Yy]$ ]]
}

# ─── Repository setup ─────────────────────────────────────────────────────────
setup_repos() {
    _header "Setting Up Repositories"

    # RPM Fusion (Free + Non-Free) — needed for some tools
    if ! rpm -q rpmfusion-free-release &>/dev/null; then
        _info "Enabling RPM Fusion (Free)..."
        run_with_spinner "RPM Fusion Free" sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
        _ok "RPM Fusion Free enabled."
    else
        _warn "RPM Fusion Free already enabled."
    fi

    if ! rpm -q rpmfusion-nonfree-release &>/dev/null; then
        _info "Enabling RPM Fusion (Non-Free)..."
        run_with_spinner "RPM Fusion Non-Free" sudo dnf install -y \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
        _ok "RPM Fusion Non-Free enabled."
    else
        _warn "RPM Fusion Non-Free already enabled."
    fi

    # EPEL-equivalent (Fedora already has full repos, but make sure copr/extras are on)
    _info "Refreshing DNF metadata..."
    run_with_spinner "DNF refresh" sudo dnf makecache --quiet
    _ok "Repositories ready."
}

# ─── Generic package installer with pass/fail report ─────────────────────────
_install_pkgs() {
    local category="$1"; shift
    local pkgs=("$@")
    local installed=0 failed=0 skipped=0

    _info "Installing ${#pkgs[@]} packages for: ${category}"
    echo ""

    for pkg in "${pkgs[@]}"; do
        # Strip inline comments (everything after first space)
        local name="${pkg%% *}"
        if rpm -q "$name" &>/dev/null 2>&1 || check_command "$name" 2>/dev/null; then
            echo -e "  ${YELLOW}already installed:${NC} $name"
            skipped=$((skipped+1))
        elif sudo dnf install -y "$name" &>>"$LOG_FILE" 2>&1; then
            echo -e "  ${GREEN}✓${NC} $name"
            installed=$((installed+1))
        else
            echo -e "  ${RED}✗${NC} $name ${RED}(not in repos — may need manual install)${NC}"
            failed=$((failed+1))
        fi
    done

    echo ""
    _sep
    echo -e "  ${GREEN}Installed: ${installed}${NC}   ${YELLOW}Already present: ${skipped}${NC}   ${RED}Failed: ${failed}${NC}"
    _sep
    [[ $failed -gt 0 ]] && _warn "Some packages not found in repos — check $LOG_FILE"
    log "$category: installed=$installed skipped=$skipped failed=$failed"
}

# ─── pip installer (for Python-only tools) ────────────────────────────────────
_install_pip() {
    local category="$1"; shift
    _info "Installing Python tools for: ${category}"
    echo ""
    for pkg in "$@"; do
        if pip3 show "$pkg" &>/dev/null 2>&1; then
            echo -e "  ${YELLOW}already installed (pip):${NC} $pkg"
        elif pip3 install --user "$pkg" &>>"$LOG_FILE" 2>&1; then
            echo -e "  ${GREEN}✓ (pip)${NC} $pkg"
        else
            echo -e "  ${RED}✗ (pip)${NC} $pkg"
        fi
    done
}

# ─── git installer ────────────────────────────────────────────────────────────
TOOLS_DIR="$HOME/HackTools"
_clone_tool() {
    local name="$1" url="$2"
    local dest="$TOOLS_DIR/$name"
    if [[ -d "$dest" ]]; then
        _info "Pulling latest: $name"
        git -C "$dest" pull --quiet 2>>"$LOG_FILE" && _ok "$name updated."
    else
        _info "Cloning: $name"
        git clone --depth=1 "$url" "$dest" &>>"$LOG_FILE" && _ok "$name cloned → $dest"
    fi
}

# =============================================================================
# CATEGORY FUNCTIONS
# =============================================================================

# ── 1. Information Gathering ──────────────────────────────────────────────────
cat_information_gathering() {
    _header "Information Gathering"
    echo -e "  ${CYAN}Network recon · DNS enumeration · OSINT · port scanning · fingerprinting${NC}"
    echo ""

    local dnf_pkgs=(
        nmap              # Industry-standard port/service scanner
        masscan           # Fastest internet-scale port scanner
        netdiscover       # ARP-based LAN host discovery
        arp-scan          # ARP scanner
        fping             # Parallel ICMP ping sweep
        hping3            # Packet crafting and TCP/IP testing
        whois             # WHOIS domain lookup
        bind-utils        # dig, nslookup, host
        dnsenum           # DNS enumeration and zone transfer
        fierce            # DNS scanner / subdomain finder
        dmitry            # Information gathering tool
        enum4linux-ng     # SMB/NetBIOS enumeration (next-gen)
        smbclient         # SMB share enumeration
        nbtscan           # NetBIOS name scanner
        onesixtyone       # SNMP scanner
        p0f               # Passive OS fingerprinting
        nikto             # Web server vulnerability scanner
        wafw00f           # WAF detection tool
        gobuster          # Dir/DNS/vhost brute-forcer
        ffuf              # Fast web fuzzer
        dirb              # Web content scanner
        whatweb           # Web technology fingerprinting
        theharvester      # OSINT email/domain/host harvesting
        recon-ng          # Web reconnaissance framework
        maltego           # Graphical OSINT/link analysis
        amass             # Subdomain enumeration / attack surface
        subfinder         # Subdomain discovery
        shodan            # Shodan CLI (pip: shodan)
    )
    _install_pkgs "Information Gathering" "${dnf_pkgs[@]}"

    # Python-only tools
    _install_pip "Information Gathering (pip)" \
        shodan dnsrecon spiderfoot

    # Git-cloned tools
    mkdir -p "$TOOLS_DIR"
    _clone_tool "EyeWitness"  "https://github.com/RedSiege/EyeWitness.git"
    _clone_tool "sublist3r"   "https://github.com/aboul3la/Sublist3r.git"
}

# ── 2. Vulnerability Analysis ─────────────────────────────────────────────────
cat_vulnerability_analysis() {
    _header "Vulnerability Analysis"
    echo -e "  ${CYAN}Scanners · fuzzers · CVE detection · config auditing${NC}"
    echo ""

    local dnf_pkgs=(
        nikto             # Web server scanner
        lynis             # Local system security auditing
        checksec          # Binary security property checker
        binwalk           # Firmware analysis and extraction
        sqlmap            # SQL injection detection/exploitation
        sslyze            # TLS/SSL configuration analyser
        sslscan           # TLS/SSL cipher suite scanner
        openscap-scanner  # SCAP/OVAL vulnerability scanner
        scap-security-guide  # SCAP security policies
        python3-pip       # Required for pip-installed tools
    )
    _install_pkgs "Vulnerability Analysis" "${dnf_pkgs[@]}"

    _install_pip "Vulnerability Analysis (pip)" \
        sslyze testssl wapiti3 commix

    # OpenVAS / GVM (Greenbone)
    echo ""
    _info "Note: For OpenVAS/GVM, install via:"
    echo -e "  ${WHITE}  sudo dnf install gvm${NC}  (then run: sudo gvm-setup)"

    # Nuclei
    if ! check_command nuclei; then
        _info "Installing Nuclei (Go binary)..."
        if check_command go; then
            go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest &>>"$LOG_FILE" \
                && _ok "Nuclei installed via go install."
        else
            _warn "Go not found — skipping Nuclei. Install Go first, then: go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
        fi
    else
        _warn "nuclei already installed."
    fi
}

# ── 3. Web Application Hacking ────────────────────────────────────────────────
cat_web_application() {
    _header "Web Application Hacking"
    echo -e "  ${CYAN}SQL injection · XSS · fuzzing · proxies · CMS scanners${NC}"
    echo ""

    local dnf_pkgs=(
        sqlmap            # Automated SQL injection tool
        gobuster          # Directory/file/DNS brute-forcer
        ffuf              # Fast web fuzzer (recursive)
        dirb              # Web content scanner
        nikto             # Web server scanner
        whatweb           # Web fingerprinting
        wafw00f           # WAF fingerprinting
        wpscan            # WordPress vulnerability scanner
        python3-requests  # HTTP library (required by many tools)
        python3-bs4       # BeautifulSoup HTML parser
        curl              # HTTP Swiss Army knife
        wget              # File downloader
    )
    _install_pkgs "Web Application" "${dnf_pkgs[@]}"

    _install_pip "Web App (pip)" \
        wfuzz commix dirsearch arjun httpx-toolkit

    # Burp Suite Community (manual download note)
    echo ""
    _info "Burp Suite Community Edition — manual install required:"
    echo -e "  ${WHITE}  https://portswigger.net/burp/communitydownload${NC}"

    # OWASP ZAP via Flatpak
    echo ""
    _info "OWASP ZAP — install via Flatpak:"
    echo -e "  ${WHITE}  flatpak install flathub org.zaproxy.ZAP${NC}"
    if confirm_action "Install OWASP ZAP via Flatpak now?"; then
        flatpak install -y flathub org.zaproxy.ZAP 2>&1 | tee -a "$LOG_FILE" \
            && _ok "ZAP installed." || _err "ZAP install failed."
    fi

    # Git tools
    _clone_tool "dirsearch"   "https://github.com/maurosoria/dirsearch.git"
    _clone_tool "ParamSpider" "https://github.com/devanshbatham/ParamSpider.git"
    _clone_tool "XSStrike"    "https://github.com/s0md3v/XSStrike.git"
}

# ── 4. Exploitation ───────────────────────────────────────────────────────────
cat_exploitation() {
    _header "Exploitation Tools"
    echo -e "  ${CYAN}Frameworks · exploit helpers · shellcode generation · reverse engineering${NC}"
    echo ""

    local dnf_pkgs=(
        metasploit        # The Metasploit Framework
        gdb               # GNU Debugger
        ltrace            # Library call tracer
        strace            # System call tracer
        radare2           # Reverse engineering framework
        binwalk           # Binary analysis and extraction
        checksec          # Binary hardening checker
        python3-pwntools  # CTF/exploit development library
        exploitdb         # Exploit Database (searchsploit)
        nasm              # Netwide Assembler (shellcode)
        mingw64-gcc       # Cross-compiler for Windows payloads
    )
    _install_pkgs "Exploitation" "${dnf_pkgs[@]}"

    # Ghidra (NSA RE tool) via Flatpak
    _info "Ghidra is best installed via Flatpak or direct download:"
    echo -e "  ${WHITE}  https://ghidra-sre.org/${NC}"

    # Git tools
    _clone_tool "Veil"        "https://github.com/Veil-Framework/Veil.git"
    _clone_tool "shellter"    "https://github.com/ParrotSec/shellter.git"
}

# ── 5. Post Exploitation ──────────────────────────────────────────────────────
cat_post_exploitation() {
    _header "Post Exploitation"
    echo -e "  ${CYAN}Persistence · lateral movement · AD attacks · privilege escalation${NC}"
    echo ""

    local dnf_pkgs=(
        crackmapexec      # Active Directory Swiss Army knife
        evil-winrm        # WinRM shell for pentesting
        neo4j             # BloodHound database backend
        python3-ldap3     # LDAP library for AD recon
        pspy              # Process monitor (no root needed)
    )
    _install_pkgs "Post Exploitation" "${dnf_pkgs[@]}"

    _install_pip "Post Exploitation (pip)" \
        impacket pypykatz bloodhound

    # Git tools
    _clone_tool "BloodHound"              "https://github.com/SpecterOps/BloodHound.git"
    _clone_tool "PEASS-ng"                "https://github.com/peass-ng/PEASS-ng.git"
    _clone_tool "linux-exploit-suggester" "https://github.com/The-Z-Labs/linux-exploit-suggester.git"
    _clone_tool "linpeas"                 "https://github.com/peass-ng/PEASS-ng.git"
    _clone_tool "PowerSploit"             "https://github.com/PowerShellMafia/PowerSploit.git"
}

# ── 6. Password Attacks ───────────────────────────────────────────────────────
cat_password_attacks() {
    _header "Password Attacks"
    echo -e "  ${CYAN}Hash cracking · brute force · wordlist tools${NC}"
    echo ""

    local dnf_pkgs=(
        hashcat           # GPU-accelerated password cracker
        john              # John the Ripper password cracker
        hydra             # Network login brute-forcer
        medusa            # Parallel network login auditor
        ncrack            # Network authentication cracker
        crunch            # Custom wordlist generator
        cewl              # Wordlist from website content
        fcrackzip         # ZIP password cracker
        pdfcrack          # PDF password cracker
        python3-pip       # For pip tools
    )
    _install_pkgs "Password Attacks" "${dnf_pkgs[@]}"

    _install_pip "Password Attacks (pip)" \
        hashid

    # rockyou wordlist
    if [[ ! -f /usr/share/wordlists/rockyou.txt ]]; then
        _info "Downloading rockyou.txt wordlist..."
        sudo mkdir -p /usr/share/wordlists
        sudo curl -sL "https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt" \
            -o /usr/share/wordlists/rockyou.txt 2>>"$LOG_FILE" \
            && _ok "rockyou.txt saved to /usr/share/wordlists/" \
            || _warn "Could not download rockyou.txt — download manually."
    else
        _warn "rockyou.txt already present."
    fi

    # SecLists
    if [[ ! -d "$TOOLS_DIR/SecLists" ]]; then
        if confirm_action "Clone SecLists (~1 GB wordlist collection)?"; then
            git clone --depth=1 "https://github.com/danielmiessler/SecLists.git" \
                "$TOOLS_DIR/SecLists" 2>&1 | tee -a "$LOG_FILE" && _ok "SecLists cloned."
        fi
    else
        _warn "SecLists already cloned."
    fi
}

# ── 7. Wireless Attacks ───────────────────────────────────────────────────────
cat_wireless() {
    _header "Wireless Attacks"
    echo -e "  ${CYAN}WiFi auditing · Bluetooth · SDR · RFID/NFC${NC}"
    echo ""

    local dnf_pkgs=(
        aircrack-ng       # WiFi security auditing suite
        kismet            # Wireless network detector/sniffer
        hostapd           # WiFi access point daemon (rogue AP)
        dnsmasq           # DHCP/DNS for rogue AP
        reaver            # WPS brute-force tool
        hcxtools          # WiFi capture file converter (hashcat)
        hcxdumptool       # WiFi capture tool
        bluez             # Bluetooth stack and tools
        bluez-tools       # Bluetooth utilities
        gnuradio          # SDR toolkit
        gqrx              # SDR receiver GUI
        rtl-sdr           # RTL-SDR driver and tools
        hackrf            # HackRF SDR tools
        libnfc            # NFC library and tools
        iw                # Wireless config tool
        wireless-tools    # iwconfig, iwlist etc.
    )
    _install_pkgs "Wireless Attacks" "${dnf_pkgs[@]}"

    _install_pip "Wireless (pip)" \
        bettercap

    # Wifite2
    _clone_tool "wifite2" "https://github.com/derv82/wifite2.git"
    # pixiewps
    _clone_tool "pixiewps" "https://github.com/wiire-a/pixiewps.git"
}

# ── 8. Sniffing & Spoofing ────────────────────────────────────────────────────
cat_sniffing_spoofing() {
    _header "Sniffing & Spoofing"
    echo -e "  ${CYAN}Packet capture · MITM · ARP/DNS spoofing · SSL stripping${NC}"
    echo ""

    local dnf_pkgs=(
        wireshark         # Network protocol analyser (GUI)
        tshark            # Wireshark CLI
        tcpdump           # Packet capture
        ettercap          # MITM framework
        dsniff            # Password sniffer suite (arpspoof etc.)
        mitmproxy         # Interactive SSL-capable MITM proxy
        dnschef           # DNS proxy/forger
        tcpreplay         # Replay captured network traffic
        python3-scapy     # Python packet manipulation library
        netsniff-ng       # Linux network performance toolkit
        p0f               # Passive OS fingerprinting
        nmap              # Port/service scanner (also for spoofing)
        macchanger        # MAC address spoofer
        responder         # LLMNR/NBT-NS/MDNS poisoner
    )
    _install_pkgs "Sniffing & Spoofing" "${dnf_pkgs[@]}"

    _install_pip "Sniffing (pip)" \
        scapy

    # bettercap
    if ! check_command bettercap; then
        _info "bettercap not in DNF — installing via Go..."
        if check_command go; then
            run_with_spinner "bettercap build" go install github.com/bettercap/bettercap@latest \
                && _ok "bettercap installed." || _warn "bettercap build failed — check $LOG_FILE"
        else
            _warn "Go not found. Install Go, then: go install github.com/bettercap/bettercap@latest"
        fi
    fi
}

# ── 9. Digital Forensics ─────────────────────────────────────────────────────
cat_forensics() {
    _header "Digital Forensics"
    echo -e "  ${CYAN}Disk imaging · memory analysis · file carving · artefact analysis${NC}"
    echo ""

    local dnf_pkgs=(
        sleuthkit         # The Sleuth Kit CLI tools
        foremost          # File recovery by header/footer
        scalpel           # File carving tool
        testdisk          # Partition and boot record recovery
        photorec          # File recovery
        dc3dd             # Forensic dd with hashing and logging
        dcfldd            # Enhanced dd with hashing
        binwalk           # Firmware and binary analysis
        perl-Image-ExifTool  # ExifTool — metadata reader/writer
        yara              # Malware pattern matching rules
        ssdeep            # Fuzzy hashing
        steghide          # Image steganography
        outguess          # Steganography tool
        radare2           # Binary/malware analysis
        strings           # Extract printable strings from binaries
        file              # File type identification
        xxd               # Hex dump
        binutils          # objdump, readelf, nm
    )
    _install_pkgs "Digital Forensics" "${dnf_pkgs[@]}"

    _install_pip "Forensics (pip)" \
        volatility3 stegseek

    # Autopsy (GUI frontend for Sleuth Kit) — AppImage/direct download
    echo ""
    _info "Autopsy GUI — download from:"
    echo -e "  ${WHITE}  https://www.autopsy.com/download/${NC}"

    _clone_tool "volatility3" "https://github.com/volatilityfoundation/volatility3.git"
    _clone_tool "bulk-extractor" "https://github.com/simsong/bulk_extractor.git"
}

# ── 10. Reverse Engineering ───────────────────────────────────────────────────
cat_reverse_engineering() {
    _header "Reverse Engineering"
    echo -e "  ${CYAN}Disassemblers · debuggers · decompilers · binary analysis${NC}"
    echo ""

    local dnf_pkgs=(
        radare2           # Reverse engineering framework
        gdb               # GNU Debugger
        ltrace            # Library call tracer
        strace            # System call tracer
        valgrind          # Memory analysis / dynamic RE
        binwalk           # Firmware extraction
        upx               # UPX packer/unpacker
        python3-pwntools  # CTF/exploit development library
        nasm              # Assembler
        objdump           # Object file disassembler (via binutils)
        binutils          # readelf, nm, objdump etc.
        checksec          # Binary hardening property checker
        apktool           # Android APK reverse engineering
        java-latest-openjdk  # Required for Ghidra, Jadx, Apktool
    )
    _install_pkgs "Reverse Engineering" "${dnf_pkgs[@]}"

    _install_pip "Reverse Engineering (pip)" \
        frida frida-tools ropper

    # pwndbg (GDB plugin)
    if [[ ! -d "$TOOLS_DIR/pwndbg" ]]; then
        _clone_tool "pwndbg" "https://github.com/pwndbg/pwndbg.git"
        _info "To install pwndbg, run:"
        echo -e "  ${WHITE}  cd $TOOLS_DIR/pwndbg && ./setup.sh${NC}"
    fi

    # Ghidra
    if ! check_command ghidra && [[ ! -d "$TOOLS_DIR/ghidra" ]]; then
        _info "Downloading latest Ghidra release..."
        local GHIDRA_URL
        GHIDRA_URL=$(curl -s https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest \
            | grep browser_download_url | grep "\.zip" | head -1 | cut -d'"' -f4)
        if [[ -n "$GHIDRA_URL" ]]; then
            wget -q "$GHIDRA_URL" -O /tmp/ghidra.zip 2>>"$LOG_FILE" \
                && unzip -q /tmp/ghidra.zip -d "$TOOLS_DIR/" 2>>"$LOG_FILE" \
                && mv "$TOOLS_DIR"/ghidra_* "$TOOLS_DIR/ghidra" 2>/dev/null || true \
                && _ok "Ghidra extracted to $TOOLS_DIR/ghidra" \
                || _err "Ghidra download failed — check $LOG_FILE"
            rm -f /tmp/ghidra.zip
        else
            _warn "Could not fetch Ghidra download URL — download manually from https://ghidra-sre.org"
        fi
    else
        _warn "Ghidra already present."
    fi

    # jadx (Android decompiler)
    if ! check_command jadx; then
        local JADX_URL
        JADX_URL=$(curl -s https://api.github.com/repos/skylot/jadx/releases/latest \
            | grep browser_download_url | grep "jadx-[0-9].*\.zip" | head -1 | cut -d'"' -f4)
        if [[ -n "$JADX_URL" ]]; then
            _info "Downloading jadx..."
            wget -q "$JADX_URL" -O /tmp/jadx.zip 2>>"$LOG_FILE" \
                && mkdir -p "$TOOLS_DIR/jadx" \
                && unzip -q /tmp/jadx.zip -d "$TOOLS_DIR/jadx/" 2>>"$LOG_FILE" \
                && ln -sf "$TOOLS_DIR/jadx/bin/jadx" "$HOME/.local/bin/jadx" 2>/dev/null || true \
                && _ok "jadx installed → $TOOLS_DIR/jadx" \
                || _err "jadx download failed."
            rm -f /tmp/jadx.zip
        else
            _warn "Could not fetch jadx URL."
        fi
    else
        _warn "jadx already installed."
    fi
}

# ── 11. Network Attacks ───────────────────────────────────────────────────────
cat_network_attacks() {
    _header "Network Attacks"
    echo -e "  ${CYAN}MITM · tunnelling · pivoting · SMB · Kerberos · proxying${NC}"
    echo ""

    local dnf_pkgs=(
        nmap              # Port and service scanner
        masscan           # Fast port scanner
        ncat              # Nmap netcat
        socat             # Socket relay tool
        proxychains-ng    # Route traffic through proxies/Tor
        sshuttle          # Transparent SSH VPN/proxy
        iodine            # DNS tunnelling
        hping3            # Packet crafting tool
        python3-scapy     # Python packet manipulation
        ike-scan          # VPN/IKE fingerprinting
        onesixtyone       # SNMP scanner
        responder         # NBT-NS/LLMNR/mDNS poisoner
        arp-scan          # ARP-based host discovery
        netcat            # Classic netcat
        curl              # HTTP Swiss Army knife
    )
    _install_pkgs "Network Attacks" "${dnf_pkgs[@]}"

    _install_pip "Network Attacks (pip)" \
        impacket crackmapexec

    _clone_tool "chisel"    "https://github.com/jpillora/chisel.git"
    _clone_tool "ligolo-ng" "https://github.com/nicocha30/ligolo-ng.git"
    _clone_tool "coercer"   "https://github.com/p0dalirius/Coercer.git"
}

# ── 12. Social Engineering ────────────────────────────────────────────────────
cat_social_engineering() {
    _header "Social Engineering"
    echo -e "  ${CYAN}Phishing frameworks · payload delivery · credential harvesting${NC}"
    echo ""

    local dnf_pkgs=(
        python3-pip       # Required
        python3           # Required
        metasploit        # msfvenom payload generator
        curl              # For downloading payloads
    )
    _install_pkgs "Social Engineering (base)" "${dnf_pkgs[@]}"

    _install_pip "Social Engineering (pip)" \
        pyinstaller       # Package Python scripts as EXEs

    # SET (Social Engineering Toolkit)
    if [[ ! -d "$TOOLS_DIR/setoolkit" ]]; then
        _clone_tool "setoolkit" "https://github.com/trustedsec/social-engineer-toolkit.git"
        _info "To install SET, run:"
        echo -e "  ${WHITE}  cd $TOOLS_DIR/setoolkit && pip3 install -r requirements.txt${NC}"
    fi

    # GoPhish
    if ! check_command gophish; then
        local GOPHISH_URL
        GOPHISH_URL=$(curl -s https://api.github.com/repos/gophish/gophish/releases/latest \
            | grep browser_download_url | grep linux_64bit | head -1 | cut -d'"' -f4)
        if [[ -n "$GOPHISH_URL" ]]; then
            _info "Downloading GoPhish..."
            mkdir -p "$TOOLS_DIR/gophish"
            wget -q "$GOPHISH_URL" -O /tmp/gophish.zip 2>>"$LOG_FILE" \
                && unzip -q /tmp/gophish.zip -d "$TOOLS_DIR/gophish/" 2>>"$LOG_FILE" \
                && chmod +x "$TOOLS_DIR/gophish/gophish" \
                && ln -sf "$TOOLS_DIR/gophish/gophish" "$HOME/.local/bin/gophish" 2>/dev/null || true \
                && _ok "GoPhish installed → $TOOLS_DIR/gophish" \
                || _err "GoPhish download failed."
            rm -f /tmp/gophish.zip
        fi
    else
        _warn "gophish already installed."
    fi

    # Evilginx2
    _clone_tool "evilginx2" "https://github.com/kgretzky/evilginx2.git"
    _info "To build evilginx2, run:"
    echo -e "  ${WHITE}  cd $TOOLS_DIR/evilginx2 && make${NC}"
}

# ── 13. CTF & Binary Exploitation ────────────────────────────────────────────
cat_ctf_tools() {
    _header "CTF & Binary Exploitation"
    echo -e "  ${CYAN}CTF frameworks · ROP tools · steganography · cryptography${NC}"
    echo ""

    local dnf_pkgs=(
        python3-pwntools  # The CTF exploit dev library
        gdb               # GNU Debugger
        qemu-system-x86   # x86 system emulation for CTF
        qemu-user-static  # Multi-arch binary execution
        steghide          # Steganography embed/extract
        outguess          # Steganography tool
        perl-Image-ExifTool  # Metadata extraction
        foremost          # File carving
        binwalk           # Binary analysis
        hashcat           # Hash cracking
        john              # John the Ripper
        python3-z3        # Z3 SMT solver (crypto CTF)
        python3-gmpy2     # GMP Python bindings (RSA CTF)
        python3-cryptography  # Python crypto library
        nasm              # Assembler for shellcode
        radare2           # RE framework
        gdb-gdbserver     # Remote GDB debugging
        checksec          # Binary security flags checker
    )
    _install_pkgs "CTF & Binary Exploitation" "${dnf_pkgs[@]}"

    _install_pip "CTF (pip)" \
        ropper angr capstone keystone-engine unicorn

    # pwndbg
    if [[ ! -d "$TOOLS_DIR/pwndbg" ]]; then
        _clone_tool "pwndbg" "https://github.com/pwndbg/pwndbg.git"
        _info "Install pwndbg: cd $TOOLS_DIR/pwndbg && ./setup.sh"
    fi

    # CTF wordlists and resources
    _clone_tool "CTF-Resources" "https://github.com/ctfs/write-ups-2015.git"
    _clone_tool "stegseek"      "https://github.com/RickdeJager/stegseek.git"

    # CyberChef (local copy)
    _info "CyberChef (online): https://gchq.github.io/CyberChef/"
}

# ── 14. Cloud & Container Security ───────────────────────────────────────────
cat_cloud_containers() {
    _header "Cloud & Container Security"
    echo -e "  ${CYAN}AWS/GCP/Azure · Docker/Kubernetes · secrets scanning${NC}"
    echo ""

    local dnf_pkgs=(
        awscli            # AWS CLI v2
        kubectl           # Kubernetes CLI
        helm              # Kubernetes package manager
        podman            # Docker-compatible container engine
        skopeo            # Container image inspection
        buildah           # Container image builder
        trivy             # Container/image vulnerability scanner
    )
    _install_pkgs "Cloud & Container Security" "${dnf_pkgs[@]}"

    _install_pip "Cloud Security (pip)" \
        pacu prowler detect-secrets

    # Azure CLI
    if ! check_command az; then
        _info "Installing Azure CLI via RPM..."
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>>"$LOG_FILE"
        sudo dnf install -y "https://packages.microsoft.com/yumrepos/azure-cli/azure-cli-$(rpm -E %fedora).noarch.rpm" \
            &>>"$LOG_FILE" && _ok "Azure CLI installed." || _warn "Azure CLI install failed — try: sudo rpm -i https://aka.ms/InstallAzureCLIDeb"
    else
        _warn "Azure CLI already installed."
    fi

    _clone_tool "gitleaks"    "https://github.com/gitleaks/gitleaks.git"
    _clone_tool "trufflehog"  "https://github.com/trufflesecurity/trufflehog.git"
    _clone_tool "kube-hunter" "https://github.com/aquasecurity/kube-hunter.git"
    _clone_tool "kube-bench"  "https://github.com/aquasecurity/kube-bench.git"
    _clone_tool "falco"       "https://github.com/falcosecurity/falco.git"
}

# ── 15. Anonymity & Anti-Forensics ───────────────────────────────────────────
cat_anonymity() {
    _header "Anonymity & Anti-Forensics"
    echo -e "  ${CYAN}Tor · proxy chains · MAC spoofing · trace wiping · encryption${NC}"
    echo ""

    local dnf_pkgs=(
        tor               # Tor anonymity network
        torsocks          # Route applications through Tor
        proxychains-ng    # Proxy chaining for anonymity
        macchanger        # MAC address spoofing tool
        bleachbit         # System and browser trace cleaner
        mat2              # Metadata anonymisation tool
        perl-Image-ExifTool  # Metadata reader and stripper
        wipe              # Secure file overwrite utility
        scrub             # Disk scrubbing tool
        secure-delete     # Secure file deletion (srm/sfill)
        veracrypt         # On-disk encrypted containers (if available)
        cryptsetup        # LUKS disk encryption
        gnupg2            # GPG encryption
        kleopatra         # GPG GUI frontend
    )
    _install_pkgs "Anonymity & Anti-Forensics" "${dnf_pkgs[@]}"

    # i2p
    _info "I2P network — install via:"
    echo -e "  ${WHITE}  https://geti2p.net/en/download${NC}"

    # OnionShare via Flatpak
    if confirm_action "Install OnionShare (Tor-based file sharing) via Flatpak?"; then
        flatpak install -y flathub org.onionshare.OnionShare 2>&1 | tee -a "$LOG_FILE" \
            && _ok "OnionShare installed." || _warn "OnionShare install failed."
    fi
}

# ─── Top-10 Essential Tools ───────────────────────────────────────────────────
install_top10() {
    _header "Installing Kali-equivalent Top-10 Essential Tools"
    _info "The most critical tools for any pentest..."
    echo ""

    local top10=(
        nmap
        metasploit
        sqlmap
        aircrack-ng
        john
        hashcat
        hydra
        wireshark
        nikto
        gobuster
    )

    for t in "${top10[@]}"; do
        if rpm -q "$t" &>/dev/null || check_command "$t" 2>/dev/null; then
            echo -e "  ${YELLOW}already installed:${NC} $t"
        elif sudo dnf install -y "$t" &>>"$LOG_FILE"; then
            echo -e "  ${GREEN}✓${NC} $t"
        else
            echo -e "  ${RED}✗${NC} $t (not found in repos)"
        fi
    done

    echo ""
    _ok "Top-10 install attempt complete. See $LOG_FILE for details."
}

# ─── Install ALL categories ───────────────────────────────────────────────────
install_all() {
    _header "Installing ALL Hacking Tool Categories"
    echo -e "  ${RED}⚠  This will attempt to install every tool (~400+). Takes a while.${NC}"
    echo ""
    if ! confirm_action "Proceed with full install?"; then
        _warn "Cancelled."; return
    fi

    setup_repos
    cat_information_gathering
    cat_vulnerability_analysis
    cat_web_application
    cat_exploitation
    cat_post_exploitation
    cat_password_attacks
    cat_wireless
    cat_sniffing_spoofing
    cat_forensics
    cat_reverse_engineering
    cat_network_attacks
    cat_social_engineering
    cat_ctf_tools
    cat_cloud_containers
    cat_anonymity

    echo ""
    _ok "All categories complete. See $LOG_FILE for full log."
}

# ─── Update all installed tools ───────────────────────────────────────────────
update_tools() {
    _header "Updating All Hacking Tools"
    run_with_spinner "DNF system update" sudo dnf upgrade -y
    _ok "DNF packages updated."

    if check_command pip3; then
        _info "Updating pip packages..."
        pip3 list --outdated --format=columns 2>/dev/null \
            | tail -n +3 | awk '{print $1}' \
            | xargs -r pip3 install --user --upgrade &>>"$LOG_FILE" \
            && _ok "pip packages updated." || _warn "Some pip updates failed — check $LOG_FILE"
    fi

    # Update git-cloned tools
    if [[ -d "$TOOLS_DIR" ]]; then
        _info "Updating git-cloned tools..."
        for tool_dir in "$TOOLS_DIR"/*/; do
            if [[ -d "$tool_dir/.git" ]]; then
                local tname
                tname=$(basename "$tool_dir")
                git -C "$tool_dir" pull --quiet 2>>"$LOG_FILE" \
                    && echo -e "  ${GREEN}✓${NC} $tname updated." \
                    || echo -e "  ${RED}✗${NC} $tname pull failed."
            fi
        done
    fi
    _ok "All tools updated."
}

# ─── Show installed tools summary ────────────────────────────────────────────
show_summary() {
    _header "Installed Hacking Tools Summary"
    local check_tools=(
        nmap masscan wireshark tshark tcpdump
        metasploit sqlmap hydra hashcat john
        aircrack-ng gobuster ffuf nikto
        radare2 gdb binwalk checksec
        volatility3 sleuthkit foremost steghide
        crackmapexec bloodhound impacket
        proxychains tor macchanger
        burpsuite nuclei
    )

    echo ""
    local found=0 miss=0
    for t in "${check_tools[@]}"; do
        if rpm -q "$t" &>/dev/null 2>&1 || check_command "$t" 2>/dev/null \
            || pip3 show "$t" &>/dev/null 2>&1 \
            || [[ -d "$TOOLS_DIR/$t" ]]; then
            echo -e "  ${GREEN}✓${NC} $t"
            found=$((found+1))
        else
            echo -e "  ${RED}✗${NC} $t"
            miss=$((miss+1))
        fi
    done

    echo ""
    _sep
    echo -e "  ${GREEN}Installed/present: ${found}${NC}   ${RED}Not found: ${miss}${NC}   (of ${#check_tools[@]} key tools checked)"
    _sep
    echo ""
    echo -e "  ${CYAN}Git-cloned tools in $TOOLS_DIR:${NC}"
    if [[ -d "$TOOLS_DIR" ]]; then
        ls -1 "$TOOLS_DIR" | sed 's/^/    /'
    else
        echo "    (none yet)"
    fi
}

# =============================================================================
# MAIN MENU
# =============================================================================

show_menu() {
    clear
    echo ""
    echo -e "${RED}"
    cat << 'BANNER'
  ██╗  ██╗ █████╗  ██████╗██╗  ██╗████████╗ ██████╗  ██████╗ ██╗      ███████╗
  ██║  ██║██╔══██╗██╔════╝██║ ██╔╝╚══██╔══╝██╔═══██╗██╔═══██╗██║      ██╔════╝
  ███████║███████║██║     █████╔╝    ██║   ██║   ██║██║   ██║██║      ███████╗
  ██╔══██║██╔══██║██║     ██╔═██╗    ██║   ██║   ██║██║   ██║██║      ╚════██║
  ██║  ██║██║  ██║╚██████╗██║  ██╗   ██║   ╚██████╔╝╚██████╔╝███████╗ ███████║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝  ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝ ╚══════╝
BANNER
    echo -e "${NC}"
    echo -e "  ${CYAN}💀  Hacking Tools Installer for Fedora  💀${NC}"
    echo -e "  ${YELLOW}⚠  FOR LEGAL USE ONLY — authorised pentest / CTF / security research  ⚠${NC}"
    echo -e "  ${CYAN}  Tools dir: $TOOLS_DIR   |   Log: $LOG_FILE${NC}"
    echo ""
    echo "  ════════════════════════════════════════════════════════"
    echo "  Individual Categories (Kali Linux menu order)"
    echo "  ════════════════════════════════════════════════════════"
    echo "   1)  Information Gathering     (nmap, masscan, amass, theHarvester)"
    echo "   2)  Vulnerability Analysis    (OpenVAS, nikto, sqlmap, sslyze)"
    echo "   3)  Web Application Hacking   (Burp, ZAP, sqlmap, ffuf, wfuzz)"
    echo "   4)  Exploitation              (Metasploit, pwntools, radare2)"
    echo "   5)  Post Exploitation         (CME, BloodHound, impacket, linpeas)"
    echo "   6)  Password Attacks          (hashcat, john, hydra, crunch, SecLists)"
    echo "   7)  Wireless Attacks          (aircrack, kismet, wifite, SDR, BT)"
    echo "   8)  Sniffing & Spoofing       (Wireshark, bettercap, mitmproxy)"
    echo "   9)  Digital Forensics         (Volatility3, Sleuth Kit, Autopsy)"
    echo "  10)  Reverse Engineering       (Ghidra, radare2, GDB, pwndbg, jadx)"
    echo "  11)  Network Attacks           (tunnels, pivoting, SMB, proxychains)"
    echo "  12)  Social Engineering        (SET, GoPhish, Evilginx2)"
    echo "  13)  CTF & Binary Exploitation (pwntools, ROP, steg, crypto)"
    echo "  14)  Cloud & Container Sec.    (Trivy, Pacu, Prowler, kubectl)"
    echo "  15)  Anonymity & Anti-Forensics(Tor, proxychains, mat2, VeraCrypt)"
    echo ""
    echo "  ════════════════════════════════════════════════════════"
    echo "  Bulk Actions"
    echo "  ════════════════════════════════════════════════════════"
    echo "  16)  Install ALL categories    (full toolkit — 400+ tools)"
    echo "  17)  Install Top-10 essentials (nmap, MSF, sqlmap, hydra…)"
    echo "  18)  Setup Repositories        (RPM Fusion, EPEL)"
    echo ""
    echo "  ════════════════════════════════════════════════════════"
    echo "  Utilities"
    echo "  ════════════════════════════════════════════════════════"
    echo "  19)  Update all hacking tools"
    echo "  20)  Show installed tools summary"
    echo ""
    echo "   0)  Exit"
    echo ""
    read -rp "  Select [0-20]: " choice
}

# =============================================================================
# BOOTSTRAP
# =============================================================================

# Must not run as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}  ✗ Do NOT run as root!${NC}"
    echo -e "${YELLOW}  Run as a regular user. The script will use sudo when needed.${NC}"
    exit 1
fi

# Ensure ~/.local/bin is in PATH for pip-installed tools
mkdir -p "$HOME/.local/bin" "$TOOLS_DIR"
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# Prime sudo once, then keep alive
sudo -v
_sudo_keepalive

echo "" | tee -a "$LOG_FILE"
echo "==> HackTools Fedora Installer — $(date)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Main loop
while true; do
    show_menu

    case "$choice" in
         1)  cat_information_gathering ;;
         2)  cat_vulnerability_analysis ;;
         3)  cat_web_application ;;
         4)  cat_exploitation ;;
         5)  cat_post_exploitation ;;
         6)  cat_password_attacks ;;
         7)  cat_wireless ;;
         8)  cat_sniffing_spoofing ;;
         9)  cat_forensics ;;
        10)  cat_reverse_engineering ;;
        11)  cat_network_attacks ;;
        12)  cat_social_engineering ;;
        13)  cat_ctf_tools ;;
        14)  cat_cloud_containers ;;
        15)  cat_anonymity ;;
        16)  install_all ;;
        17)  install_top10 ;;
        18)  setup_repos ;;
        19)  update_tools ;;
        20)  show_summary ;;
         0)
            echo -e "\n${GREEN}  Stay legal. Happy hacking. 👾${NC}\n"
            exit 0
            ;;
         *)
            echo -e "${RED}  ✗ Invalid option: ${choice}${NC}"
            ;;
    esac

    echo ""
    read -rp "  Press Enter to continue..."
done
