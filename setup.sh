#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════╗
#  ███████╗███████╗██████╗  ██████╗ ██████╗  █████╗ ███████╗ ██████╗ ██████╗
#  ██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔══██╗██╔══██╗██╔════╝██╔═══██╗██╔══██╗
#  █████╗  █████╗  ██║  ██║██║   ██║██████╔╝███████║█████╗  ██║   ██║██████╔╝
#  ██╔══╝  ██╔══╝  ██║  ██║██║   ██║██╔══██╗██╔══██║██╔══╝  ██║   ██║██╔══██╗
#  ██║     ███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║██║     ╚██████╔╝██║  ██║
#  ╚═╝     ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝
#
#      Invisible Migration from Windows + Full Setup + Easy of Comfort
#   Version: 2.0.v
#   Modules: Winboat · Browsers Hardening · Security · VPN · Privacy · More
# ╚══════════════════════════════════════════════════════════════════════════╝

# -e  : exit on first error
# -u  : treat unset variables as errors  (catches typos)
# -o pipefail : propagate pipe failures  (e.g. curl | jq)
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

#===========================================
# PROGRESS / SPINNER UTILITIES
#===========================================

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

print_progress_bar() {
    local current=$1 total=$2 label="${3:-}"
    local width=40
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    local bar
    bar="$(printf '%0.s█' $(seq 1 $filled))$(printf '%0.s░' $(seq 1 $empty))"
    printf "  [%s] %d/%d %s\r" "$bar" "$current" "$total" "$label"
    [[ "$current" -eq "$total" ]] && printf "\n"
}

# Directories
GITHUB_DIR="$HOME/GitHub"
LOCAL_BIN="$HOME/.local/bin"
APPIMAGE_DIR="$HOME/Applications"
JSHIELDER_BACKUP_DIR="$HOME/jshielder_backups_$(date +%Y%m%d_%H%M%S)"

# Log file
LOG_FILE="$HOME/setup_log_$(date +%Y%m%d_%H%M%S).txt"

# ── sudo keepalive ─────────────────────────────────────────────────────
_sudo_keepalive() {
    while true; do sudo -n true; sleep 55; done 2>/dev/null &
    _SUDO_KA_PID=$!
    trap 'kill "$_SUDO_KA_PID" 2>/dev/null' EXIT
}

#===========================================
# PACKAGE LISTS
#===========================================

DNF_PACKAGES=(
    # Development
    git
    make
    cmake
    python3
    python3-pip
    nodejs
    npm
    vscodium

    # Utilities
    fastfetch
    tmux
    curl
    wget
    unzip
    jq
    fzf
    lazygit
    rust

    # Games
    dosbox
    wine
    steam
    playonlinux
    lutris

    # Applications
    showtime
    papers

    # System
    dnf-plugins-core
    thunderbird
    baobab
    gnome-disks

    # Fonts
    fira-code-fonts
    jetbrains-mono-fonts
)

FLATPAK_PACKAGES=(
    # Communication
    "com.discordapp.Discord"
    #"org.telegram.desktop"
    "org.signal.Signal"

    # Productivity
    #"md.obsidian.Obsidian"
    "org.onlyoffice.desktopeditors"

    # Development
    "io.podman_desktop.PodmanDesktop"

    # Creativity
    "org.blender.Blender"
    "org.kde.krita"
    "org.kde.kdenlive"
    "org.synfig.SynfigStudio"

    # Games
    "com.heroicgameslauncher.hgl"
    "io.github.fastrizwaan.WineZGUI"

    # Multimedia
    "com.spotify.Client"
    "org.videolan.VLC"
    "org.jdownloader.JDownloader"
    "org.mixxx.Mixxx"
    "org.qbittorrent.qBittorrent"

    # Browsers
    #"com.brave.Browser"
    "app.zen_browser.zen"
    "io.gitlab.librewolf-community"

    # Utilities
    #"org.flameshot.Flameshot"
    #"io.github.peazip.PeaZip"
    #"io.github.ilya_zlobintsev.LACT"
    "org.localsend.localsend_app"
    "com.github.wwmm.easyeffects"
)

# GitHub Repositories
# Format: "repo_url|branch|install_type|install_command"
GITHUB_REPOS=(
    "https://github.com/dreamsofautonomy/zensh.git|main|clone|"
)

# GitHub Releases (binary downloads)
# Format: "repo|binary_name|asset_pattern"
GITHUB_RELEASES=(
    "jesseduffield/lazygit|lazygit|lazygit_.*_Linux_x86_64.tar.gz"
    "junegunn/fzf|fzf|fzf-.*-linux_amd64.tar.gz"
    "sharkdp/bat|bat|bat-.*-x86_64-unknown-linux-gnu.tar.gz"
    "BurntSushi/ripgrep|rg|ripgrep-.*-x86_64-unknown-linux-musl.tar.gz"
)

#===========================================
# HELPER FUNCTIONS
#===========================================

print_header() {
    echo ""
    echo -e "${GREEN}==> ${NC}${1}"
    echo "------------------------------------------------------------"
}

print_section() {
    echo -e "\n${CYAN}>>> $1${NC}\n"
}

print_success() {
    echo -e "${GREEN}  ✓ $1${NC}"
}

print_error() {
    echo -e "${RED}  ✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}  ! $1${NC}"
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_command() {
    command -v "$1" &>/dev/null
}

confirm_action() {
    local response
    read -rp "  $1 [y/N]: " response
    case "$response" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

create_directories() {
    mkdir -p "$GITHUB_DIR" "$LOCAL_BIN" "$APPIMAGE_DIR"

    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        export PATH="$LOCAL_BIN:$PATH"
    fi

    if [[ -f "$HOME/.zshrc" ]] && ! grep -q 'local/bin' "$HOME/.zshrc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi

    if check_command fish; then
        fish -c "fish_add_path $LOCAL_BIN" 2>/dev/null || true
    fi
}

#===========================================
# INSTALLATION FUNCTIONS
#===========================================

setup_repositories() {
    print_header "Setting Up Repositories"

    print_section "Installing RPM Fusion Free"
    if ! rpm -q rpmfusion-free-release &>/dev/null; then
        run_with_spinner "Installing RPM Fusion Free..." \
            sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
        print_success "RPM Fusion Free installed"
    else
        print_warning "RPM Fusion Free already installed"
    fi

    print_section "Installing RPM Fusion Non-Free"
    if ! rpm -q rpmfusion-nonfree-release &>/dev/null; then
        run_with_spinner "Installing RPM Fusion Non-Free..." \
            sudo dnf install -y \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
        print_success "RPM Fusion Non-Free installed"
    else
        print_warning "RPM Fusion Non-Free already installed"
    fi

    print_section "Setting up Flathub"
    run_with_spinner "Adding Flathub remote..." \
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    print_success "Flathub configured"

    print_section "Adding Terra repository (fyralabs)"
    if dnf repolist | grep -q "terra"; then
        print_warning "Terra repo already configured"
    else
        run_with_spinner "Adding Terra repository..." \
            sudo dnf install -y --nogpgcheck \
                --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
                terra-release
        print_success "Terra repository added"
    fi
}

install_dnf_packages() {
    print_header "Installing DNF Packages"

    print_section "Updating system"
    run_with_spinner "Updating system packages (dnf update)..." sudo dnf update -y
    print_success "System up to date"

    print_section "Checking installed packages"
    local installed_rpms to_install=() already=() missing=() pkg total_pkgs i=0
    installed_rpms=$(rpm -qa --qf '%{NAME}\n')
    total_pkgs=${#DNF_PACKAGES[@]}

    for pkg in "${DNF_PACKAGES[@]}"; do
        (( i++ )) || true
        printf "  [checking] %d/%d  %-30s\n" "$i" "$total_pkgs" "$pkg"
        if echo "$installed_rpms" | grep -qx "$pkg"; then
            already+=("$pkg")
        else
            missing+=("$pkg")
            to_install+=("$pkg")
        fi
    done

    echo ""
    [[ ${#already[@]} -gt 0 ]] && echo -e "  ${YELLOW}Already installed (${#already[@]}):${NC} ${already[*]}"
    [[ ${#missing[@]} -gt 0 ]] && echo -e "  ${CYAN}To install (${#missing[@]}):${NC} ${missing[*]}"
    echo ""

    if [[ ${#to_install[@]} -eq 0 ]]; then
        print_success "All packages already installed"
        return
    fi

    print_section "Installing ${#to_install[@]} package(s) in one transaction..."
    run_with_spinner "Installing DNF packages..." \
        sudo dnf install -y --setopt=install_weak_deps=False --setopt=tsflags=nodocs "${to_install[@]}"
    local _dnf_rc=$?
    if [[ $_dnf_rc -eq 0 ]]; then
        print_success "All packages installed"
    else
        print_error "Some packages failed (exit $_dnf_rc) — check $LOG_FILE"
        log "DNF batch install had failures (exit $_dnf_rc)"
    fi
}

install_flatpak_packages() {
    print_header "Installing Flatpak Applications"

    local installed_list
    installed_list=$(flatpak list --app --columns=application 2>/dev/null)

    local to_install=() already=() missing=() app total_apps i=0
    total_apps=${#FLATPAK_PACKAGES[@]}
    for app in "${FLATPAK_PACKAGES[@]}"; do
        (( i++ )) || true
        printf "  [checking] %d/%d  %-40s\n" "$i" "$total_apps" "$app"
        if echo "$installed_list" | grep -qF "$app"; then
            already+=("$app")
        else
            missing+=("$app")
            to_install+=("$app")
        fi
    done

    echo ""
    [[ ${#already[@]} -gt 0 ]] && echo -e "  ${YELLOW}Already installed (${#already[@]}):${NC} ${already[*]}"
    [[ ${#missing[@]} -gt 0 ]] && echo -e "  ${CYAN}To install (${#missing[@]}):${NC} ${missing[*]}"
    echo ""

    if [[ ${#to_install[@]} -eq 0 ]]; then
        print_success "All Flatpak apps already installed"
        return
    fi

    local flathub_apps=() zen_pending=false
    for app in "${to_install[@]}"; do
        if [[ "$app" == "app.zen_browser.zen" ]]; then
            zen_pending=true
        else
            flathub_apps+=("$app")
        fi
    done

    if [[ ${#flathub_apps[@]} -gt 0 ]]; then
        local total_fp=${#flathub_apps[@]} fp_i=0 fp_failed=()
        print_section "Installing ${#flathub_apps[@]} Flatpak app(s) from Flathub..."
        for app in "${flathub_apps[@]}"; do
            (( fp_i++ )) || true
            local short_name="${app##*.}"
            if run_with_spinner "[${fp_i}/${total_fp}] ${short_name}..." \
                    flatpak install -y --noninteractive flathub "$app"; then
                print_success "[${fp_i}/${total_fp}] ${app}"
                log "Flatpak installed: ${app}"
            else
                print_error "[${fp_i}/${total_fp}] Failed: ${app}"
                fp_failed+=("$app")
                log "Flatpak FAILED: ${app}"
            fi
        done
        if [[ ${#fp_failed[@]} -eq 0 ]]; then
            print_success "All Flatpak apps installed successfully"
        else
            print_warning "Failed apps (${#fp_failed[@]}): ${fp_failed[*]}"
            print_warning "Check $LOG_FILE for details"
        fi
    fi

    if $zen_pending; then
        print_section "Installing Zen Browser..."
        flatpak remote-add --if-not-exists zen-browser \
            https://download.opensuse.org/repositories/home:/bgstack15:/aftermoz/AppStream/home:bgstack15:aftermoz.flatpakrepo \
            2>/dev/null || true
        if run_with_spinner "[Zen] Installing Zen Browser..." \
                flatpak install -y --noninteractive flathub app.zen_browser.zen 2>/dev/null; then
            print_success "Zen Browser installed from Flathub"
        elif run_with_spinner "[Zen] Installing Zen Browser (alt remote)..." \
                flatpak install -y --noninteractive zen-browser app.zen_browser.zen 2>/dev/null; then
            print_success "Zen Browser installed"
        else
            print_warning "Zen Browser could not be installed automatically — install manually from https://flathub.org/apps/app.zen_browser.zen"
            log "Zen Browser install failed — manual install required"
        fi
    fi
}

clone_github_repos() {
    print_header "Cloning GitHub Repositories"

    pushd "$GITHUB_DIR" > /dev/null

    local repo_entry repo_url branch install_type install_cmd repo_name
    local gr_total=${#GITHUB_REPOS[@]} gr_i=0
    for repo_entry in "${GITHUB_REPOS[@]}"; do
        (( gr_i++ )) || true
        IFS='|' read -r repo_url branch install_type install_cmd <<< "$repo_entry"
        repo_name=$(basename "$repo_url" .git)

        printf "\n  [%d/%d] %s\n" "$gr_i" "$gr_total" "$repo_name"

        if [[ -d "$repo_name" ]]; then
            run_with_spinner "[${gr_i}/${gr_total}] Pulling latest: ${repo_name}..." \
                git -C "$repo_name" pull origin "$branch"
            print_success "[${gr_i}/${gr_total}] Updated: $repo_name"
        else
            if run_with_spinner "[${gr_i}/${gr_total}] Cloning: ${repo_name}..." \
                    git clone --branch "$branch" "$repo_url" "$repo_name"; then
                print_success "[${gr_i}/${gr_total}] Cloned: $repo_name"
            else
                print_error "[${gr_i}/${gr_total}] Clone failed: $repo_name"
                log "Git clone failed: $repo_url"
                continue
            fi
        fi

        cd "$repo_name"

        case "$install_type" in
            clone)
                print_success "Clone only — no build needed"
                ;;
            make)
                if run_with_spinner "[${gr_i}/${gr_total}] Building (make): ${repo_name}..." \
                        bash -c "$install_cmd"; then
                    print_success "Build completed: $repo_name"
                else
                    print_error "Build failed: $repo_name"
                fi
                ;;
            cmake)
                mkdir -p build && cd build
                if run_with_spinner "[${gr_i}/${gr_total}] Building (cmake): ${repo_name}..." \
                        bash -c "cmake .. && make && sudo make install"; then
                    print_success "Build completed: $repo_name"
                else
                    print_error "Build failed: $repo_name"
                fi
                cd ..
                ;;
            script)
                if [[ -f "$install_cmd" ]]; then
                    chmod +x "$install_cmd"
                    if run_with_spinner "[${gr_i}/${gr_total}] Running script: ${repo_name}..." \
                            ./"$install_cmd"; then
                        print_success "Script completed: $repo_name"
                    else
                        print_error "Script failed: $repo_name"
                    fi
                fi
                ;;
            cargo)
                if run_with_spinner "[${gr_i}/${gr_total}] Building (cargo): ${repo_name}..." \
                        bash -c "$install_cmd"; then
                    cp target/release/* "$LOCAL_BIN/" 2>/dev/null || true
                    print_success "Build completed: $repo_name"
                else
                    print_error "Build failed: $repo_name"
                fi
                ;;
            go)
                if run_with_spinner "[${gr_i}/${gr_total}] Building (go): ${repo_name}..." \
                        go build -o "$LOCAL_BIN/$repo_name"; then
                    print_success "Build completed: $repo_name"
                else
                    print_error "Build failed: $repo_name"
                fi
                ;;
            npm)
                if run_with_spinner "[${gr_i}/${gr_total}] Installing (npm): ${repo_name}..." \
                        bash -c "npm install && npm run build --if-present"; then
                    print_success "Build completed: $repo_name"
                else
                    print_error "Build failed: $repo_name"
                fi
                ;;
        esac

        popd > /dev/null && pushd "$GITHUB_DIR" > /dev/null
    done
    popd > /dev/null
}

install_github_releases() {
    print_header "Installing GitHub Releases"

    if ! check_command jq; then
        print_warning "jq not found — installing..."
        sudo dnf install -y jq 2>&1 | tee -a "$LOG_FILE" > /dev/null
    fi

    local temp_dir
    temp_dir=$(mktemp -d)

    _fetch_and_install_one() {
        local entry="$1" tdir="$2"
        local repo binary_name asset_pattern
        IFS='|' read -r repo binary_name asset_pattern <<< "$entry"

        if check_command "$binary_name"; then
            log "Already installed: $binary_name"
            return 0
        fi

        local api_url="https://api.github.com/repos/$repo/releases/latest"
        local download_url
        download_url=$(curl -sf "$api_url" \
            | jq -r ".assets[] | select(.name | test(\"$asset_pattern\")) | .browser_download_url" \
            | head -1) || true

        if [[ -z "$download_url" || "$download_url" == "null" ]]; then
            log "Asset not found: $binary_name"
            return 1
        fi

        local filename dl_dir
        filename=$(basename "$download_url")
        dl_dir="$tdir/$binary_name"
        mkdir -p "$dl_dir"

        if ! curl -sL "$download_url" -o "$dl_dir/$filename"; then
            log "Download failed: $binary_name"
            return 1
        fi

        cd "$dl_dir"
        case "$filename" in
            *.tar.gz|*.tgz) tar -xzf "$filename" ;;
            *.zip)          unzip -q "$filename" ;;
            *)
                chmod +x "$filename"
                cp "$filename" "$LOCAL_BIN/$binary_name"
                log "Installed $binary_name"
                return
                ;;
        esac

        local binary_path
        binary_path=$(find . -name "$binary_name" -type f -executable 2>/dev/null | head -1) || true
        [[ -z "$binary_path" ]] && \
            binary_path=$(find . -name "$binary_name" -type f 2>/dev/null | head -1) || true

        if [[ -n "$binary_path" ]]; then
            chmod +x "$binary_path"
            cp "$binary_path" "$LOCAL_BIN/$binary_name"
            log "Installed $binary_name to $LOCAL_BIN"
        else
            log "Binary not found in archive: $binary_name"
            return 1
        fi
    }

    local gr_total=${#GITHUB_RELEASES[@]} gr_i=0 failed=0 entry
    for entry in "${GITHUB_RELEASES[@]}"; do
        (( gr_i++ )) || true
        local _bin_name
        _bin_name=$(echo "$entry" | cut -d'|' -f2)
        if run_with_spinner "[${gr_i}/${gr_total}] ${_bin_name}..." \
                bash -c "_fetch_and_install_one $(printf %q "$entry") $(printf %q "$temp_dir")"; then
            print_success "[${gr_i}/${gr_total}] $_bin_name installed"
        else
            print_error "[${gr_i}/${gr_total}] $_bin_name failed — check $LOG_FILE"
            (( failed++ )) || true
        fi
    done

    [[ $failed -gt 0 ]] && print_warning "$failed download(s) had issues — check $LOG_FILE"
    print_success "GitHub Releases done"
    rm -rf "$temp_dir"
}

#===========================================
# OH MY POSH & FASTFETCH
#===========================================

install_oh_my_posh() {
    print_header "Installing Oh My Posh"

    if check_command oh-my-posh; then
        print_warning "Oh My Posh already installed"
    else
        print_section "Downloading Oh My Posh..."
        curl -s https://ohmyposh.dev/install.sh -o /tmp/omp_install.sh
        run_with_spinner "Installing Oh My Posh..." bash /tmp/omp_install.sh -d "$LOCAL_BIN"
        rm -f /tmp/omp_install.sh
    fi

    mkdir -p "$HOME/.config/oh-my-posh/themes"

    run_with_spinner "Downloading Oh My Posh themes..." \
        curl -sL https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip \
        -o /tmp/themes.zip
    unzip -o -q /tmp/themes.zip -d "$HOME/.config/oh-my-posh/themes"
    rm /tmp/themes.zip
    chmod u+rw "$HOME/.config/oh-my-posh/themes"/*.json 2>/dev/null || true

    # ── Bash ──
    if ! grep -q "oh-my-posh" "$HOME/.bashrc"; then
        cat >> "$HOME/.bashrc" << 'EOF'

# Oh My Posh
eval "$(oh-my-posh init bash --config $HOME/.config/oh-my-posh/themes/clean-detailed.omp.json)"
EOF
        print_success "Oh My Posh wired into .bashrc"
    else
        print_warning "Oh My Posh already in .bashrc"
    fi

    # ── Zsh ──
    if [[ -f "$HOME/.zshrc" ]]; then
        if ! grep -q "oh-my-posh" "$HOME/.zshrc"; then
            cat >> "$HOME/.zshrc" << 'EOF'

# Oh My Posh
if command -v oh-my-posh &>/dev/null; then
    eval "$(oh-my-posh init zsh --config $HOME/.config/oh-my-posh/themes/clean-detailed.omp.json)"
fi
EOF
            print_success "Oh My Posh wired into .zshrc"
        else
            print_warning "Oh My Posh already in .zshrc"
        fi
    fi

    # ── Fish ──
    local FISH_CONF="$HOME/.config/fish/config.fish"
    if [[ -f "$FISH_CONF" ]]; then
        if ! grep -q "oh-my-posh" "$FISH_CONF"; then
            printf '\n# Oh My Posh\nif type -q oh-my-posh\n    oh-my-posh init fish --config $HOME/.config/oh-my-posh/themes/clean-detailed.omp.json | source\nend\n' >> "$FISH_CONF"
            print_success "Oh My Posh wired into config.fish"
        else
            print_warning "Oh My Posh already in config.fish"
        fi
    fi

    print_success "Oh My Posh installed"
    echo -e "  ${CYAN}Available themes: ~/.config/oh-my-posh/themes/${NC}"
    echo ""
    echo -e "  ${YELLOW}Popular themes:${NC}"
    echo -e "    - agnoster  - atomic  - dracula  - gruvbox"
    echo -e "    - catppuccin  - tokyo  - night-owl  - powerlevel10k_rainbow"
}

#===========================================
# ZSH SETUP (CachyOS-style)
#===========================================

install_zsh() {
    print_header "Install & Configure Zsh"

    if ! check_command zsh; then
        run_with_spinner "Installing zsh..." sudo dnf install -y zsh
        print_success "zsh installed"
    else
        print_warning "zsh already installed: $(zsh --version)"
    fi

    print_section "Installing zsh plugins (DNF)"
    run_with_spinner "Installing zsh plugins..." \
        sudo dnf install -y zsh-autosuggestions zsh-syntax-highlighting
    print_success "zsh-autosuggestions + zsh-syntax-highlighting installed"

    if ! check_command zoxide; then
        if check_command cargo; then
            run_with_spinner "Installing zoxide (cargo)..." cargo install zoxide --locked
        else
            run_with_spinner "Installing zoxide (DNF)..." sudo dnf install -y zoxide
        fi
        print_success "zoxide installed"
    fi

    if ! check_command eza; then
        run_with_spinner "Installing eza..." sudo dnf install -y eza
        print_success "eza installed"
    fi

    if ! check_command thefuck; then
        if check_command pip3; then
            run_with_spinner "Installing thefuck..." \
                bash -c 'pip3 install thefuck --user --break-system-packages 2>/dev/null \
                         || pip3 install thefuck --user'
            print_success "thefuck installed"
        else
            print_warning "pip3 not found — skipping thefuck"
        fi
    fi

    if ! check_command fzf; then
        run_with_spinner "Installing fzf..." sudo dnf install -y fzf
        print_success "fzf installed"
    fi

    print_section "Writing ~/.zshrc"
    local ZSHRC="$HOME/.zshrc"
    [[ -f "$ZSHRC" ]] && cp "$ZSHRC" "${ZSHRC}.bak_$(date +%Y%m%d_%H%M%S)"

    cat > "$ZSHRC" << 'ZSHRC_CONTENT'
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
bindkey -e

autoload -Uz compinit
compinit

# Fastfetch
if command -v fastfetch &>/dev/null; then
    fastfetch
fi

# Syntax highlighting
[[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Autosuggestions
[[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#808080"

# FZF fuzzy finder
if command -v fzf &>/dev/null; then
    eval "$(fzf --zsh)"
fi

export HISTSIZE=10000
export SAVEHIST=10000

# Oh My Posh prompt
if command -v oh-my-posh &>/dev/null; then
    eval "$(oh-my-posh init zsh --config $HOME/.config/oh-my-posh/themes/agnoster.omp.json)"
fi
ZSHRC_CONTENT

    print_success "$HOME/.zshrc written"

    echo ""
    read -rp "  Set zsh as your default shell? [y/N]: " set_default
    if [[ "$set_default" =~ ^[Yy]$ ]]; then
        local ZSH_PATH
        ZSH_PATH=$(which zsh)
        if grep -qF "$ZSH_PATH" /etc/shells; then
            chsh -s "$ZSH_PATH"
            print_success "Default shell set to zsh — re-login to apply"
        else
            print_warning "$ZSH_PATH not in /etc/shells — adding it..."
            echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
            chsh -s "$ZSH_PATH"
            print_success "Default shell set to zsh — re-login to apply"
        fi
    fi

    print_success "Zsh setup complete!"
    echo -e "  ${CYAN}Config: ~/.zshrc${NC}"
    echo -e "  ${CYAN}Backup: ~/.zshrc.bak_*${NC}"
    log "Zsh installed and configured"
}

#===========================================
# FISH SETUP (CachyOS-style)
#===========================================

install_fish() {
    print_header "Install & Configure Fish Shell (CachyOS-style)"

    if ! check_command fish; then
        run_with_spinner "Installing fish..." sudo dnf install -y fish
        print_success "fish installed: $(fish --version)"
    else
        print_warning "fish already installed: $(fish --version)"
    fi

    print_section "Installing fisher (plugin manager)"
    if fish -c "type -q fisher" 2>/dev/null; then
        print_warning "fisher already installed"
    else
        run_with_spinner "Installing fisher..." \
            fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher" || true
        print_success "fisher installed"
    fi

    print_section "Installing fish plugins"
    run_with_spinner "Installing autopair.fish..." \
        fish -c "fisher install jorgebucaran/autopair.fish" || true
    print_success "autopair.fish"

    run_with_spinner "Installing fzf.fish..." \
        fish -c "fisher install PatrickF1/fzf.fish" || true
    print_success "fzf.fish (Ctrl+R history, Ctrl+T files, Alt+C dirs)"

    run_with_spinner "Installing sponge..." \
        fish -c "fisher install meaningful-ooo/sponge" || true
    print_success "sponge (cleans bad commands from history)"

    run_with_spinner "Installing tide prompt..." \
        fish -c "fisher install IlanCosman/tide@v6" || true
    print_success "tide prompt installed"

    if ! check_command zoxide; then
        run_with_spinner "Installing zoxide..." sudo dnf install -y zoxide
    fi

    print_section "Writing CachyOS-style config.fish"
    local FISH_CFG="$HOME/.config/fish/config.fish"
    mkdir -p "$HOME/.config/fish"
    [[ -f "$FISH_CFG" ]] && cp "$FISH_CFG" "${FISH_CFG}.bak_$(date +%Y%m%d_%H%M%S)"

    cat > "$FISH_CFG" << 'FISH_CONTENT'
# ─────────────────────────────────────────────────────────────────
#  ~/.config/fish/config.fish  ─  CachyOS-inspired configuration
# ─────────────────────────────────────────────────────────────────

set -g fish_greeting ""

fish_add_path $HOME/.local/bin
fish_add_path $HOME/bin

set -gx EDITOR nvim
set -gx VISUAL $EDITOR
set -gx PAGER "bat --paging=always"

set -gx FZF_DEFAULT_OPTS \
    '--height 40% --layout=reverse --border \
     --color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 \
     --color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 \
     --color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796'

if command -q fd
    set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
    set -gx FZF_CTRL_T_COMMAND  $FZF_DEFAULT_COMMAND
    set -gx FZF_ALT_C_COMMAND   'fd --type d --hidden --follow --exclude .git'
end

if command -q zoxide
    zoxide init fish --cmd cd | source
end

if command -q thefuck
    thefuck --alias | source
end

if command -q eza
    alias ls  'eza --icons --group-directories-first'
    alias ll  'eza -lah --icons --group-directories-first --git'
    alias lt  'eza --tree --level=2 --icons'
    alias la  'eza -a --icons --group-directories-first'
else
    alias ls  'ls --color=auto'
    alias ll  'ls -lahF --color=auto'
end

if command -q bat
    alias cat 'bat --style=plain --paging=never'
end

alias grep  'grep --color=auto'
alias ip    'ip --color=auto'

alias gs    'git status'
alias ga    'git add'
alias gc    'git commit'
alias gp    'git push'
alias gl    'git log --oneline --graph --decorate'
alias gd    'git diff'

alias rm    'rm -I'
alias cp    'cp -i'
alias mv    'mv -i'

alias ..    'cd ..'
alias ...   'cd ../..'

alias update  'sudo dnf update -y'
alias pkgs    'sudo dnf install'
alias flatup  'flatpak update -y'

if type -q oh-my-posh
    oh-my-posh init fish --config $HOME/.config/oh-my-posh/themes/agnoster.omp.json | source
end

if type -q fastfetch
    fastfetch
end
FISH_CONTENT

    print_success "config.fish written"

    print_section "Setting up fish abbreviations"
    cat > "$HOME/.config/fish/conf.d/abbr.fish" << 'ABBR_CONTENT'
abbr --add dnfi  'sudo dnf install'
abbr --add dnfr  'sudo dnf remove'
abbr --add dnfs  'dnf search'
abbr --add dnfu  'sudo dnf update -y'
abbr --add fpi   'flatpak install flathub'
abbr --add fpu   'flatpak update -y'
abbr --add fpr   'flatpak remove'
abbr --add gcm   'git commit -m'
abbr --add gca   'git commit --amend --no-edit'
abbr --add gco   'git checkout'
abbr --add gcb   'git checkout -b'
abbr --add gst   'git stash'
abbr --add gstp  'git stash pop'
abbr --add lg    'lazygit'
ABBR_CONTENT

    print_success "fish abbreviations written to ~/.config/fish/conf.d/abbr.fish"

    print_section "Configuring tide prompt"
    if fish -c "type -q tide" 2>/dev/null; then
        run_with_spinner "Configuring tide prompt..." \
            fish -c "tide configure --auto --style=Rainbow --prompt_colors='16 colors' \
                --show_time='12-hour format' --rainbow_prompt_separators=Slanted \
                --powerline_prompt_heads=Sharp --powerline_prompt_tails=Flat \
                --powerline_prompt_style='Two lines, character and frame' \
                --prompt_connection=Dotted --powerline_right_prompt_frame=No \
                --prompt_connection_andor_frame_color=Dark --prompt_spacing=Sparse \
                --icons='Many icons' --transient=No" || true
        print_success "tide prompt configured (rainbow / slanted separators)"
    else
        print_warning "tide not found — skipping auto-config (run 'tide configure' manually)"
    fi

    echo ""
    read -rp "  Set fish as your default shell? [y/N]: " set_default_fish
    if [[ "$set_default_fish" =~ ^[Yy]$ ]]; then
        local FISH_PATH
        FISH_PATH=$(which fish)
        if grep -qF "$FISH_PATH" /etc/shells; then
            chsh -s "$FISH_PATH"
            print_success "Default shell set to fish — re-login to apply"
        else
            print_warning "$FISH_PATH not in /etc/shells — adding it..."
            echo "$FISH_PATH" | sudo tee -a /etc/shells > /dev/null
            chsh -s "$FISH_PATH"
            print_success "Default shell set to fish — re-login to apply"
        fi
    fi

    print_success "Fish shell setup complete!"
    echo -e "  ${CYAN}Config:  ~/.config/fish/config.fish${NC}"
    echo -e "  ${CYAN}Abbrevs: ~/.config/fish/conf.d/abbr.fish${NC}"
    echo -e "  ${YELLOW}Tip: run 'tide configure' anytime to change the prompt style${NC}"
    echo -e "  ${YELLOW}Tip: Ctrl+R = fzf history  •  Ctrl+T = fzf files  •  Alt+C = fzf dirs${NC}"
    log "Fish shell installed and configured"
}

configure_fastfetch() {
    print_header "Configuring Fastfetch"

    if ! check_command fastfetch; then
        print_warning "Fastfetch not installed. Installing..."
        run_with_spinner "Installing fastfetch..." sudo dnf install -y fastfetch
    fi

    mkdir -p "$HOME/.config/fastfetch"

    print_section "Creating custom configuration..."
    cat > "$HOME/.config/fastfetch/config.jsonc" << 'EOF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "source": "${HOME}/.config/fastfetch/photo.png",
        "type": "kitty",
        "height": 20,
        "padding": {
            "left": 3,
            "top": 1
        }
    },
    "modules": [
        "title",
        "separator",
        "os",
        "host",
        { "type": "kernel", "format": "{release}" },
        "uptime",
        { "type": "packages", "combined": true },
        "shell",
        { "type": "display", "compactType": "original", "key": "Resolution" },
        "de",
        "wm",
        "wmtheme",
        "terminal",
        { "type": "terminalfont", "format": "{/name}{-}{/}{name}{?size} {size}{?}" },
        "cpu",
        { "type": "gpu", "key": "GPU", "format": "{name}" },
        { "type": "memory", "format": "{used} / {total}" },
        { "type": "disk", "key": "Disk (/)", "folders": "/" },
        "break",
        "colors",
        "break"
    ]
}
EOF

    print_success "Custom config created"

    echo ""
    read -p "  Run fastfetch on terminal startup? [y/N]: " add_startup
    if [[ "$add_startup" =~ ^[Yy]$ ]]; then
        if ! grep -q "fastfetch" "$HOME/.bashrc"; then
            printf '\n# Fastfetch on startup\nif command -v fastfetch &>/dev/null; then\n    fastfetch\nfi\n' >> "$HOME/.bashrc"
            print_success "Added fastfetch to .bashrc"
        else
            print_warning "Fastfetch already in .bashrc"
        fi

        if [[ -f "$HOME/.zshrc" ]]; then
            if ! grep -q "fastfetch" "$HOME/.zshrc"; then
                printf '\n# Fastfetch on startup\nif command -v fastfetch &>/dev/null; then\n    fastfetch\nfi\n' >> "$HOME/.zshrc"
                print_success "Added fastfetch to .zshrc"
            else
                print_warning "Fastfetch already in .zshrc"
            fi
        fi

        local FISH_CONF="$HOME/.config/fish/config.fish"
        if [[ -f "$FISH_CONF" ]]; then
            if ! grep -q "fastfetch" "$FISH_CONF"; then
                printf '\n# Fastfetch on startup\nif type -q fastfetch\n    fastfetch\nend\n' >> "$FISH_CONF"
                print_success "Added fastfetch to config.fish"
            else
                print_warning "Fastfetch already in config.fish"
            fi
        fi
    fi

    print_success "Fastfetch configured"
    echo -e "  ${CYAN}Config location: ~/.config/fastfetch/config.jsonc${NC}"
}

#===========================================
# NVIDIA DRIVERS
#===========================================

install_nvidia_drivers() {
    print_header "Installing NVIDIA Drivers"

    print_section "Detecting GPU..."
    local gpu_info
    gpu_info=$(lspci 2>/dev/null | grep -i nvidia | head -1) || true

    if [[ -z "$gpu_info" ]]; then
        print_warning "No NVIDIA GPU detected via lspci."
        read -p "  Continue anyway? [y/N]: " force_continue
        if [[ ! "$force_continue" =~ ^[Yy]$ ]]; then
            print_warning "Cancelled"
            return
        fi
    else
        print_success "Found: $gpu_info"
    fi

    echo ""
    echo -e "  ${CYAN}Choose driver installation method:${NC}"
    echo -e "    ${WHITE}1)${NC} Automatic (akmod-nvidia) — recommended, rebuilds on kernel update"
    echo -e "    ${WHITE}2)${NC} CUDA + drivers (akmod-nvidia + xorg-x11-drv-nvidia-cuda)"
    echo -e "    ${WHITE}3)${NC} Open kernel module (akmod-nvidia-open) — for Turing/Ampere/Ada+"
    echo -e "    ${WHITE}0)${NC} Cancel"
    echo ""
    read -p "  Select [0-3]: " nvidia_choice

    case "$nvidia_choice" in
        1)
            run_with_spinner "Installing akmod-nvidia..." sudo dnf install -y akmod-nvidia
            print_success "akmod-nvidia installed"
            ;;
        2)
            run_with_spinner "Installing akmod-nvidia + CUDA..." sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
            print_success "akmod-nvidia + CUDA installed"
            echo -e "  ${CYAN}CUDA libraries installed for GPU compute workloads${NC}"
            ;;
        3)
            run_with_spinner "Installing akmod-nvidia-open..." sudo dnf install -y akmod-nvidia-open
            print_success "akmod-nvidia-open installed"
            echo -e "  ${CYAN}Open kernel module is recommended for Turing (RTX 20xx) and newer${NC}"
            ;;
        0)
            print_warning "Cancelled"
            return
            ;;
        *)
            print_error "Invalid option"
            return
            ;;
    esac

    echo ""
    print_warning "IMPORTANT: The kernel module must finish building before rebooting."
    echo -e "  ${CYAN}Run this to confirm: ${WHITE}modinfo -F version nvidia${NC}"
    echo -e "  ${CYAN}When it shows a version number, it's safe to reboot.${NC}"
    echo ""

    read -p "  Blacklist Nouveau (open-source NVIDIA driver)? [Y/n]: " blacklist_nouveau
    if [[ ! "$blacklist_nouveau" =~ ^[Nn]$ ]]; then
        print_section "Blacklisting Nouveau..."
        sudo tee /etc/modprobe.d/blacklist-nouveau.conf > /dev/null << 'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
        if sudo dracut --force; then
            print_success "Nouveau blacklisted and initramfs rebuilt"
        else
            print_error "dracut failed — initramfs may not have been updated. Check manually."
        fi
    fi

    echo ""
    print_success "NVIDIA driver installation complete"
    echo -e "  ${YELLOW}Please reboot after the kmod finishes building.${NC}"
}

#===========================================
# APPIMAGE INSTALLER
#===========================================

install_appimages() {
    print_header "Installing AppImages"

    mkdir -p "$APPIMAGE_DIR"

    echo -e "  ${CYAN}AppImages will be saved to: ${WHITE}$APPIMAGE_DIR${NC}"
    echo ""
    echo -e "  ${CYAN}Select which AppImages to install:${NC}"
    echo -e "    ${WHITE}1)${NC} Helium Browser           — Chromium-based browser"
    echo -e "    ${WHITE}2)${NC} Capacities               — Note-taking / knowledge base app"
    echo -e "    ${WHITE}3)${NC} Linux Affinity Installer — Affinity suite via Wine (v3.0.2)"
    echo -e "    ${WHITE}4)${NC} All of the above"
    echo -e "    ${WHITE}0)${NC} Cancel"
    echo ""
    read -p "  Select [0-4]: " appimage_choice

    case "$appimage_choice" in
        1) _download_helium ;;
        2) _download_capacities ;;
        3) _download_affinity_installer ;;
        4)
            _download_helium
            _download_capacities
            _download_affinity_installer
            ;;
        0)
            print_warning "Cancelled"
            return
            ;;
        *)
            print_error "Invalid option"
            return
            ;;
    esac

    echo ""
    print_success "AppImage installation complete"
    echo -e "  ${CYAN}Location: $APPIMAGE_DIR${NC}"
    echo -e "  ${YELLOW}Tip: Add $APPIMAGE_DIR to your app launcher or run directly from terminal.${NC}"
}

_download_helium() {
    print_section "Downloading Helium Browser..."
    local api_url="https://api.github.com/repos/imputnet/helium-linux/releases/latest"
    local download_url
    download_url=$(curl -sf "$api_url" \
        | grep -oP '"browser_download_url":\s*"\K[^"]+' \
        | grep -i "\.AppImage$" \
        | grep -iv "arm\|aarch\|avx2\|SSE3\|sse3" \
        | head -1) || true

    if [[ -z "$download_url" ]]; then
        print_warning "Could not resolve latest release via API; using known release."
        download_url="https://github.com/imputnet/helium-linux/releases/download/0.9.2.1/helium-0.9.2.1-x86_64.AppImage"
    fi

    local filename dest
    filename=$(basename "$download_url")
    dest="$APPIMAGE_DIR/$filename"

    if [[ -f "$dest" ]]; then
        print_warning "Already downloaded: $filename"
        return
    fi

    if run_with_spinner "Downloading Helium Browser..." curl -sL "$download_url" -o "$dest"; then
        chmod +x "$dest"
        print_success "Helium Browser saved to $dest"
    else
        print_error "Download failed for Helium Browser"
        rm -f "$dest"
    fi
}

_download_capacities() {
    print_section "Downloading Capacities..."
    local api_url="https://api.github.com/repos/capacities-io/capacities-releases/releases/latest"
    local download_url
    download_url=$(curl -sf "$api_url" \
        | grep -oP '"browser_download_url":\s*"\K[^"]+' \
        | grep -i "\.AppImage$" \
        | head -1) || true

    if [[ -z "$download_url" ]]; then
        print_warning "Could not resolve Capacities release via API; trying official download..."
        download_url="https://cdn.capacities.io/desktop/linux/Capacities-latest.AppImage"
    fi

    local filename dest
    filename=$(basename "$download_url")
    dest="$APPIMAGE_DIR/$filename"

    if [[ -f "$dest" ]]; then
        print_warning "Already downloaded: $filename"
        return
    fi

    if run_with_spinner "Downloading Capacities..." curl -sL "$download_url" -o "$dest"; then
        chmod +x "$dest"
        print_success "Capacities saved to $dest"
    else
        print_error "Download failed for Capacities"
        rm -f "$dest"
    fi
}

_download_affinity_installer() {
    print_section "Downloading Linux Affinity Installer v3.0.2..."
    local download_url="https://github.com/ryzendew/Linux-Affinity-Installer/releases/download/3.0.2/Linux-Affinity-Installer-3.0.2.AppImage"
    local filename="Linux-Affinity-Installer-3.0.2.AppImage"
    local dest="$APPIMAGE_DIR/$filename"

    if [[ -f "$dest" ]]; then
        print_warning "Already downloaded: $filename"
        return
    fi

    if run_with_spinner "Downloading Linux Affinity Installer..." curl -sL "$download_url" -o "$dest"; then
        chmod +x "$dest"
        print_success "Linux Affinity Installer saved to $dest"
        echo -e "  ${CYAN}Run it with: ${WHITE}$dest${NC}"
        echo -e "  ${YELLOW}Note: Requires Wine/Proton to be configured. The installer will guide you.${NC}"
    else
        print_error "Download failed for Linux Affinity Installer"
        rm -f "$dest"
    fi
}

#===========================================
# CLAMAV ANTIVIRUS
#===========================================

install_clamav() {
    print_header "Installing & Configuring ClamAV Antivirus"

    print_section "Installing ClamAV packages..."
    local clamav_pkgs=(clamav clamd clamav-update)
    local clamav_to_install=() pkg
    for pkg in "${clamav_pkgs[@]}"; do
        if rpm -q "$pkg" &>/dev/null; then
            print_warning "Already installed: $pkg"
        else
            clamav_to_install+=("$pkg")
        fi
    done

    if [[ ${#clamav_to_install[@]} -gt 0 ]]; then
        sudo dnf install -y "${clamav_to_install[@]}" 2>&1 | tee -a "$LOG_FILE"
        local _cav_rc=${PIPESTATUS[0]}
        if [[ $_cav_rc -eq 0 ]]; then
            print_success "ClamAV packages installed"
        else
            print_error "ClamAV install failed (exit $_cav_rc) — check $LOG_FILE"
            return 1
        fi
    fi

    if ! command -v clamscan &>/dev/null; then
        print_error "clamscan not found after install — aborting ClamAV setup"
        return 1
    fi
    print_success "ClamAV version: $(clamscan --version 2>/dev/null | head -1)"

    print_section "Preparing clamd scan configuration..."
    local _clamd_conf="/etc/clamd.d/scan.conf"
    local _clamd_sample="/etc/clamd.d/scan.conf.sample"

    if [[ ! -f "$_clamd_conf" ]]; then
        if [[ -f "$_clamd_sample" ]]; then
            sudo cp "$_clamd_sample" "$_clamd_conf"
            print_success "Created $_clamd_conf from sample"
        else
            sudo mkdir -p /etc/clamd.d
            sudo tee "$_clamd_conf" > /dev/null << 'CLAMD_CONF'
LocalSocket /run/clamd.scan/clamd.sock
LocalSocketMode 660
FixStaleSocket yes
LocalSocketGroup virusgroup
User clamscan
LogFile /var/log/clamd.scan
LogFileMaxSize 2M
LogRotate yes
LogTime yes
PidFile /run/clamd.scan/clamd.pid
DatabaseDirectory /var/lib/clamav
MaxRecursion 16
MaxFiles 10000
CLAMD_CONF
            print_success "Created minimal $_clamd_conf"
        fi
    else
        print_warning "$_clamd_conf already exists — keeping it."
    fi

    sudo mkdir -p /run/clamd.scan
    sudo chown clamscan:clamscan /run/clamd.scan 2>/dev/null || true
    sudo chmod 750 /run/clamd.scan 2>/dev/null || true

    print_section "Updating virus database..."
    sudo systemctl stop clamav-freshclam 2>/dev/null || true
    sudo systemctl stop clamd@scan       2>/dev/null || true
    sleep 1

    if sudo freshclam --datadir=/var/lib/clamav 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Virus database updated"
    else
        print_warning "freshclam had warnings — may just be a rate-limit; continuing"
    fi

    print_section "Enabling clamav-freshclam (daily auto-update)..."
    sudo systemctl enable clamav-freshclam --now 2>&1 | tee -a "$LOG_FILE" || \
        print_warning "clamav-freshclam failed to start — check: journalctl -u clamav-freshclam"
    print_success "clamav-freshclam enabled"

    print_section "Enabling clamd@scan daemon..."
    if getent group virusgroup &>/dev/null; then
        sudo gpasswd -a "${USER}" virusgroup 2>/dev/null \
            && print_success "Added ${USER} to virusgroup" \
            || print_warning "Could not add ${USER} to virusgroup"
    else
        print_warning "virusgroup not found — skipping group add"
    fi

    sudo setfacl -R -m u:clamscan:r-X,d:u:clamscan:r-X /home 2>/dev/null || true
    sudo systemctl enable clamd@scan 2>&1 | tee -a "$LOG_FILE"
    sudo systemctl start  clamd@scan 2>&1 | tee -a "$LOG_FILE"
    sleep 2

    if systemctl is-active --quiet clamd@scan 2>/dev/null; then
        print_success "clamd@scan daemon is running"
    else
        print_warning "clamd@scan is not active — clamdscan won't work, but clamscan will."
        print_warning "Check: sudo journalctl -u clamd@scan -n 30"
    fi

    local quarantine_dir="$HOME/clamav-quarantine"
    mkdir -p "$quarantine_dir"
    print_success "Quarantine directory: $quarantine_dir"

    echo ""
    read -p "  Set up a daily scheduled scan at 1 AM? [y/N]: " setup_cron
    if [[ "$setup_cron" =~ ^[Yy]$ ]]; then
        local cron_job="0 1 * * * /usr/bin/nice -n 15 /usr/bin/clamscan -r -i --move=${quarantine_dir} /home/ >> \$HOME/clamav_scan.log 2>&1"
        if crontab -l 2>/dev/null | grep -qF "clamscan"; then
            print_warning "ClamAV cron job already exists — skipping"
        else
            ( crontab -l 2>/dev/null; echo "$cron_job" ) | crontab -
            print_success "Daily scan scheduled (1 AM, results → ~/clamav_scan.log)"
        fi
    fi

    echo ""
    read -p "  Install ClamTk graphical frontend? [y/N]: " install_clamtk
    if [[ "$install_clamtk" =~ ^[Yy]$ ]]; then
        sudo dnf install -y clamtk 2>&1 | tee -a "$LOG_FILE"
        local _ctk_rc=${PIPESTATUS[0]}
        if [[ $_ctk_rc -eq 0 ]]; then
            print_success "ClamTk installed — launch with: clamtk"
        else
            print_warning "ClamTk install failed (exit $_ctk_rc)"
        fi
    fi

    echo ""
    print_success "ClamAV setup complete!"
    echo -e "  ${CYAN}Manual scan:${NC}      sudo clamscan -r -i /home/"
    echo -e "  ${CYAN}Daemon scan:${NC}      sudo clamdscan -r -i /home/"
    echo -e "  ${CYAN}Quarantine dir:${NC}   $quarantine_dir"
    echo -e "  ${CYAN}Daemon logs:${NC}      sudo journalctl -u clamd@scan"
}

#===========================================
# LINUX SECURITY HARDENING (Chris Titus)
#===========================================

install_linux_hardening() {
    print_header "Linux Security Hardening (Chris Titus Method)"

    echo -e "  ${CYAN}Select which hardening steps to apply:${NC}"
    echo ""
    echo -e "    ${WHITE}1)${NC} Firewall (firewalld) + Fail2ban   — block attacks & brute-force"
    echo -e "    ${WHITE}2)${NC} SELinux Enforcing                 — mandatory access control"
    echo -e "    ${WHITE}3)${NC} Repository & GPG key audit        — review untrusted sources"
    echo -e "    ${WHITE}4)${NC} sysctl kernel/network hardening   — anti-spoofing, ASLR, ICMP"
    echo -e "    ${WHITE}5)${NC} All of the above"
    echo -e "    ${WHITE}0)${NC} Cancel"
    echo ""
    echo -e "  ${YELLOW}Tip: Enter multiple numbers separated by spaces (e.g. 1 4)${NC}"
    read -rp "  Select [0-5]: " harden_input

    if [[ -z "$harden_input" || "$harden_input" == "0" ]]; then
        print_warning "Cancelled"
        return
    fi

    if echo " $harden_input " | grep -q " 5 \| 5$\|^5 \|^5$"; then
        harden_input="1 2 3 4"
    fi

    _step_selected() { echo " $harden_input " | grep -qw "$1"; }

    local applied=()

    if _step_selected 1; then
        print_section "Step 1: Firewall (firewalld) + Fail2ban"
        sudo systemctl enable firewalld --now
        sleep 2
        sudo firewall-cmd --set-default-zone=public
        sudo firewall-cmd --permanent --add-service=ssh   2>/dev/null || true
        sudo firewall-cmd --permanent --add-service=http  2>/dev/null || true
        sudo firewall-cmd --permanent --add-service=https 2>/dev/null || true
        sudo firewall-cmd --permanent \
            --remove-rich-rule='rule service name="ssh" limit value="10/m" accept' 2>/dev/null || true
        sudo firewall-cmd --permanent \
            --add-rich-rule='rule service name="ssh" limit value="10/m" accept' 2>/dev/null || true
        sudo firewall-cmd --reload
        print_success "firewalld enabled — SSH rate-limited, HTTP/HTTPS open"

        if ! rpm -q fail2ban &>/dev/null; then
            sudo dnf install -y fail2ban fail2ban-firewalld 2>&1 | tee -a "$LOG_FILE" || true
        else
            print_warning "fail2ban already installed"
        fi

        sudo tee /etc/fail2ban/jail.local > /dev/null << 'F2B_EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
banaction = firewallcmd-rich-rules[actiontype=<multiport>]
banaction_allports = firewallcmd-rich-rules[actiontype=<allports>]
backend = systemd

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
maxretry = 3
bantime  = 7200
F2B_EOF

        sudo systemctl enable fail2ban --now
        print_success "fail2ban enabled — SSH: 3 retries → 2 hr ban"
        applied+=("firewalld + fail2ban")
    fi

    if _step_selected 2; then
        print_section "Step 2: SELinux Enforcing Mode"
        local selinux_status
        selinux_status=$(getenforce 2>/dev/null || echo "Unknown")
        echo "  Current SELinux state: ${selinux_status}"

        if [[ "$selinux_status" == "Enforcing" ]]; then
            print_success "SELinux is already Enforcing"
        else
            if [[ "$selinux_status" == "Permissive" ]]; then
                sudo setenforce 1 2>/dev/null || print_warning "Could not set Enforcing at runtime"
            fi
            if [[ -f /etc/selinux/config ]]; then
                sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
                print_success "SELinux set to 'enforcing' in /etc/selinux/config"
            fi
            if [[ "$selinux_status" == "Disabled" ]]; then
                sudo touch /.autorelabel
                print_warning "Filesystem relabel scheduled — next boot will relabel"
            fi
        fi
        applied+=("SELinux enforcing")
    fi

    if _step_selected 3; then
        print_section "Step 3: Repository & GPG Key Audit"
        echo ""
        echo -e "  ${CYAN}Enabled DNF repositories:${NC}"
        sudo dnf repolist enabled 2>/dev/null | awk 'NR>1 {printf "    %-40s %s\n", $1, $NF}' || true
        local repo_count
        repo_count=$(sudo dnf repolist enabled 2>/dev/null | tail -n +2 | wc -l)
        echo -e "\n  ${WHITE}Total enabled repos: ${repo_count}${NC}"
        if [[ $repo_count -gt 6 ]]; then
            echo -e "  ${YELLOW}⚠  ${repo_count} repos detected. Consider reviewing untrusted sources.${NC}"
        else
            print_success "Repo count looks reasonable (${repo_count})"
        fi
        echo ""
        echo -e "  ${CYAN}Imported GPG keys:${NC}"
        rpm -qa gpg-pubkey --qf "    %{summary}\n" 2>/dev/null | sort || true
        echo ""
        echo -e "  ${YELLOW}Tip: Remove untrusted keys with: ${WHITE}sudo rpm -e gpg-pubkey-<ID>${NC}"
        applied+=("repo/GPG audit")
    fi

    if _step_selected 4; then
        print_section "Step 4: sysctl Kernel & Network Hardening"
        sudo tee /etc/sysctl.d/99-hardening.conf > /dev/null << 'SYSCTL_EOF'
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.tcp_rfc1337 = 1
kernel.randomize_va_space = 2
kernel.kptr_restrict = 1
kernel.dmesg_restrict = 1
kernel.sysrq = 0
SYSCTL_EOF
        sudo sysctl --system &>/dev/null
        print_success "sysctl hardening applied and active"
        applied+=("sysctl hardening")
    fi

    echo ""
    if [[ ${#applied[@]} -eq 0 ]]; then
        print_warning "No valid steps were selected."
        return
    fi

    print_success "Hardening complete! Applied: ${applied[*]}"
    echo -e "  ${YELLOW}A reboot is recommended to ensure all changes are fully active.${NC}"
}

#===========================================
# JSHIELDER — FULL SYSTEM HARDENING (KDE)
#===========================================

_js_info()  { echo -e "${CYAN}  [*]${NC} $*"; log "JSHIELDER INFO: $*"; }
_js_ok()    { print_success "$*"; log "JSHIELDER OK: $*"; }
_js_warn()  { print_warning "$*"; log "JSHIELDER WARN: $*"; }
_js_err()   { print_error "$*";   log "JSHIELDER ERR: $*"; }

_js_backup() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local dest
        dest="${JSHIELDER_BACKUP_DIR}$(dirname "$file")"
        sudo mkdir -p "$dest"
        sudo cp -p "$file" "$dest/" && log "JSHIELDER BACKUP: $file → $dest/" || true
    fi
}

_js_install_tools() {
    print_section "JShielder Step 1/14: Installing Security Tools"
    _js_info "Enabling EPEL repository..."
    if ! sudo dnf repolist enabled 2>/dev/null | grep -qi epel; then
        sudo dnf install -y epel-release 2>&1 | tee -a "$LOG_FILE" > /dev/null \
            && _js_ok "EPEL enabled." \
            || _js_warn "Could not enable EPEL; some packages may be unavailable."
    else
        _js_ok "EPEL already enabled."
    fi

    local js_pkgs=(
        fail2ban fail2ban-firewalld
        rkhunter aide
        auditd audit-libs
        nmap arpwatch psad
        lynis sysstat psacct
        libpwquality usbguard
        s-nail logwatch
        policycoreutils-python-utils
        dnf-automatic
    )

    for pkg in "${js_pkgs[@]}"; do
        if sudo dnf install -y "$pkg" 2>&1 | tee -a "$LOG_FILE" > /dev/null; then
            _js_ok "Installed: $pkg"
        else
            _js_warn "Could not install: $pkg (skipping)"
        fi
    done
}

_js_hostname() {
    print_section "JShielder Step 2/14: Hostname"
    echo -e "  ${YELLOW}Current hostname: $(hostname)${NC}"
    read -rp "  Enter new hostname (blank to keep current): " _js_hn
    if [[ -n "$_js_hn" ]]; then
        sudo hostnamectl set-hostname "$_js_hn" && _js_ok "Hostname → $_js_hn"
    else
        _js_info "Hostname unchanged."
    fi
}

_js_admin_user() {
    print_section "JShielder Step 3/14: Create Secure Admin User"
    read -rp "  Enter new admin username (blank to skip): " _js_au
    [[ -z "$_js_au" ]] && { _js_warn "Skipped."; return; }

    if id "$_js_au" &>/dev/null; then
        _js_warn "User '$_js_au' already exists."
    else
        sudo useradd -m -s /bin/bash "$_js_au"
        sudo passwd "$_js_au"
        sudo usermod -aG wheel "$_js_au"
        _js_ok "User '$_js_au' created and added to wheel group."
    fi

    read -rp "  Generate ED25519 SSH key pair for $_js_au? [y/N]: " _js_gk
    if [[ "${_js_gk,,}" == "y" ]]; then
        local _js_sshd="/home/${_js_au}/.ssh"
        sudo mkdir -p "$_js_sshd"
        sudo ssh-keygen -t ed25519 -C "${_js_au}@$(hostname)" \
            -f "${_js_sshd}/id_ed25519" -N ""
        sudo bash -c "cat '${_js_sshd}/id_ed25519.pub' >> '${_js_sshd}/authorized_keys'"
        sudo chmod 700 "$_js_sshd"
        sudo chmod 600 "${_js_sshd}/authorized_keys"
        sudo chown -R "${_js_au}:${_js_au}" "$_js_sshd"
        _js_ok "ED25519 key generated: ${_js_sshd}/id_ed25519"
        _js_warn "IMPORTANT: Copy private key off server before disabling password auth!"
    fi
}

_js_harden_ssh() {
    print_section "JShielder Step 4/14: SSH Server Hardening"
    local _sshd="/etc/ssh/sshd_config"
    _js_backup "$_sshd"

    read -rp "  SSH port [default 22]: " _js_port; _js_port="${_js_port:-22}"
    read -rp "  Disable root SSH login? [Y/n]: " _js_dr;  _js_dr="${_js_dr:-y}"
    read -rp "  Disable password auth (keys only)? [y/N]: " _js_dp; _js_dp="${_js_dp:-n}"

    sudo tee "$_sshd" > /dev/null << EOF
# JShielder Fedora KDE — Hardened SSH
# Generated: $(date)

Port ${_js_port}
Protocol 2
AddressFamily inet

HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

LoginGraceTime 30
MaxAuthTries 3
MaxSessions 5
MaxStartups 3:50:10

PermitRootLogin $( [[ "${_js_dr,,}" == "y" ]] && echo "no" || echo "prohibit-password" )
StrictModes yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

PasswordAuthentication $( [[ "${_js_dp,,}" == "y" ]] && echo "no" || echo "yes" )
PermitEmptyPasswords no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
UsePAM yes

AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*

Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group14-sha256,diffie-hellman-group16-sha512

ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive no

SyslogFacility AUTH
LogLevel VERBOSE

Subsystem sftp /usr/libexec/openssh/sftp-server
EOF

    if [[ "$_js_port" != "22" ]]; then
        sudo semanage port -a -t ssh_port_t -p tcp "$_js_port" 2>>"$LOG_FILE" \
            && _js_ok "SELinux updated for port $_js_port." \
            || _js_warn "semanage failed; ensure policycoreutils-python-utils is installed."
        sudo firewall-cmd --permanent --zone=public --remove-service=ssh &>/dev/null || true
        sudo firewall-cmd --permanent --zone=public --add-port="${_js_port}/tcp"
        sudo firewall-cmd --reload
    fi

    sudo systemctl restart sshd \
        && _js_ok "SSH restarted with hardened config." \
        || _js_err "SSH restart failed — check config before logging out!"
}

_js_harden_kernel() {
    print_section "JShielder Step 5/14: Extended Kernel Hardening (sysctl)"
    _js_backup "/etc/sysctl.d/99-hardening.conf"
    sudo tee /etc/sysctl.d/99-jshielder.conf > /dev/null << 'SYSCTL_JS'
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
net.ipv4.tcp_fin_timeout = 15
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
kernel.perf_event_paranoid = 3
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_regular = 2
fs.protected_fifos = 2
SYSCTL_JS
    sudo sysctl --system &>/dev/null
    _js_ok "Extended kernel parameters applied (99-jshielder.conf)."
}

_js_disable_unused() {
    print_section "JShielder Step 6/14: Disable Unused Filesystems & Protocols"
    sudo tee /etc/modprobe.d/jshielder-blacklist.conf > /dev/null << 'MODPROBE'
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install udf /bin/true
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
install ax25 /bin/true
install netrom /bin/true
install x25 /bin/true
install rose /bin/true
install decnet /bin/true
install af_802154 /bin/true
install ipx /bin/true
install appletalk /bin/true
MODPROBE
    _js_ok "Unused filesystems and network protocols blacklisted."
}

_js_account_policy() {
    print_section "JShielder Step 7/14: Account Policy & Password Hardening"
    _js_backup "/etc/profile"
    grep -q "umask 027" /etc/profile || echo "umask 027" | sudo tee -a /etc/profile > /dev/null
    grep -q "umask 027" /etc/bashrc  || echo "umask 027" | sudo tee -a /etc/bashrc  > /dev/null
    _js_ok "UMASK set to 027."

    _js_backup "/etc/security/pwquality.conf"
    sudo tee /etc/security/pwquality.conf > /dev/null << 'PWQUAL'
minlen = 14
minclass = 4
maxrepeat = 3
lcredit = -1
ucredit = -1
dcredit = -1
ocredit = -1
difok = 8
dictcheck = 1
PWQUAL
    _js_ok "Password quality policy configured (minlen=14, 4 char classes)."

    _js_backup "/etc/login.defs"
    sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/'  /etc/login.defs
    sudo sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   7/'   /etc/login.defs
    sudo sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/'  /etc/login.defs
    sudo sed -i 's/^UMASK.*/UMASK           027/'          /etc/login.defs
    _js_ok "Password aging: max 90d, min 7d, warn 14d."

    _js_backup "/etc/security/faillock.conf"
    sudo tee /etc/security/faillock.conf > /dev/null << 'FLOCK'
deny = 5
fail_interval = 900
unlock_time = 900
silent
audit
even_deny_root
FLOCK
    _js_ok "Account lockout: 5 failures → 15-min lockout."
}

_js_auditd() {
    print_section "JShielder Step 8/14: Auditd — CIS Benchmark Rules"
    _js_backup "/etc/audit/auditd.conf"
    sudo sed -i 's/^max_log_file_action.*/max_log_file_action = ROTATE/' /etc/audit/auditd.conf
    sudo sed -i 's/^num_logs.*/num_logs = 10/'                           /etc/audit/auditd.conf
    sudo sed -i 's/^max_log_file .*/max_log_file = 50/'                  /etc/audit/auditd.conf

    sudo tee /etc/audit/rules.d/jshielder.rules > /dev/null << 'AUDITRULES'
-D
-b 8192
-f 2

-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

-w /etc/group  -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow  -p wa -k identity

-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
-w /etc/hosts         -p wa -k system-locale
-w /etc/NetworkManager -p wa -k system-locale

-w /etc/selinux/ -p wa -k MAC-policy

-w /var/log/lastlog   -p wa -k logins
-w /var/run/faillock/ -p wa -k logins

-a always,exit -F arch=b64 -S setuid -F auid>=1000 -F auid!=4294967295 -k priv_esc
-a always,exit -F arch=b32 -S setuid -F auid>=1000 -F auid!=4294967295 -k priv_esc

-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod

-w /etc/sudoers   -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope

-w /sbin/insmod  -p x -k modules
-w /sbin/rmmod   -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules

-e 2
AUDITRULES

    sudo augenrules --load 2>>"$LOG_FILE" \
        || sudo auditctl -R /etc/audit/rules.d/jshielder.rules 2>>"$LOG_FILE" \
        || _js_warn "augenrules/auditctl failed; rules will load on next reboot."
    sudo systemctl enable --now auditd \
        && _js_ok "Auditd enabled and running with CIS rules." \
        || _js_warn "Auditd failed to start — check journalctl -u auditd"
}

_js_selinux() {
    print_section "JShielder Step 9/14: SELinux Enforcement"
    local _sel
    _sel=$(getenforce 2>/dev/null || echo "Unknown")
    _js_info "Current SELinux mode: ${_sel}"

    if [[ "$_sel" == "Enforcing" ]]; then
        _js_ok "SELinux already Enforcing — no change needed."
        return
    fi

    echo -e "  ${YELLOW}1) Enforcing (recommended)  2) Permissive  3) Skip${NC}"
    read -rp "  Choice [1]: " _js_sel; _js_sel="${_js_sel:-1}"
    case "$_js_sel" in
        1)
            sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
            sudo setenforce 1 2>/dev/null || true
            [[ "$_sel" == "Disabled" ]] && sudo touch /.autorelabel \
                && _js_warn "Filesystem relabel scheduled."
            _js_ok "SELinux set to ENFORCING."
            ;;
        2)
            sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
            sudo setenforce 0 2>/dev/null || true
            _js_ok "SELinux set to PERMISSIVE."
            ;;
        *) _js_info "SELinux unchanged." ;;
    esac
}

_js_ids() {
    print_section "JShielder Step 10/14: RKHunter & AIDE File Integrity"

    if command -v rkhunter &>/dev/null; then
        sudo rkhunter --update --nocolors 2>>"$LOG_FILE" || _js_warn "rkhunter update failed."
        sudo rkhunter --propupd --nocolors 2>>"$LOG_FILE"
        sudo tee /etc/cron.weekly/rkhunter > /dev/null << 'RKCRON'
#!/bin/bash
/usr/bin/rkhunter --check --nocolors --skip-keypress 2>&1 | /usr/bin/mail -s "RKHunter - $(hostname)" root
RKCRON
        sudo chmod +x /etc/cron.weekly/rkhunter
        _js_ok "rkhunter initialized; weekly scan scheduled."
    else
        _js_warn "rkhunter not installed — run JShielder tool install step first."
    fi

    if command -v aide &>/dev/null; then
        sudo aide --init 2>>"$LOG_FILE" || true
        if sudo test -f /var/lib/aide/aide.db.new.gz; then
            sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
            _js_ok "AIDE database initialized."
        fi
        sudo tee /etc/cron.daily/aide > /dev/null << 'AIDECRON'
#!/bin/bash
/usr/sbin/aide --check 2>&1 | /usr/bin/mail -s "AIDE Integrity - $(hostname)" root
AIDECRON
        sudo chmod +x /etc/cron.daily/aide
        _js_ok "AIDE daily integrity check scheduled."
    else
        _js_warn "AIDE not installed — run JShielder tool install step first."
    fi
}

_js_secure_cron() {
    print_section "JShielder Step 11/14: Secure Cron Access"
    sudo rm -f /etc/cron.deny /etc/at.deny
    echo "root" | sudo tee /etc/cron.allow > /dev/null
    echo "root" | sudo tee /etc/at.allow   > /dev/null
    sudo chmod 600 /etc/cron.allow /etc/at.allow
    for _js_cd in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.monthly /etc/cron.weekly /etc/crontab; do
        [[ -e "$_js_cd" ]] && sudo chmod og-rwx "$_js_cd" || true
    done
    _js_ok "Cron locked — only root may schedule jobs."
}

_js_file_permissions() {
    print_section "JShielder Step 12/14: Critical File Permissions"
    local -A _js_perms=(
        ["/etc/passwd"]="644"
        ["/etc/shadow"]="000"
        ["/etc/gshadow"]="000"
        ["/etc/group"]="644"
        ["/etc/hosts"]="644"
        ["/boot/grub2/grub.cfg"]="600"
        ["/etc/ssh/sshd_config"]="600"
        ["/etc/sudoers"]="440"
        ["/etc/crontab"]="600"
        ["/etc/at.allow"]="600"
        ["/etc/cron.allow"]="600"
    )

    for _js_f in "${!_js_perms[@]}"; do
        if [[ -e "$_js_f" ]]; then
            sudo chmod "${_js_perms[$_js_f]}" "$_js_f" \
                && _js_ok "Secured: $_js_f (${_js_perms[$_js_f]})" \
                || _js_warn "Could not chmod: $_js_f"
        fi
    done

    sudo chmod 700 /root && sudo chown root:root /root
    _js_ok "Root home directory secured (700)."
}

_js_banners() {
    print_section "JShielder Step 13/14: Login Banners"
    sudo tee /etc/issue > /dev/null << 'ISSUE'

  UNAUTHORIZED ACCESS IS STRICTLY PROHIBITED
  All activity on this system is monitored and recorded.
  By continuing, you consent to this monitoring policy.
ISSUE
    sudo cp /etc/issue /etc/issue.net
    sudo chmod 644 /etc/issue /etc/issue.net
    sudo tee /etc/motd > /dev/null << 'MOTD'

  ┌─────────────────────────────────────────────────────┐
  │  WARNING: Authorized users only. All sessions are   │
  │  logged. Unauthorized use will be prosecuted.       │
  └─────────────────────────────────────────────────────┘

MOTD
    _js_ok "Login banners configured."
}

_js_kde_hardening() {
    print_section "JShielder Step 14/14: KDE Plasma Hardening"

    if [[ -d /etc/xdg ]]; then
        sudo tee /etc/xdg/kwalletrc > /dev/null << 'KWALLET'
[Wallet]
Close When Idle=true
Close Idle Timeout=10
Enabled=true
First Use=false
Launch Manager=false
KWALLET
        _js_ok "KWallet set to close after 10 minutes idle."
    fi

    sudo systemctl disable --now krfb 2>/dev/null \
        && _js_warn "KDE remote desktop (KRFB/VNC) disabled." || true

    sudo mkdir -p /etc/xdg
    sudo tee /etc/xdg/kscreenlockerrc > /dev/null << 'SCREENLOCK'
[Daemon]
Autolock=true
LockGrace=5
LockOnResume=true
Timeout=5
SCREENLOCK
    _js_ok "KDE screen lock: 5-minute auto-lock, lock on resume."

    if [[ -f /etc/sddm.conf ]]; then
        _js_backup "/etc/sddm.conf"
        sudo sed -i 's/^User=.*/User=/' /etc/sddm.conf
        sudo sed -i 's/^Session=.*/Session=/' /etc/sddm.conf
        _js_ok "SDDM autologin disabled."
    fi

    read -rp "  Disable Bluetooth? [y/N]: " _js_bt
    if [[ "${_js_bt,,}" == "y" ]]; then
        sudo systemctl disable --now bluetooth 2>/dev/null || true
        echo "install bluetooth /bin/true" \
            | sudo tee -a /etc/modprobe.d/jshielder-blacklist.conf > /dev/null
        _js_ok "Bluetooth disabled."
    fi

    read -rp "  Disable KDE file indexer (Baloo)? [y/N]: " _js_baloo
    if [[ "${_js_baloo,,}" == "y" ]]; then
        if command -v balooctl &>/dev/null; then
            balooctl disable && _js_ok "Baloo indexing disabled."
        else
            sudo tee /etc/xdg/baloofilerc > /dev/null << 'BALOO'
[Basic Settings]
Indexing-Enabled=false
BALOO
            _js_ok "Baloo disabled via /etc/xdg/baloofilerc."
        fi
    fi

    if command -v dnf-automatic &>/dev/null || sudo dnf install -y dnf-automatic 2>&1 | tee -a "$LOG_FILE" > /dev/null; then
        sudo sed -i 's/^upgrade_type.*/upgrade_type = security/'  /etc/dnf/automatic.conf 2>/dev/null || true
        sudo sed -i 's/^apply_updates.*/apply_updates = yes/'     /etc/dnf/automatic.conf 2>/dev/null || true
        sudo systemctl enable --now dnf-automatic-install.timer \
            && _js_ok "Automatic security updates enabled." \
            || _js_warn "dnf-automatic timer failed to start."
    fi

    sudo systemctl enable --now psacct  2>/dev/null && _js_ok "Process accounting (psacct) enabled." || true
    sudo systemctl enable --now sysstat 2>/dev/null && _js_ok "sysstat enabled." || true
}

install_jshielder_hardening() {
    print_header "JShielder — Full System Hardening (Fedora KDE Edition)"

    echo -e "  ${CYAN}Based on JShielder by Jason Soto (@JsiTech)${NC}"
    echo -e "  ${CYAN}https://github.com/Jsitech/JShielder${NC}"
    echo -e "  ${YELLOW}Backups saved to: ${WHITE}${JSHIELDER_BACKUP_DIR}${NC}"
    echo ""
    echo -e "  Select hardening mode:${NC}"
    echo -e "    ${WHITE}1)${NC} Full hardening (all 14 steps — recommended)"
    echo -e "    ${WHITE}2)${NC} Security tools install only"
    echo -e "    ${WHITE}3)${NC} SSH hardening only"
    echo -e "    ${WHITE}4)${NC} Kernel hardening only"
    echo -e "    ${WHITE}5)${NC} Auditd (CIS rules) only"
    echo -e "    ${WHITE}6)${NC} SELinux enforcement only"
    echo -e "    ${WHITE}7)${NC} KDE hardening only"
    echo -e "    ${WHITE}0)${NC} Cancel"
    echo ""
    read -rp "  Choice [1]: " _js_mode; _js_mode="${_js_mode:-1}"

    sudo mkdir -p "$JSHIELDER_BACKUP_DIR"
    log "JShielder hardening started — mode: $_js_mode"

    case "$_js_mode" in
        0) print_warning "JShielder cancelled."; return ;;
        1)
            _js_install_tools
            _js_hostname
            _js_admin_user
            _js_harden_ssh
            _js_harden_kernel
            _js_disable_unused
            _js_account_policy
            _js_auditd
            _js_selinux
            _js_ids
            _js_secure_cron
            _js_file_permissions
            _js_banners
            _js_kde_hardening
            ;;
        2) _js_install_tools ;;
        3) _js_harden_ssh ;;
        4) _js_harden_kernel ;;
        5) _js_auditd ;;
        6) _js_selinux ;;
        7) _js_kde_hardening ;;
        *) print_error "Invalid choice."; return ;;
    esac

    echo ""
    print_success "JShielder hardening complete!"
    echo -e "  ${CYAN}Backups:${NC} $JSHIELDER_BACKUP_DIR"
    echo -e "  ${CYAN}Log:${NC}     $LOG_FILE"
    echo ""
    echo -e "  Useful commands:${NC}"
    echo -e "    ${WHITE}sudo lynis audit system${NC}          — full security audit"
    echo -e "    ${WHITE}sudo rkhunter --check${NC}            — rootkit scan"
    echo -e "    ${WHITE}sudo fail2ban-client status sshd${NC} — view SSH bans"
    echo -e "    ${WHITE}getenforce${NC}                       — confirm SELinux state"
    echo ""
    echo -e "  ${YELLOW}⚠  A REBOOT is recommended to fully apply all changes.${NC}"
}

#===========================================
# BROWSER PRIVACY HARDENING
#===========================================

harden_browser_privacy() {
    print_header "Browser Privacy Hardening (Firefox / LibreWolf / Zen)"

    echo -e "  ${CYAN}Deploys a hardened user.js based on arkenfox to all local profiles.${NC}"
    echo ""
    echo -e "  ${YELLOW}What it hardens:${NC}"
    echo -e "    • Disables all telemetry and crash reporting"
    echo -e "    • Disables WebRTC (prevents real IP leak behind VPN/Tor)"
    echo -e "    • Disables canvas/font/screen fingerprinting APIs"
    echo -e "    • Disables geolocation"
    echo -e "    • Enforces HTTPS-only mode"
    echo -e "    • Enables DNS-over-HTTPS (Quad9)"
    echo -e "    • Strips cross-origin referrers"
    echo -e "    • Clears form data and sessions on close"
    echo -e "    • Removes Pocket, Firefox Accounts, telemetry pings"
    echo ""

    _harden_ff_profile() {
        local profile_path="$1" browser_name="$2"
        print_section "Hardening ${browser_name}: $(basename "$profile_path")"

        [[ -f "${profile_path}/user.js" ]] && \
            cp "${profile_path}/user.js" \
               "${profile_path}/user.js.bak.$(date +%Y%m%d)" \
            && print_warning "Backed up existing user.js"

        cat > "${profile_path}/user.js" << 'USERJS'
// Hardened user.js — based on arkenfox (https://github.com/arkenfox/user.js)

user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("browser.discovery.enabled", false);
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);

user_pref("privacy.resistFingerprinting", true);
user_pref("webgl.disabled", true);
user_pref("media.peerconnection.enabled", false);
user_pref("geo.enabled", false);
user_pref("browser.send_pings", false);
user_pref("dom.battery.enabled", false);

user_pref("network.http.referer.XOriginPolicy", 2);
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);
user_pref("privacy.firstparty.isolate", true);
user_pref("network.cookie.cookieBehavior", 5);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);

user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_pbm", true);

user_pref("network.trr.mode", 2);
user_pref("network.trr.uri", "https://dns.quad9.net/dns-query");
user_pref("network.trr.custom_uri", "https://dns.quad9.net/dns-query");

user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.urlbar.speculativeConnect.enabled", false);

user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("privacy.clearOnShutdown.cache", true);
user_pref("privacy.clearOnShutdown.formdata", true);
user_pref("privacy.clearOnShutdown.sessions", true);

user_pref("browser.safebrowsing.malware.enabled", false);
user_pref("browser.safebrowsing.phishing.enabled", false);
user_pref("browser.safebrowsing.downloads.enabled", false);

user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);
user_pref("extensions.pocket.enabled", false);
user_pref("identity.fxaccounts.enabled", false);
user_pref("browser.uitour.enabled", false);
USERJS
        print_success "Hardened user.js deployed → ${browser_name} profile."
        print_warning "Restart ${browser_name} to apply."
    }

    local found=0

    _scan_and_harden() {
        local base="$1" label="$2" depth="${3:-1}"
        [[ -d "$base" ]] || return 0
        while IFS= read -r profile; do
            if [[ -d "$profile" ]]; then
                _harden_ff_profile "$profile" "$label"
                found=$((found+1))
            fi
        done < <(find "$base" -maxdepth "$depth" -name "*.default*" -type d 2>/dev/null)
    }

    _scan_and_harden "$HOME/.mozilla/firefox" "Firefox"
    _scan_and_harden "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox" "Firefox (Flatpak)"
    _scan_and_harden "$HOME/.librewolf" "LibreWolf"
    _scan_and_harden "$HOME/.var/app/io.gitlab.librewolf-community/.librewolf" "LibreWolf (Flatpak)"
    _scan_and_harden "$HOME/.zen" "Zen Browser" 2
    _scan_and_harden "$HOME/.var/app/app.zen_browser.zen/.zen" "Zen Browser (Flatpak)" 2

    if [[ $found -eq 0 ]]; then
        print_warning "No browser profiles found (checked native + Flatpak locations)."
        echo -e "  ${CYAN}Launch your browser at least once to create a profile, then re-run.${NC}"
    else
        print_success "Hardened $found profile(s) across Firefox / LibreWolf / Zen Browser."
    fi
}

#=============================================================================
# PRIVACY & NETWORK — IP Privacy Manager
#=============================================================================

_PRIV_BACKUP_DIR="/etc/ip-privacy-backups"
_PRIV_STATE_FILE="/etc/ip-privacy-backups/.state"
_PRIV_TOR_USER=""
_PRIV_TOR_TRANS_PORT=9040
_PRIV_TOR_DNS_PORT=9053
_PRIV_TOR_VIRT_NET="10.192.0.0/10"

_priv_info()   { echo -e "${GREEN}[+]${NC} $*"; }
_priv_warn()   { echo -e "${YELLOW}[!]${NC} $*"; }
_priv_error()  { echo -e "${RED}[x]${NC} $*"; }
_priv_header() { echo ""; echo -e "${CYAN}── $* ──${NC}"; }

_priv_get_default_iface() {
    ip route show default 2>/dev/null | awk '/default/ {print $5; exit}'
}

_priv_get_active_connection() {
    local iface
    iface=$(_priv_get_default_iface)
    if [[ -n "$iface" ]]; then
        nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null | \
            grep "${iface}" | cut -d: -f1 | head -1
    fi
}

_priv_show_current_ip() {
    _priv_header "Current IP Information"
    local iface
    iface=$(_priv_get_default_iface)
    echo "  Interface : ${iface:-unknown}"
    echo "  Local IP  : $(ip -4 addr show "${iface}" 2>/dev/null | awk '/inet / {print $2}')"
    echo "  MAC       : $(ip link show "${iface}" 2>/dev/null | awk '/ether/ {print $2}')"
    echo "  Fetching public IP..."
    local ext_ip
    ext_ip=$(curl -s --max-time 10 https://ifconfig.me 2>/dev/null || true)
    [[ -z "$ext_ip" ]] && ext_ip=$(curl -s --max-time 10 https://icanhazip.com 2>/dev/null || echo "unavailable")
    echo "  Public IP : ${ext_ip}"
    echo ""
}

_priv_backup_file() {
    local src="$1"
    sudo mkdir -p "$_PRIV_BACKUP_DIR"
    if [[ -f "$src" && ! -f "${_PRIV_BACKUP_DIR}/$(basename "$src").orig" ]]; then
        sudo cp "$src" "${_PRIV_BACKUP_DIR}/$(basename "$src").orig"
        _priv_info "Backed up $src"
    fi
}

_priv_save_state()  { sudo mkdir -p "$_PRIV_BACKUP_DIR"; echo "$1" | sudo tee -a "$_PRIV_STATE_FILE" >/dev/null; }
_priv_clear_state() { sudo rm -f "$_PRIV_STATE_FILE"; }

_priv_detect_tor_user() {
    local candidate
    for candidate in toranon debian-tor _tor tor; do
        if id "$candidate" &>/dev/null; then
            _PRIV_TOR_USER="$candidate"
            return 0
        fi
    done
    return 1
}

_priv_find_free_port() {
    local port="$1" i=0
    while [[ $i -lt 20 ]]; do
        if ! ss -tlnup 2>/dev/null | grep -q ":${port} "; then
            echo "$port"; return 0
        fi
        port=$((port + 1)); i=$((i + 1))
    done
    _priv_error "Could not find a free port starting from $1"
    return 1
}

_priv_iptables_full_reset() {
    _priv_header "Resetting ALL iptables rules to defaults"
    local table
    for table in filter nat mangle raw security; do
        sudo iptables  -t "$table" -F 2>/dev/null || true
        sudo iptables  -t "$table" -X 2>/dev/null || true
        sudo ip6tables -t "$table" -F 2>/dev/null || true
        sudo ip6tables -t "$table" -X 2>/dev/null || true
    done
    sudo iptables  -P INPUT ACCEPT 2>/dev/null || true
    sudo iptables  -P FORWARD ACCEPT 2>/dev/null || true
    sudo iptables  -P OUTPUT ACCEPT 2>/dev/null || true
    sudo ip6tables -P INPUT ACCEPT 2>/dev/null || true
    sudo ip6tables -P FORWARD ACCEPT 2>/dev/null || true
    sudo ip6tables -P OUTPUT ACCEPT 2>/dev/null || true
    _priv_info "iptables: all rules flushed, policies set to ACCEPT."
}

_priv_check_connectivity() {
    _priv_header "Checking internet connectivity"
    local _attempt
    for _attempt in 1 2 3; do
        if curl -s --max-time 8 https://www.google.com &>/dev/null; then
            _priv_info "HTTPS connectivity: OK"
            return 0
        fi
        sleep 2
    done
    _priv_error "Internet connectivity check FAILED after 3 attempts."
    _priv_emergency_repair
    return 1
}

_priv_emergency_repair() {
    _priv_header "Emergency Network Repair"
    _priv_iptables_full_reset
    sudo rm -f /etc/resolv.conf 2>/dev/null || true
    sudo tee /etc/resolv.conf >/dev/null <<'EOF'
nameserver 45.90.28.0
nameserver 45.90.30.0
nameserver 9.9.9.9
EOF
    sudo systemctl restart NetworkManager 2>/dev/null || true
    sleep 3
    local conn
    conn=$(nmcli -t -f NAME connection show 2>/dev/null | head -1)
    if [[ -n "$conn" ]]; then
        nmcli connection down "$conn" 2>/dev/null || true
        sleep 1
        nmcli connection up "$conn" 2>/dev/null || true
        sleep 3
    fi
    if curl -s --max-time 8 https://www.google.com &>/dev/null; then
        _priv_info "Network RECOVERED!"
    else
        _priv_error "Network still down. Try: sudo systemctl restart NetworkManager"
    fi
}

_priv_install_tor() {
    if ! command -v tor &>/dev/null; then
        if ! run_with_spinner "Installing Tor..." sudo dnf install -y tor; then
            _priv_error "Failed to install Tor."
            return 1
        fi
    fi
    return 0
}

_priv_configure_tor() {
    _priv_header "Configuring Tor Transparent Proxy"
    if ! _priv_install_tor; then return 1; fi
    if ! _priv_detect_tor_user; then
        _priv_error "Cannot find Tor system user."
        return 1
    fi

    _PRIV_TOR_DNS_PORT=$(_priv_find_free_port "$_PRIV_TOR_DNS_PORT")   || return 1
    _PRIV_TOR_TRANS_PORT=$(_priv_find_free_port "$_PRIV_TOR_TRANS_PORT") || return 1

    _priv_backup_file /etc/tor/torrc

    sudo tee /etc/tor/torrc >/dev/null <<EOF
VirtualAddrNetworkIPv4 ${_PRIV_TOR_VIRT_NET}
AutomapHostsOnResolve 1
TransPort 127.0.0.1:${_PRIV_TOR_TRANS_PORT}
DNSPort 127.0.0.1:${_PRIV_TOR_DNS_PORT}
SocksPort 127.0.0.1:9050
Log notice syslog
ClientRejectInternalAddresses 1
EOF

    if [[ ! -f "${_PRIV_BACKUP_DIR}/iptables-v4-clean.rules" ]]; then
        sudo mkdir -p "$_PRIV_BACKUP_DIR"
        sudo iptables-save  2>/dev/null | sudo tee "${_PRIV_BACKUP_DIR}/iptables-v4-clean.rules" > /dev/null || true
        sudo ip6tables-save 2>/dev/null | sudo tee "${_PRIV_BACKUP_DIR}/iptables-v6-clean.rules" > /dev/null || true
    fi
    return 0
}

_priv_tor_iptables_up() {
    _priv_header "Setting up iptables for Tor transparent proxy"
    if [[ -z "$_PRIV_TOR_USER" ]]; then
        _priv_detect_tor_user || { _priv_error "Cannot determine Tor user."; return 1; }
    fi
    local tor_uid
    tor_uid=$(id -u "$_PRIV_TOR_USER" 2>/dev/null || true)
    if [[ -z "$tor_uid" ]]; then
        _priv_error "Cannot get UID for user '${_PRIV_TOR_USER}'."
        return 1
    fi

    sudo iptables -F
    sudo iptables -t nat -F
    sudo iptables -t nat -X 2>/dev/null || true

    sudo iptables -t nat -A OUTPUT -m owner --uid-owner "$tor_uid" -j RETURN
    local net
    for net in 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
        sudo iptables -t nat -A OUTPUT -d "$net" -j RETURN
    done
    sudo iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports "$_PRIV_TOR_DNS_PORT"
    sudo iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports "$_PRIV_TOR_DNS_PORT"
    sudo iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports "$_PRIV_TOR_TRANS_PORT"

    sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    sudo iptables -A OUTPUT -o lo -j ACCEPT
    sudo iptables -A OUTPUT -m owner --uid-owner "$tor_uid" -j ACCEPT
    for net in 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
        sudo iptables -A OUTPUT -d "$net" -j ACCEPT
    done
    sudo iptables -A OUTPUT -j REJECT

    sudo ip6tables -F
    sudo ip6tables -P INPUT DROP
    sudo ip6tables -P FORWARD DROP
    sudo ip6tables -P OUTPUT DROP
    sudo ip6tables -A OUTPUT -o lo -j ACCEPT
    sudo ip6tables -A INPUT  -i lo -j ACCEPT

    _priv_save_state "iptables_modified"
    _priv_info "iptables rules applied — all traffic routed through Tor."
    return 0
}

_priv_tor_verify() {
    _priv_header "Verifying Tor is working"
    local check_ip
    check_ip=$(curl -s --max-time 20 --socks5-hostname 127.0.0.1:9050 \
               https://check.torproject.org/api/ip 2>/dev/null || true)
    if [[ -n "$check_ip" ]]; then
        echo "  Tor Project: ${check_ip}"
        if echo "$check_ip" | grep -qi '"IsTor":true'; then
            _priv_info "CONFIRMED: Traffic is going through Tor!"
        else
            _priv_warn "Tor might not be fully working yet."
        fi
    else
        _priv_warn "Could not reach Tor check API (may still be bootstrapping)."
    fi
}

_priv_tor_start() {
    _priv_header "Starting Tor Transparent Proxy"
    if ! _priv_configure_tor; then
        _priv_error "Configuration failed."
        return 1
    fi

    sudo fuser -k "${_PRIV_TOR_DNS_PORT}/tcp"   2>/dev/null || true
    sudo fuser -k "${_PRIV_TOR_TRANS_PORT}/tcp" 2>/dev/null || true
    sleep 1

    sudo systemctl stop tor 2>/dev/null || true
    sleep 1
    sudo systemctl start tor 2>&1 || true
    sleep 2

    if ! systemctl is-active --quiet tor 2>/dev/null; then
        _priv_error "Tor failed to start!"
        journalctl -u tor --no-pager -n 25 2>/dev/null || true
        return 1
    fi

    sudo systemctl enable tor 2>/dev/null || true
    _priv_save_state "tor_running"
    _priv_info "Tor service is running!"

    local waited=0 max_wait=45 last_pct=""
    while [[ $waited -lt $max_wait ]]; do
        local bootstrap
        bootstrap=$(journalctl -u tor --no-pager -n 50 2>/dev/null | \
                    grep -o "Bootstrapped [0-9]*%" | tail -1 || true)
        if [[ -n "$bootstrap" && "$bootstrap" != "$last_pct" ]]; then
            echo "  ${CYAN}${bootstrap}${NC}"
            last_pct="$bootstrap"
            [[ "$bootstrap" == *"100%"* ]] && break
        fi
        sleep 2
        waited=$((waited + 2))
    done

    if ! _priv_tor_iptables_up; then
        _priv_error "iptables failed. Stopping Tor..."
        sudo systemctl stop tor 2>/dev/null || true
        return 1
    fi

    _priv_info "Tor transparent proxy is ACTIVE."
    sleep 2
    _priv_tor_verify
    _priv_show_current_ip
}

_priv_tor_stop() {
    _priv_header "Stopping Tor Transparent Proxy"
    _priv_iptables_full_reset
    sudo systemctl stop    tor 2>/dev/null || true
    sudo systemctl disable tor 2>/dev/null || true
    [[ -f "${_PRIV_BACKUP_DIR}/torrc.orig" ]] && sudo cp "${_PRIV_BACKUP_DIR}/torrc.orig" /etc/tor/torrc
    _priv_check_connectivity
    _priv_show_current_ip
}

_priv_tor_new_identity() {
    _priv_header "Requesting new Tor identity"
    if ! systemctl is-active --quiet tor 2>/dev/null; then
        _priv_error "Tor is not running. Start it first."
        return 1
    fi
    if printf 'AUTHENTICATE ""\r\nSIGNAL NEWNYM\r\nQUIT\r\n' | \
       nc -q 1 127.0.0.1 9051 2>/dev/null | grep -q "250"; then
        _priv_info "New identity signal sent."
    else
        sudo systemctl restart tor
        sleep 5
    fi
    sleep 5
    _priv_tor_verify
    _priv_show_current_ip
}

_priv_mac_randomize_persistent() {
    _priv_header "Enabling Persistent MAC Randomization"
    sudo mkdir -p /etc/NetworkManager/conf.d
    sudo tee /etc/NetworkManager/conf.d/90-mac-randomize.conf >/dev/null <<'EOF'
[device]
wifi.scan-rand-mac-address=yes

[connection]
ethernet.cloned-mac-address=random
wifi.cloned-mac-address=random
connection.stable-id=${CONNECTION}/${BOOT}
EOF
    _priv_save_state "mac_persistent"
    sudo systemctl restart NetworkManager
    sleep 3
    local iface
    iface=$(_priv_get_default_iface)
    [[ -n "$iface" ]] && _priv_info "New MAC: $(ip link show "${iface}" 2>/dev/null | awk '/ether/ {print $2}')"
}

_priv_mac_randomize_once() {
    _priv_header "One-time MAC Randomization"
    local iface conn
    iface=$(_priv_get_default_iface)
    conn=$(_priv_get_active_connection)
    if [[ -z "$iface" || -z "$conn" ]]; then
        _priv_error "Cannot detect active connection."
        return 1
    fi
    local new_mac
    new_mac=$(printf '02:%02x:%02x:%02x:%02x:%02x' \
        $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) \
        $((RANDOM%256)) $((RANDOM%256)))
    nmcli connection modify "$conn" ethernet.cloned-mac-address "$new_mac"
    nmcli connection down "$conn" 2>/dev/null || true
    sleep 1
    nmcli connection up "$conn" 2>/dev/null || true
    sleep 2
    _priv_save_state "mac_once"
    _priv_info "MAC changed to: ${new_mac}"
    _priv_show_current_ip
}

_priv_mac_restore() {
    _priv_header "Restoring Original MAC Address"
    sudo rm -f /etc/NetworkManager/conf.d/90-mac-randomize.conf
    local conn
    conn=$(_priv_get_active_connection)
    [[ -n "$conn" ]] && nmcli connection modify "$conn" ethernet.cloned-mac-address "" 2>/dev/null || true
    sudo systemctl restart NetworkManager
    sleep 3
    _priv_info "MAC address restored to hardware default."
}

_priv_ipv6_privacy() {
    _priv_header "Enabling IPv6 Privacy Extensions (RFC 4941)"
    _priv_backup_file /etc/sysctl.conf
    sudo tee /etc/sysctl.d/90-ipv6-privacy.conf >/dev/null <<'EOF'
net.ipv6.conf.all.use_tempaddr = 2
net.ipv6.conf.default.use_tempaddr = 2
net.ipv6.conf.all.temp_prefered_lft = 300
net.ipv6.conf.all.temp_valid_lft = 600
EOF
    sudo sysctl --system >/dev/null 2>&1
    local conn
    conn=$(_priv_get_active_connection)
    if [[ -n "$conn" ]]; then
        nmcli connection modify "$conn" ipv6.ip6-privacy 2 2>/dev/null || true
        nmcli connection modify "$conn" ipv6.addr-gen-mode stable-privacy 2>/dev/null || true
    fi
    _priv_save_state "ipv6_privacy"
    _priv_info "IPv6 privacy extensions are active."
}

_priv_dns_private() {
    _priv_header "Configuring Private DNS (NextDNS + DNS-over-TLS)"
    if [[ -f /etc/resolv.conf && ! -L /etc/resolv.conf ]]; then
        _priv_backup_file /etc/resolv.conf
    fi
    sudo mkdir -p /etc/systemd/resolved.conf.d
    sudo tee /etc/systemd/resolved.conf.d/90-dns-privacy.conf >/dev/null <<'EOF'
[Resolve]
DNSOverTLS=opportunistic
DNS=45.90.28.0#dns.nextdns.io 45.90.30.0#dns.nextdns.io
FallbackDNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
Domains=~.
MulticastDNS=no
LLMNS=no
Cache=yes
EOF
    sudo systemctl enable --now systemd-resolved 2>/dev/null || true
    sudo rm -f /etc/resolv.conf 2>/dev/null || true
    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    sudo mkdir -p /etc/NetworkManager/conf.d
    sudo tee /etc/NetworkManager/conf.d/90-dns-resolved.conf >/dev/null <<'EOF'
[main]
dns=systemd-resolved
EOF
    sudo systemctl restart systemd-resolved 2>/dev/null || true
    sudo systemctl restart NetworkManager 2>/dev/null || true
    sleep 3
    _priv_save_state "dns_private"
    _priv_info "DNS-over-TLS configured with NextDNS + Quad9."
}

_priv_dns_restore() {
    _priv_header "Restoring DNS to defaults"
    sudo rm -f /etc/systemd/resolved.conf.d/90-dns-privacy.conf
    sudo rm -f /etc/NetworkManager/conf.d/90-dns-resolved.conf
    sudo rm -f /etc/resolv.conf 2>/dev/null || true
    if [[ -f "${_PRIV_BACKUP_DIR}/resolv.conf.orig" ]]; then
        sudo cp "${_PRIV_BACKUP_DIR}/resolv.conf.orig" /etc/resolv.conf
    else
        sudo tee /etc/resolv.conf >/dev/null <<'EOF'
nameserver 45.90.28.0
nameserver 45.90.30.0
nameserver 9.9.9.9
EOF
    fi
    sudo systemctl restart systemd-resolved 2>/dev/null || true
    sudo systemctl restart NetworkManager 2>/dev/null || true
    sleep 3
    _priv_info "DNS restored."
}

_priv_wg_setup() {
    _priv_header "WireGuard VPN Setup"
    if ! command -v wg &>/dev/null; then
        sudo dnf install -y wireguard-tools 2>/dev/null || true
    fi
    local wg_dir="/etc/wireguard"
    sudo mkdir -p "$wg_dir"
    sudo chmod 700 "$wg_dir"
    echo -e "${CYAN}Do you have a WireGuard config file (.conf)?${NC}"
    echo "  1) Import existing .conf file"
    echo "  2) Generate new keypair (template only)"
    read -rp "Choice [1/2]: " wg_choice
    case "$wg_choice" in
        1)
            read -rp "Path to .conf file: " wg_conf_path
            if [[ ! -f "$wg_conf_path" ]]; then
                _priv_error "File not found: $wg_conf_path"
                return 1
            fi
            local wg_name
            wg_name=$(basename "$wg_conf_path" .conf)
            sudo cp "$wg_conf_path" "${wg_dir}/${wg_name}.conf"
            sudo chmod 600 "${wg_dir}/${wg_name}.conf"
            nmcli connection import type wireguard file "${wg_dir}/${wg_name}.conf" 2>/dev/null \
                && nmcli connection up "$wg_name" 2>/dev/null || \
                sudo systemctl enable --now "wg-quick@${wg_name}" 2>/dev/null || true
            sleep 3
            _priv_show_current_ip
            ;;
        2)
            local privkey pubkey
            privkey=$(wg genkey)
            pubkey=$(echo "$privkey" | wg pubkey)
            _priv_info "Generated keypair:"
            echo "  Private: ${privkey}"
            echo "  Public:  ${pubkey}"
            sudo tee "${wg_dir}/wg0.conf.template" >/dev/null <<TMPL
[Interface]
PrivateKey = ${privkey}
Address = 10.x.x.x/32
DNS = 45.90.28.0, 45.90.30.0

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = <SERVER_IP>:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
TMPL
            _priv_info "Template saved to ${wg_dir}/wg0.conf.template"
            ;;
        *) _priv_warn "Invalid choice." ;;
    esac
}

_priv_wg_down() {
    _priv_header "Disconnecting WireGuard"
    local iface
    for iface in $(wg show interfaces 2>/dev/null); do
        sudo wg-quick down "$iface" 2>/dev/null || \
            nmcli connection down "$iface" 2>/dev/null || true
        _priv_info "Brought down $iface"
    done
    _priv_show_current_ip
}

_priv_full_on() {
    _priv_header "FULL PRIVACY MODE — Activating all protections"
    _priv_ipv6_privacy;          echo ""
    _priv_dns_private;           echo ""
    _priv_mac_randomize_persistent; echo ""
    _priv_tor_start;             echo ""
    _priv_save_state "full_privacy"
    echo -e "${GREEN}+----------------------------------------------+"
    echo "|   FULL PRIVACY MODE IS NOW ACTIVE            |"
    echo "|   [+] MAC address randomized                |"
    echo "|   [+] IPv6 privacy extensions enabled       |"
    echo "|   [+] DNS-over-TLS (NextDNS) configured     |"
    echo "|   [+] All traffic routed through Tor        |"
    echo "|   Select option 13 in privacy menu to undo  |"
    echo "+----------------------------------------------+${NC}"
}

_priv_full_off() {
    _priv_header "RESTORING ALL SETTINGS TO DEFAULTS"
    read -rp "${YELLOW}Continue? [y/N]: ${NC}" confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { _priv_info "Cancelled."; return 0; }

    _priv_iptables_full_reset
    sudo systemctl stop    tor 2>/dev/null || true
    sudo systemctl disable tor 2>/dev/null || true
    _priv_dns_restore
    sudo rm -f /etc/NetworkManager/conf.d/90-mac-randomize.conf 2>/dev/null || true
    local conn
    conn=$(nmcli -t -f NAME connection show 2>/dev/null | head -1)
    [[ -n "$conn" ]] && nmcli connection modify "$conn" ethernet.cloned-mac-address "" 2>/dev/null || true
    sudo rm -f /etc/sysctl.d/90-ipv6-privacy.conf 2>/dev/null || true
    sudo sysctl --system >/dev/null 2>&1 || true
    sudo systemctl restart NetworkManager 2>/dev/null || true
    sleep 4
    _priv_clear_state
    _priv_check_connectivity
    _priv_show_current_ip
    echo -e "${GREEN}+----------------------------------------------+"
    echo "|   ALL SETTINGS RESTORED TO DEFAULTS          |"
    echo "+----------------------------------------------+${NC}"
}

_priv_leak_test() {
    _priv_header "Privacy Leak Test"
    local ext_ip
    ext_ip=$(curl -s --max-time 10 https://ifconfig.me 2>/dev/null || echo "unavailable")
    echo "  Public IP: ${ext_ip}"
    echo ""
    local tor_check
    tor_check=$(curl -s --max-time 15 https://check.torproject.org/api/ip 2>/dev/null || echo "unavailable")
    echo "  Tor API: ${tor_check}"
    echo ""
    echo -e "  ${CYAN}Browser leak tests:${NC}"
    echo "  DNS leaks:  https://dnsleaktest.com"
    echo "  WebRTC:     https://browserleaks.com/webrtc"
    echo "  Full check: https://ipleak.net"
    echo ""
}

_priv_diagnose() {
    _priv_header "System Diagnostics"
    echo "  Tor installed:   $(command -v tor &>/dev/null && echo 'yes' || echo 'no')"
    echo "  Tor service:     $(systemctl is-active tor 2>/dev/null || echo 'inactive')"
    local iface
    iface=$(_priv_get_default_iface)
    echo "  NM state:    $(nmcli -t -f STATE general 2>/dev/null || echo 'unknown')"
    echo "  Interface:   ${iface:-none}"
    echo ""
    echo "  /etc/resolv.conf:"
    [[ -L /etc/resolv.conf ]] && echo "    (symlink -> $(readlink /etc/resolv.conf))"
    grep -v "^#\|^$" /etc/resolv.conf 2>/dev/null | sed 's/^/    /' || echo "    (missing)"
    echo ""
    echo "  iptables OUTPUT: $(sudo iptables -L OUTPUT 2>/dev/null | head -1 | grep -o 'policy [A-Z]*')"
    echo ""
}

#=============================================================================
# YGGDRASIL MESH VPN
#=============================================================================

_ygg_ok()  { echo -e "${GREEN}[ OK ]${NC}  $*"; }
_ygg_info(){ echo -e "${CYAN}[INFO]${NC}  $*"; }
_ygg_warn(){ echo -e "${YELLOW}[WARN]${NC}  $*"; }
_ygg_sep() { echo -e "────────────────────────────────────────────────────${NC}"; }

install_yggdrasil() {
    print_header "Yggdrasil — Encrypted Mesh Network (Fedora)"

    echo -e "  ${CYAN}Reference: https://yggdrasil-network.github.io/configuration.html${NC}"
    echo ""
    echo -e "  Select mode:${NC}"
    echo -e "    ${WHITE}1)${NC} Install & configure Yggdrasil"
    echo -e "    ${WHITE}2)${NC} Uninstall Yggdrasil"
    echo -e "    ${WHITE}3)${NC} Show status / node info"
    echo -e "    ${WHITE}0)${NC} Cancel"
    echo ""
    read -rp "  Choice [1]: " _ygg_mode; _ygg_mode="${_ygg_mode:-1}"

    case "$_ygg_mode" in
        0) print_warning "Cancelled."; return ;;
        3)
            systemctl status yggdrasil --no-pager -l 2>&1 | head -20
            ip -6 addr show tun0 2>/dev/null | grep inet6 | awk '{print "  "$2}' \
                || echo "  (not yet — service may still be starting)"
            sudo yggdrasilctl getSelf 2>/dev/null | python3 -m json.tool 2>/dev/null \
                || echo "  (admin socket not ready)"
            return
            ;;
        2)
            sudo systemctl stop    yggdrasil 2>/dev/null || true
            sudo systemctl disable yggdrasil 2>/dev/null || true
            sudo dnf remove -y yggdrasil    2>/dev/null || true
            sudo rm -f /etc/yggdrasil.conf
            print_success "Yggdrasil removed."
            return
            ;;
        1) ;;
        *) print_error "Invalid choice."; return ;;
    esac

    run_with_spinner "Updating system packages..." sudo dnf update -y -q
    _ygg_ok "System up to date."

    run_with_spinner "Enabling COPR repository..." sudo dnf copr enable -y neilalexander/yggdrasil-go
    run_with_spinner "Installing Yggdrasil..." sudo dnf install -y yggdrasil
    local _ygg_ver
    _ygg_ver=$(yggdrasil -version 2>/dev/null | awk '{print $NF}' || echo "unknown")
    _ygg_ok "Installed — version: ${_ygg_ver}"

    local _ygg_conf="/etc/yggdrasil.conf"
    if [[ -f "$_ygg_conf" ]]; then
        local _ygg_bak
        _ygg_bak="${_ygg_conf}.bak.$(date +%Y%m%d_%H%M%S)"
        _ygg_warn "Existing config found — backing up to ${_ygg_bak}"
        sudo cp "$_ygg_conf" "$_ygg_bak"
    fi
    sudo yggdrasil -genconf | sudo tee "$_ygg_conf" >/dev/null
    sudo chmod 600 "$_ygg_conf"
    _ygg_ok "Config written to ${_ygg_conf}"

    local _ygg_peers_tmp
    _ygg_peers_tmp=$(mktemp)
    cat > "$_ygg_peers_tmp" <<'PEERS_EOF'
[
  tls://vpn.ltha.de:443
  tls://ygg.mkg20001.io:443
  tls://de1.servers.devices.cwinfo.net:28395
  tls://fr2.servers.devices.cwinfo.net:54232
  tcp://88.99.175.190:14088
  tls://ygg.mnlabs.net:6010
  tcp://51.15.204.214:12345
  tls://sg.peering.ygg.prmprnd.dev:60004
]
PEERS_EOF

    local _ygg_patched_tmp _ygg_py_tmp
    _ygg_patched_tmp=$(mktemp)
    _ygg_py_tmp=$(mktemp --suffix=.py)
    cat > "$_ygg_py_tmp" <<'PYEOF'
import sys, re, pathlib
conf_file, peers_file, out_file = sys.argv[1], sys.argv[2], sys.argv[3]
content = pathlib.Path(conf_file).read_text()
with open(peers_file) as pf:
    block = pf.read().strip()
patched = re.sub(r'Peers:\s*\[.*?\]', 'Peers: ' + block, content, flags=re.DOTALL)
pathlib.Path(out_file).write_text(patched)
print("  Peers injected.")
PYEOF
    python3 "$_ygg_py_tmp" "$_ygg_conf" "$_ygg_peers_tmp" "$_ygg_patched_tmp"
    sudo cp "$_ygg_patched_tmp" "$_ygg_conf"
    sudo chmod 600 "$_ygg_conf"
    rm -f "$_ygg_peers_tmp" "$_ygg_patched_tmp" "$_ygg_py_tmp"
    _ygg_ok "Peers configured. Find peers near you: https://publicpeers.neilalexander.dev/"

    if systemctl is-active --quiet firewalld; then
        sudo firewall-cmd --permanent --add-port="9001/tcp" -q
        sudo firewall-cmd --permanent --add-port="9001/udp" -q
        sudo firewall-cmd --permanent --zone=trusted --add-interface=tun0 -q 2>/dev/null || true
        sudo firewall-cmd --reload -q
        _ygg_ok "Firewall: port 9001 TCP/UDP opened; tun0 trusted."
    fi

    sudo systemctl daemon-reload
    sudo systemctl enable yggdrasil
    sudo systemctl restart yggdrasil
    sleep 3
    if systemctl is-active --quiet yggdrasil; then
        _ygg_ok "yggdrasil.service is running."
    else
        _ygg_warn "Service not running. Check: sudo journalctl -u yggdrasil -n 60"
    fi

    _ygg_sep
    local _ygg_addr
    _ygg_addr=$(ip -6 addr show tun0 2>/dev/null | grep inet6 | awk '{print $2}' | head -1 || true)
    if [[ -n "$_ygg_addr" ]]; then
        echo -e "  Your Yggdrasil IPv6 address: ${CYAN}${_ygg_addr}${NC}"
    else
        echo -e "  ${YELLOW}IPv6 address will appear shortly — run: sudo yggdrasilctl getSelf${NC}"
    fi
    echo -e "  ${YELLOW}Backup /etc/yggdrasil.conf — it contains your private key!${NC}"
    _ygg_sep
}

#=============================================================================
# PRIVACY & NETWORK — SUB-MENU
#=============================================================================

privacy_network_menu() {
    print_header "Privacy & Network Tools"

    for _cmd in curl nmcli ip iptables ss host; do
        if ! command -v "$_cmd" &>/dev/null; then
            case "$_cmd" in
                curl)     sudo dnf install -y curl        2>/dev/null || true ;;
                nmcli)    sudo dnf install -y NetworkManager 2>/dev/null || true ;;
                ip|ss)    sudo dnf install -y iproute     2>/dev/null || true ;;
                iptables) sudo dnf install -y iptables    2>/dev/null || true ;;
                host)     sudo dnf install -y bind-utils  2>/dev/null || true ;;
            esac
        fi
    done

    while true; do
        clear

        local _tor_status="${RED}OFF${NC}"
        systemctl is-active --quiet tor 2>/dev/null && _tor_status="${GREEN}ACTIVE${NC}"
        local _ygg_status="${RED}OFF${NC}"
        systemctl is-active --quiet yggdrasil 2>/dev/null && _ygg_status="${GREEN}ACTIVE${NC}"
        local _iface
        _iface=$(_priv_get_default_iface)
        local _cur_mac
        _cur_mac=$(ip link show "${_iface}" 2>/dev/null | awk '/ether/ {print $2}')
        local _cur_ip
        _cur_ip=$(ip -4 addr show "${_iface}" 2>/dev/null | awk '/inet / {print $2}')
        local _nm_state
        _nm_state=$(nmcli -t -f STATE general 2>/dev/null || echo "unknown")

        cat << 'BANNER'

      Privacy & Network Tools
BANNER
        echo -e "${NC}"
        echo -e "  Status:${NC}  Tor [${_tor_status}]  Yggdrasil [${_ygg_status}]  Net [${_nm_state}]"
        echo -e "  Iface:${NC}   ${_iface:-?}   MAC:${NC} ${_cur_mac:-?}   IP:${NC} ${_cur_ip:-?}"
        echo ""
        echo -e "  ─── Tor Proxy ────────────────────────────────────${NC}"
        echo -e "  ${GREEN} 1)${NC}  Start Tor transparent proxy"
        echo -e "  ${GREEN} 2)${NC}  Get new Tor identity"
        echo -e "  ${GREEN} 3)${NC}  Stop Tor transparent proxy"
        echo ""
        echo -e "  ─── MAC Address ──────────────────────────────────${NC}"
        echo -e "  ${GREEN} 4)${NC}  Randomize MAC address (once)"
        echo -e "  ${GREEN} 5)${NC}  Persistent MAC randomization (every boot)"
        echo -e "  ${GREEN} 6)${NC}  Restore original MAC"
        echo ""
        echo -e "  ─── Privacy Hardening ────────────────────────────${NC}"
        echo -e "  ${GREEN} 7)${NC}  Enable IPv6 privacy extensions (RFC 4941)"
        echo -e "  ${GREEN} 8)${NC}  Configure DNS-over-TLS (NextDNS + Quad9)"
        echo ""
        echo -e "  ─── VPN ──────────────────────────────────────────${NC}"
        echo -e "  ${GREEN} 9)${NC}  Setup WireGuard VPN"
        echo -e "  ${GREEN}10)${NC}  Disconnect WireGuard VPN"
        echo ""
        echo -e "  ─── Yggdrasil Mesh VPN ───────────────────────────${NC}"
        echo -e "  ${GREEN}11)${NC}  Install / Configure Yggdrasil"
        echo ""
        echo -e "  ─── All-in-One ───────────────────────────────────${NC}"
        echo -e "  ${GREEN}12)${NC}  FULL PRIVACY MODE  (Tor + MAC + DoT + IPv6)"
        echo -e "  ${GREEN}13)${NC}  RESTORE EVERYTHING to defaults"
        echo ""
        echo -e "  ─── Info & Troubleshoot ──────────────────────────${NC}"
        echo -e "  ${GREEN}14)${NC}  Run privacy leak test"
        echo -e "  ${GREEN}15)${NC}  Show current IP info"
        echo -e "  ${GREEN}16)${NC}  Diagnose / troubleshoot"
        echo -e "  ${GREEN}17)${NC}  Emergency network repair"
        echo ""
        echo -e "  ${RED} 0)${NC}  Return to main menu"
        echo ""

        read -rp "  Enter choice [0-17]: " _pn_choice
        echo ""

        case "$_pn_choice" in
            1)  _priv_tor_start ;;
            2)  _priv_tor_new_identity ;;
            3)  _priv_tor_stop ;;
            4)  _priv_mac_randomize_once ;;
            5)  _priv_mac_randomize_persistent ;;
            6)  _priv_mac_restore ;;
            7)  _priv_ipv6_privacy ;;
            8)  _priv_dns_private ;;
            9)  _priv_wg_setup ;;
            10) _priv_wg_down ;;
            11) install_yggdrasil ;;
            12) _priv_full_on ;;
            13) _priv_full_off ;;
            14) _priv_leak_test ;;
            15) _priv_show_current_ip ;;
            16) _priv_diagnose ;;
            17) _priv_emergency_repair ;;
            0)
                print_success "Returning to main menu."
                return
                ;;
            *)
                print_warning "Invalid choice: ${_pn_choice}"
                ;;
        esac

        echo ""
        read -rp "Press Enter to continue..." _dummy
    done
}

#===========================================
# AUTO MOUNT — ALL DRIVES
#===========================================

_mnt_ok()   { echo -e "${GREEN}  ✓${NC}  $*"; }
_mnt_warn() { echo -e "${YELLOW}  !${NC}  $*"; }
_mnt_err()  { echo -e "${RED}  ✗${NC}  $*"; }
_mnt_info() { echo -e "${CYAN}  ›${NC}  $*"; }
_mnt_sep()  { echo -e "  ──────────────────────────────────────────────${NC}"; }

_mnt_fstype_label() {
    case "$1" in
        ext4)    echo "ext4 (Linux)" ;;
        ext3)    echo "ext3 (Linux legacy)" ;;
        ext2)    echo "ext2 (Linux legacy)" ;;
        xfs)     echo "XFS (Linux)" ;;
        btrfs)   echo "Btrfs (Linux)" ;;
        ntfs|ntfs-3g) echo "NTFS (Windows)" ;;
        vfat|fat32|fat16) echo "FAT32/FAT16 (Universal)" ;;
        exfat)   echo "exFAT (Universal)" ;;
        f2fs)    echo "F2FS (Mobile/Flash)" ;;
        iso9660|udf) echo "ISO/UDF (Optical)" ;;
        swap)    echo "Swap (skip)" ;;
        LVM2_member) echo "LVM (skip)" ;;
        *)       echo "$1 (unknown)" ;;
    esac
}

_mnt_ensure_drivers() {
    local need_ntfs=false need_exfat=false need_btrfs=false
    while IFS= read -r fstype; do
        case "$fstype" in
            ntfs*) need_ntfs=true ;;
            exfat) need_exfat=true ;;
            btrfs) need_btrfs=true ;;
        esac
    done < <(lsblk -rno FSTYPE 2>/dev/null | grep -v '^$')

    local pkgs=()
    $need_ntfs  && ! command -v ntfs-3g &>/dev/null    && pkgs+=(ntfs-3g)
    $need_exfat && ! command -v mount.exfat &>/dev/null && pkgs+=(exfatprogs fuse-exfat)
    $need_btrfs && ! command -v btrfs &>/dev/null       && pkgs+=(btrfs-progs)
    command -v udisksctl &>/dev/null || pkgs+=(udisks2)
    rpm -q gvfs &>/dev/null          || pkgs+=(gvfs gvfs-smb gvfs-mtp gvfs-gphoto2)

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        _mnt_info "Installing missing filesystem packages: ${pkgs[*]}"
        sudo dnf install -y "${pkgs[@]}" 2>&1 | tee -a "$LOG_FILE" > /dev/null \
            && _mnt_ok "Filesystem packages installed." \
            || _mnt_warn "Some packages failed — continuing anyway."
    else
        _mnt_ok "All required filesystem drivers are present."
    fi
}

_mnt_scan_devices() {
    lsblk -rno NAME,FSTYPE,SIZE,LABEL,UUID,MOUNTPOINT 2>/dev/null \
        | awk '$2 != "" && $2 != "swap" && $2 != "LVM2_member" && $2 != "linux_raid_member" {
            dev="/dev/"$1; print dev"|"$2"|"$3"|"$4"|"$5"|"$6
        }'
}

_mnt_show_drive_table() {
    echo ""
    echo -e "  ${CYAN}Detected Block Devices:${NC}"
    _mnt_sep
    printf "  %-12s %-22s %-8s %-20s %-s\n" "DEVICE" "FILESYSTEM" "SIZE" "LABEL/UUID" "MOUNTPOINT"
    _mnt_sep
    local dev fstype sz label uuid mnt display_label
    while IFS='|' read -r dev fstype sz label uuid mnt; do
        display_label="${label:-${uuid:0:8}}"
        [[ -z "$display_label" ]] && display_label="(none)"
        local mnt_display="${mnt:-(not mounted)}"
        local fs_label
        fs_label=$(_mnt_fstype_label "$fstype")
        printf "  %-12s %-22s %-8s %-20s %-s\n" "$dev" "$fs_label" "$sz" "$display_label" "$mnt_display"
    done < <(_mnt_scan_devices)
    _mnt_sep
    echo ""
}

_mnt_make_mountpoint() {
    local dev="$1" label="$2" uuid="$3"
    local base
    if [[ -n "$label" ]]; then
        base=$(echo "$label" | tr ' ' '_' | tr -cd '[:alnum:]_-' | head -c 32)
    elif [[ -n "$uuid" ]]; then
        base="disk_${uuid:0:8}"
    else
        base="disk_$(basename "$dev")"
    fi
    echo "/mnt/${base}"
}

_mnt_mount_device() {
    local dev="$1" fstype="$2" label="$3" uuid="$4"
    local mountpoint
    mountpoint=$(_mnt_make_mountpoint "$dev" "$label" "$uuid")
    local existing_mnt
    existing_mnt=$(lsblk -rno MOUNTPOINT "$dev" 2>/dev/null | grep -v '^$' | head -1)
    if [[ -n "$existing_mnt" ]]; then
        _mnt_warn "$(basename "$dev") already mounted at ${existing_mnt} — skipping."
        return 0
    fi
    sudo mkdir -p "$mountpoint"
    local opts="defaults"
    case "$fstype" in
        ntfs|ntfs-3g)
            opts="defaults,uid=$(id -u),gid=$(id -g),umask=022,windows_names"
            fstype="ntfs-3g"
            ;;
        vfat|fat32|fat16)
            opts="defaults,uid=$(id -u),gid=$(id -g),umask=022,codepage=437,iocharset=utf8"
            ;;
        exfat)
            opts="defaults,uid=$(id -u),gid=$(id -g),umask=022"
            ;;
        ext4|ext3|ext2|xfs|btrfs|f2fs)
            opts="defaults,noatime"
            ;;
    esac
    if sudo mount -t "$fstype" -o "$opts" "$dev" "$mountpoint" 2>>"$LOG_FILE"; then
        _mnt_ok "Mounted ${dev} → ${mountpoint}"
        return 0
    else
        if sudo mount -o "defaults" "$dev" "$mountpoint" 2>>"$LOG_FILE"; then
            _mnt_ok "Mounted ${dev} → ${mountpoint} (auto-detected type)"
            return 0
        else
            _mnt_err "Failed to mount ${dev} — see $LOG_FILE"
            sudo rmdir "$mountpoint" 2>/dev/null || true
            return 1
        fi
    fi
}

_mnt_write_fstab() {
    local dev="$1" fstype="$2" label="$3" uuid="$4"
    if [[ -z "$uuid" ]]; then
        _mnt_warn "$(basename "$dev") has no UUID — cannot write reliable fstab entry."
        return 0
    fi
    local mountpoint
    mountpoint=$(_mnt_make_mountpoint "$dev" "$label" "$uuid")
    if grep -q "UUID=${uuid}" /etc/fstab 2>/dev/null; then
        _mnt_warn "fstab entry for UUID=${uuid:0:8}… already exists — skipping."
        return 0
    fi
    sudo mkdir -p "$mountpoint"
    local opts dump pass
    case "$fstype" in
        ntfs|ntfs-3g)
            opts="uid=$(id -u),gid=$(id -g),umask=022,windows_names,nofail,x-systemd.device-timeout=10s"
            dump=0; pass=0; fstype="ntfs-3g"
            ;;
        vfat|fat32|fat16)
            opts="uid=$(id -u),gid=$(id -g),umask=022,codepage=437,iocharset=utf8,nofail,x-systemd.device-timeout=10s"
            dump=0; pass=0
            ;;
        exfat)
            opts="uid=$(id -u),gid=$(id -g),umask=022,nofail,x-systemd.device-timeout=10s"
            dump=0; pass=0
            ;;
        ext4) opts="defaults,noatime,nofail,x-systemd.device-timeout=10s"; dump=0; pass=2 ;;
        xfs)  opts="defaults,noatime,nofail,x-systemd.device-timeout=10s"; dump=0; pass=2 ;;
        btrfs) opts="defaults,noatime,compress=zstd,nofail,x-systemd.device-timeout=10s"; dump=0; pass=0 ;;
        *) opts="defaults,nofail,x-systemd.device-timeout=10s"; dump=0; pass=0 ;;
    esac
    {
        echo ""
        echo "# Added by setup.sh auto-mount — $(date '+%Y-%m-%d %H:%M')"
        echo "# Device: ${dev}  Label: ${label:-(no label)}"
        printf 'UUID=%-38s %-30s %-10s %-50s %s %s\n' \
               "$uuid" "$mountpoint" "$fstype" "$opts" "$dump" "$pass"
    } | sudo tee -a /etc/fstab >/dev/null
    _mnt_ok "fstab entry added for ${dev} (UUID ${uuid:0:8}…) → ${mountpoint}"
}

_mnt_setup_udev() {
    sudo tee /etc/udev/rules.d/99-automount.rules >/dev/null <<'UDEV'
ACTION=="add", SUBSYSTEMS=="usb", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", \
    RUN+="/usr/bin/systemd-mount --no-block --collect --automount=yes %N"
UDEV
    sudo udevadm control --reload-rules 2>/dev/null && _mnt_ok "udev rules reloaded." \
        || _mnt_warn "udev reload failed — rules will apply after reboot."
}

_mnt_setup_polkit() {
    sudo mkdir -p /etc/polkit-1/rules.d
    sudo tee /etc/polkit-1/rules.d/99-udisks2-mount.rules >/dev/null <<'POLKIT'
polkit.addRule(function(action, subject) {
    var udisksActions = [
        "org.freedesktop.udisks2.filesystem-mount",
        "org.freedesktop.udisks2.filesystem-unmount-others",
        "org.freedesktop.udisks2.eject-media",
        "org.freedesktop.udisks2.power-off-drive",
        "org.freedesktop.udisks2.filesystem-mount-other-seat"
    ];
    if (udisksActions.indexOf(action.id) >= 0 && subject.local && subject.active) {
        return polkit.Result.YES;
    }
});
POLKIT
    _mnt_ok "polkit rule written — KDE users can now mount drives without sudo."
}

automount_drives() {
    print_header "Auto Mount — All Drives (Internal & External)"

    echo -e "  ${CYAN}This tool will:${NC}"
    echo -e "    ${WHITE}•${NC} Detect all unmounted partitions (internal & external)"
    echo -e "    ${WHITE}•${NC} Install missing filesystem drivers (NTFS, exFAT, Btrfs…)"
    echo -e "    ${WHITE}•${NC} Mount all detected drives to /mnt/<label>"
    echo -e "    ${WHITE}•${NC} Optionally write persistent /etc/fstab entries"
    echo -e "    ${WHITE}•${NC} Set up udev rules for plug-and-play USB auto-mounting"
    echo -e "    ${WHITE}•${NC} Configure polkit so KDE Dolphin can mount drives without sudo"
    echo ""
    echo -e "  ${YELLOW}⚠  A backup of /etc/fstab will be made before any changes.${NC}"
    echo ""
    echo -e "  What would you like to do?${NC}"
    echo -e "    ${WHITE}1)${NC} Mount all unmounted drives NOW (session only, no fstab)"
    echo -e "    ${WHITE}2)${NC} Mount + make PERSISTENT (writes /etc/fstab entries)"
    echo -e "    ${WHITE}3)${NC} Setup USB plug-and-play only (udev + polkit + udisks2)"
    echo -e "    ${WHITE}4)${NC} Show drive table only"
    echo -e "    ${WHITE}5)${NC} Unmount a specific drive"
    echo -e "    ${WHITE}0)${NC} Cancel"
    echo ""
    read -rp "  Choice [1]: " _mnt_choice; _mnt_choice="${_mnt_choice:-1}"

    case "$_mnt_choice" in
        0) print_warning "Cancelled."; return ;;
        4) _mnt_show_drive_table; return ;;
        5)
            _mnt_show_drive_table
            read -rp "  Enter device to unmount (e.g. /dev/sdb1): " _umnt_dev
            if [[ -z "$_umnt_dev" ]]; then
                print_warning "No device specified."
                return
            fi
            if sudo umount "$_umnt_dev" 2>/dev/null; then
                _mnt_ok "Unmounted ${_umnt_dev}"
            else
                _mnt_err "Could not unmount ${_umnt_dev}"
            fi
            return
            ;;
    esac

    local do_fstab=false do_udev=false
    case "$_mnt_choice" in
        1) do_fstab=false; do_udev=false ;;
        2) do_fstab=true;  do_udev=true  ;;
        3) do_fstab=false; do_udev=true  ;;
    esac

    print_section "Step 1/4 — Installing filesystem drivers..."
    _mnt_ensure_drivers

    print_section "Step 2/4 — Scanning block devices..."
    _mnt_show_drive_table

    if $do_fstab; then
        local fstab_bak
        fstab_bak="/etc/fstab.bak.$(date +%Y%m%d_%H%M%S)"
        sudo cp /etc/fstab "$fstab_bak"
        _mnt_ok "fstab backed up to ${fstab_bak}"
    fi

    print_section "Step 3/4 — Mounting drives..."
    local mounted=0 skipped=0 failed=0
    local dev fstype sz label uuid mnt

    while IFS='|' read -r dev fstype sz label uuid mnt; do
        if [[ -n "$mnt" ]]; then
            skipped=$((skipped + 1))
            continue
        fi
        if [[ "$dev" == /dev/loop* || "$dev" == /dev/sr* || "$dev" == /dev/zram* ]]; then
            skipped=$((skipped + 1))
            continue
        fi
        echo ""
        _mnt_info "Processing: ${dev} [${fstype}] ${sz} label='${label}'"
        if _mnt_mount_device "$dev" "$fstype" "$label" "$uuid"; then
            mounted=$((mounted + 1))
            if $do_fstab; then
                _mnt_write_fstab "$dev" "$fstype" "$label" "$uuid"
            fi
        else
            failed=$((failed + 1))
        fi
    done < <(_mnt_scan_devices)

    print_section "Step 4/4 — USB plug-and-play setup..."
    if $do_udev; then
        _mnt_setup_polkit
        _mnt_setup_udev
        sudo systemctl enable --now udisks2 2>/dev/null \
            && _mnt_ok "udisks2 is running." \
            || _mnt_warn "udisks2 enable failed (may already be active)."
    fi

    echo ""
    _mnt_sep
    echo -e "  Mount Summary:${NC}"
    echo -e "    ${GREEN}Mounted:${NC}  ${mounted}"
    echo -e "    ${YELLOW}Skipped:${NC}  ${skipped}"
    echo -e "    ${RED}Failed:${NC}   ${failed}"
    _mnt_sep
    echo ""
    log "Auto-mount complete: mounted=$mounted skipped=$skipped failed=$failed fstab=$do_fstab"
}

#===========================================
# NOOBS GUIDE
#===========================================

_nb_tip()     { echo -e "  ${YELLOW}💡 Tip:${NC} $*"; }
_nb_step()    { echo -e "  ${GREEN}▶  Step $1:${NC} $2"; }
_nb_explain() { echo -e "  ${CYAN}ℹ  ${NC}$*"; }
_nb_warn()    { echo -e "  ${RED}⚠  ${NC}$*"; }

_nb_pause() {
    echo ""
    echo -e "  Press Enter to continue, or type 'q' to return to menu...${NC}"
    read -r _nb_input
    [[ "$_nb_input" == "q" ]] && return 1
    return 0
}

_nb_guide_welcome() {
    echo ""
    echo -e "  ${WHITE}Welcome to Fedora Linux!${NC}"
    echo ""
    echo -e "  What is Fedora?${NC}"
    _nb_explain "Fedora is a free, open-source Linux distribution sponsored by Red Hat."
    _nb_explain "KDE Plasma is the desktop environment — familiar but far more powerful."
    echo ""
    echo -e "  Golden rules for new Linux users:${NC}"
    echo -e "    ${GREEN}1)${NC} Never run this script as root (it handles sudo itself)"
    echo -e "    ${GREEN}2)${NC} Read what a command does before running it"
    echo -e "    ${GREEN}3)${NC} The terminal is your best friend — don't be scared of it"
    echo -e "    ${GREEN}4)${NC} Back up your /home folder regularly"
    echo ""
    _nb_tip "The Fedora forums (discussion.fedoraproject.org) are extremely friendly to beginners!"
    _nb_pause || return
}

_nb_guide_terminal() {
    echo ""
    echo -e "  ${WHITE}Using the Terminal 💻${NC}"
    echo ""
    echo -e "  Essential terminal commands:${NC}"
    printf "  ${GREEN}%-35s${NC} %s\n" "ls -la"                "List files (detailed, including hidden)"
    printf "  ${GREEN}%-35s${NC} %s\n" "cd /path/to/folder"    "Change directory"
    printf "  ${GREEN}%-35s${NC} %s\n" "pwd"                   "Show current directory path"
    printf "  ${GREEN}%-35s${NC} %s\n" "mkdir myfolder"        "Create a new folder"
    printf "  ${GREEN}%-35s${NC} %s\n" "cp file1 file2"        "Copy a file"
    printf "  ${GREEN}%-35s${NC} %s\n" "mv file1 file2"        "Move/rename a file"
    printf "  ${GREEN}%-35s${NC} %s\n" "rm file"               "Delete a file"
    printf "  ${GREEN}%-35s${NC} %s\n" "cat file.txt"          "Show file contents"
    printf "  ${GREEN}%-35s${NC} %s\n" "nano file.txt"         "Edit a file (easy text editor)"
    printf "  ${GREEN}%-35s${NC} %s\n" "man ls"                "Show manual for any command"
    printf "  ${GREEN}%-35s${NC} %s\n" "Ctrl + C"              "Cancel/stop a running command"
    printf "  ${GREEN}%-35s${NC} %s\n" "Tab"                   "Auto-complete filenames/commands"
    echo ""
    _nb_tip "Copy-paste in Konsole with Ctrl+Shift+C and Ctrl+Shift+V"
    _nb_pause || return
}

_nb_guide_packages() {
    echo ""
    echo -e "  ${WHITE}Installing Software on Fedora 📦${NC}"
    echo ""
    echo -e "  ${GREEN}1) DNF — The main package manager${NC}"
    printf "  ${CYAN}%-45s${NC} %s\n" "sudo dnf install firefox"    "Install Firefox"
    printf "  ${CYAN}%-45s${NC} %s\n" "sudo dnf remove firefox"     "Uninstall Firefox"
    printf "  ${CYAN}%-45s${NC} %s\n" "sudo dnf update"             "Update ALL software"
    printf "  ${CYAN}%-45s${NC} %s\n" "sudo dnf search vlc"         "Search for VLC"
    echo ""
    echo -e "  ${GREEN}2) Flatpak — Universal app packages (sandboxed)${NC}"
    printf "  ${CYAN}%-45s${NC} %s\n" "flatpak install flathub com.discordapp.Discord" "Install Discord"
    printf "  ${CYAN}%-45s${NC} %s\n" "flatpak update"              "Update all Flatpaks"
    echo ""
    echo -e "  ${GREEN}3) RPM files — Like .exe files on Windows${NC}"
    printf "  ${CYAN}%-45s${NC}\n" "sudo dnf install ./google-chrome.rpm"
    echo ""
    _nb_tip "Always prefer DNF over downloading random files from the internet!"
    _nb_pause || return
}

_nb_guide_sudo() {
    echo ""
    echo -e "  ${WHITE}Understanding sudo & Permissions 🔐${NC}"
    echo ""
    echo -e "  What is sudo?${NC}"
    _nb_explain "'sudo' temporarily grants admin power — like 'Run as Administrator' on Windows."
    _nb_explain "You'll be asked for YOUR password (not a root password)."
    echo ""
    _nb_warn "Never paste sudo commands from the internet without reading them first."
    echo ""
    printf "  ${CYAN}%-30s${NC} %s\n" "chmod +x script.sh"   "Make a file executable"
    printf "  ${CYAN}%-30s${NC} %s\n" "chmod 644 file.txt"   "Owner: rw, Group: r, Others: r"
    printf "  ${CYAN}%-30s${NC} %s\n" "chown alice file.txt" "Change file owner to alice"
    echo ""
    _nb_pause || return
}

_nb_guide_updates() {
    echo ""
    echo -e "  ${WHITE}Keeping Your System Updated 🔄${NC}"
    echo ""
    printf "  ${GREEN}%-40s${NC} %s\n" "sudo dnf update"          "Update everything"
    printf "  ${GREEN}%-40s${NC} %s\n" "flatpak update"           "Update Flatpak apps separately"
    printf "  ${GREEN}%-40s${NC} %s\n" "sudo dnf autoremove"      "Remove unused dependencies"
    echo ""
    _nb_tip "Reboot after a kernel update to start using the new kernel."
    _nb_pause || return
}

_nb_guide_kde() {
    echo ""
    echo -e "  ${WHITE}Getting Around KDE Plasma 🖥️${NC}"
    echo ""
    printf "  ${GREEN}%-30s${NC} %s\n" "Super key (Windows key)"      "Open application launcher"
    printf "  ${GREEN}%-30s${NC} %s\n" "Alt + F4"                     "Close window"
    printf "  ${GREEN}%-30s${NC} %s\n" "Super + D"                    "Show desktop"
    printf "  ${GREEN}%-30s${NC} %s\n" "Super + L"                    "Lock screen"
    printf "  ${GREEN}%-30s${NC} %s\n" "Print Screen"                 "Take a screenshot"
    printf "  ${GREEN}%-30s${NC} %s\n" "Dolphin"                      "File manager (like Explorer)"
    printf "  ${GREEN}%-30s${NC} %s\n" "Konsole"                      "Terminal emulator"
    printf "  ${GREEN}%-30s${NC} %s\n" "Discover"                     "Graphical app store"
    echo ""
    _nb_pause || return
}

_nb_guide_files() {
    echo ""
    echo -e "  ${WHITE}File System Layout 📂${NC}"
    echo ""
    printf "  ${CYAN}%-20s${NC} %s\n" "/"             "Root — the top of everything (like C:\\ on Windows)"
    printf "  ${CYAN}%-20s${NC} %s\n" "/home/YOU"     "YOUR personal folder — where all your stuff lives"
    printf "  ${CYAN}%-20s${NC} %s\n" "/etc"          "System configuration files (be careful here)"
    printf "  ${CYAN}%-20s${NC} %s\n" "/var/log"      "System logs — check here when things break"
    printf "  ${CYAN}%-20s${NC} %s\n" "/mnt"          "Where extra drives are mounted"
    printf "  ${CYAN}%-20s${NC} %s\n" "/tmp"          "Temporary files — wiped on reboot"
    echo ""
    _nb_tip "Back up your /home folder — everything else can be reinstalled from scratch"
    _nb_pause || return
}

_nb_guide_networking() {
    echo ""
    echo -e "  ${WHITE}Networking on Fedora 🌐${NC}"
    echo ""
    printf "  ${GREEN}%-35s${NC} %s\n" "ip addr"                  "Show all IP addresses"
    printf "  ${GREEN}%-35s${NC} %s\n" "nmcli general status"     "Show NetworkManager status"
    printf "  ${GREEN}%-35s${NC} %s\n" "ping 8.8.8.8"            "Test internet"
    printf "  ${GREEN}%-35s${NC} %s\n" "curl ifconfig.me"         "Show your public IP"
    printf "  ${GREEN}%-35s${NC} %s\n" "ss -tulnp"                "Show open ports"
    echo ""
    echo -e "  ${CYAN}Firewall (firewalld):${NC}"
    printf "  ${CYAN}%-45s${NC} %s\n" "sudo firewall-cmd --state"            "Check if firewall is running"
    printf "  ${CYAN}%-45s${NC} %s\n" "sudo firewall-cmd --list-all"         "Show all rules"
    echo ""
    _nb_pause || return
}

_nb_guide_troubleshoot() {
    echo ""
    echo -e "  ${WHITE}Troubleshooting Common Problems 🔧${NC}"
    echo ""
    echo -e "  Package manager is broken:${NC}"
    printf "  ${CYAN}%-40s${NC} %s\n" "sudo dnf clean all"          "Clear package cache"
    printf "  ${CYAN}%-40s${NC} %s\n" "sudo dnf distro-sync"        "Resync with repos"
    echo ""
    echo -e "  Check logs for errors:${NC}"
    printf "  ${CYAN}%-40s${NC} %s\n" "journalctl -xe"              "Show recent system errors"
    printf "  ${CYAN}%-40s${NC} %s\n" "dmesg | tail -30"           "Kernel messages"
    echo ""
    _nb_tip "The Fedora Ask community (ask.fedoraproject.org) solves 99% of problems!"
    _nb_pause || return
}

_nb_guide_recommended_apps() {
    echo ""
    echo -e "  ${WHITE}Recommended Apps for Beginners 🚀${NC}"
    echo ""
    echo -e "  Web browsers:${NC}"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Firefox"         "(pre-installed)" "Best privacy, Fedora default"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Zen Browser"     "(Flatpak)"       "Fast, modern Firefox fork"
    echo ""
    echo -e "  Office & Productivity:${NC}"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "LibreOffice"     "(DNF)"           "Full MS Office alternative"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "OnlyOffice"      "(Flatpak)"       "Best .docx/.xlsx compatibility"
    echo ""
    echo -e "  Media:${NC}"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "VLC"             "(Flatpak)"       "Plays everything"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Kdenlive"        "(DNF/Flatpak)"   "Video editor"
    echo ""
    echo -e "  Communication:${NC}"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Thunderbird"     "(DNF)"           "Email client"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Discord"         "(Flatpak)"       "Voice + text chat"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Signal"          "(Flatpak)"       "Encrypted messaging"
    echo ""
    echo -e "  Development:${NC}"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "VSCodium"        "(DNF)"           "Best code editor"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Podman Desktop"  "(Flatpak)"       "Containers (like Docker)"
    echo ""
    _nb_tip "This script's options 3 and 4 install many of these automatically!"
    _nb_pause || return
}

_nb_guide_this_script() {
    echo ""
    echo -e "  ${WHITE}How to Use This Setup Script 📋${NC}"
    echo ""
    _nb_step "1" "Option 2  — Setup Repositories (RPM Fusion + Flathub)"
    _nb_step "2" "Option 3  — Install DNF Packages"
    _nb_step "3" "Option 4  — Install Flatpak Apps"
    _nb_step "4" "Option 7  — Install Oh My Posh (beautiful terminal prompt)"
    _nb_step "5" "Option 8  — Configure Fastfetch (system info on startup)"
    _nb_step "6" "Option 11 — Install Homebrew"
    _nb_step "7" "Option 19 — Auto Mount Drives"
    _nb_step "8" "Option 15 — ClamAV Antivirus"
    _nb_step "9" "Option 16 — Linux Security Hardening"
    _nb_step "10" "Option 18 — Privacy & Network (Tor, VPN, DoT)"
    echo ""
    _nb_warn "Option 17 (JShielder) is for advanced users — read what it does first!"
    _nb_tip "Option 1 (Install EVERYTHING) runs all of the above in one go."
    _nb_pause || return
}

noobs_guide_menu() {
    while true; do
        clear
        cat << 'BANNER'
  NOOBS GUIDE -- Fedora Linux for Beginners
  Everything you need to know, explained simply

  Getting Started
  1)  Welcome to Fedora & This Script
  2)  Using the Terminal (essential commands)
  3)  Installing Software (DNF, Flatpak, RPM)
  4)  Understanding sudo & Permissions
  5)  Keeping Your System Updated

  KDE & Daily Use
  6)  Getting Around KDE Plasma
  7)  File System Layout (Where is everything?)
  8)  Networking & WiFi

  Help & Tools
  9)  Troubleshooting Common Problems
  10) Recommended Apps for Beginners
  11) How to Use This Setup Script (recommended order)

  0)  Return to main menu

BANNER
        echo -e "${NC}"
        read -rp "  Select a topic [0-11]: " _nb_choice
        echo ""

        case "$_nb_choice" in
            1)  _nb_guide_welcome ;;
            2)  _nb_guide_terminal ;;
            3)  _nb_guide_packages ;;
            4)  _nb_guide_sudo ;;
            5)  _nb_guide_updates ;;
            6)  _nb_guide_kde ;;
            7)  _nb_guide_files ;;
            8)  _nb_guide_networking ;;
            9)  _nb_guide_troubleshoot ;;
            10) _nb_guide_recommended_apps ;;
            11) _nb_guide_this_script ;;
            0)
                print_success "Returning to main menu."
                return
                ;;
            *)
                print_warning "Invalid choice: ${_nb_choice}"
                ;;
        esac
    done
}

#===========================================
# HOMEBREW
#===========================================

install_homebrew() {
    print_header "Install & Setup Homebrew (Linuxbrew)"

    if check_command brew; then
        print_warning "Homebrew is already installed: $(brew --version | head -1)"
        if ! confirm_action "Re-run Homebrew setup/update anyway?"; then
            return
        fi
    else
        print_section "Installing Homebrew dependencies"
        sudo dnf install -y curl git gcc gcc-c++ make 2>&1 | tee -a "$LOG_FILE"

        print_section "Running Homebrew installer"
        NONINTERACTIVE=1 /bin/bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
            2>&1 | tee -a "$LOG_FILE"
    fi

    local brew_bin=""
    if [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
        brew_bin="/home/linuxbrew/.linuxbrew/bin/brew"
    elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
        brew_bin="$HOME/.linuxbrew/bin/brew"
    fi

    if [[ -z "$brew_bin" ]]; then
        print_error "Homebrew binary not found after install — check $LOG_FILE"
        return 1
    fi

    local brew_shellenv
    brew_shellenv=$("$brew_bin" shellenv)

    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc_file" ]] && ! grep -q "brew shellenv" "$rc_file"; then
            {
                echo ""
                echo "# Homebrew"
                echo "eval \"\$($brew_bin shellenv)\""
            } >> "$rc_file"
            print_success "Homebrew env added to $rc_file"
        fi
    done

    eval "$brew_shellenv"

    brew update 2>&1 | tee -a "$LOG_FILE"
    brew doctor 2>&1 | tee -a "$LOG_FILE" || true

    print_success "Homebrew installed and configured!"
    print_warning "Restart your terminal (or run: eval \"\$(brew shellenv)\") to activate brew."
    log "Homebrew setup complete"
}

#===========================================
# WINBOAT
#===========================================

install_winboat() {
    print_header "Installing WinBoat — Windows Apps on Linux"

    echo ""
    echo -e "  ${CYAN}WinBoat runs Windows inside a Podman/Docker container and streams${NC}"
    echo -e "  ${CYAN}apps to your desktop via FreeRDP — no dual-boot needed.${NC}"
    echo ""
    echo -e "  ${YELLOW}Hardware requirements:${NC}"
    echo -e "    • At least 4 GB RAM and 2 CPU threads"
    echo -e "    • At least 32 GB free disk space"
    echo -e "    • KVM virtualisation enabled in BIOS/UEFI"
    echo ""

    if ! confirm_action "Proceed with WinBoat installation?"; then
        print_warning "Cancelled."
        return
    fi

    print_section "Checking KVM virtualisation support..."
    if [[ -e /dev/kvm ]]; then
        print_success "KVM is available (/dev/kvm found)"
    else
        print_error "/dev/kvm not found — KVM must be enabled in your BIOS/UEFI."
        return 1
    fi

    echo ""
    echo -e "  ${CYAN}Choose containerisation backend:${NC}"
    echo -e "    ${WHITE}1)${NC} Podman  (recommended)"
    echo -e "    ${WHITE}2)${NC} Docker"
    echo ""
    read -rp "  Select [1/2]: " wb_backend
    case "$wb_backend" in
        2) wb_backend="docker" ;;
        *) wb_backend="podman" ;;
    esac
    print_success "Backend selected: $wb_backend"

    if [[ "$wb_backend" == "podman" ]]; then
        run_with_spinner "Installing Podman prerequisites..." \
            sudo dnf install -y podman podman-compose freerdp
        systemctl --user enable --now podman.socket 2>&1 | tee -a "$LOG_FILE" || \
            print_warning "Could not enable podman.socket — you may need to log out and back in."
        print_success "Podman socket enabled"
    else
        run_with_spinner "Installing Docker prerequisites..." \
            sudo dnf install -y docker docker-compose-plugin freerdp
        sudo systemctl enable --now docker 2>&1 | tee -a "$LOG_FILE"
        if getent group docker &>/dev/null; then
            sudo gpasswd -a "${USER}" docker 2>/dev/null \
                && print_success "Added ${USER} to docker group (log out/in required)" \
                || print_warning "Could not add ${USER} to docker group"
        fi
    fi

    print_section "Fetching latest WinBoat release from GitHub..."
    local api_url="https://api.github.com/repos/TibixDev/winboat/releases/latest"
    local rpm_url
    rpm_url=$(curl -sf "$api_url" \
        | grep -oP '"browser_download_url":\s*"\K[^"]+' \
        | grep '\.rpm$' \
        | head -1) || true

    if [[ -z "$rpm_url" ]]; then
        print_error "Could not fetch WinBoat release URL from GitHub API."
        print_warning "Visit https://github.com/TibixDev/winboat/releases and install the .rpm manually."
        return 1
    fi

    local rpm_file="/tmp/winboat-latest.rpm"
    if ! run_with_spinner "Downloading WinBoat RPM..." curl -sL "$rpm_url" -o "$rpm_file"; then
        print_error "Download failed — check your connection."
        return 1
    fi

    if run_with_spinner "Installing WinBoat RPM..." sudo dnf install -y --allowerasing "$rpm_file"; then
        print_success "WinBoat installed successfully!"
        log "WinBoat installed from $rpm_url"
    else
        print_error "RPM install failed — check $LOG_FILE"
        rm -f "$rpm_file"
        return 1
    fi
    rm -f "$rpm_file"

    echo ""
    print_success "WinBoat setup complete!"
    echo -e "  ${CYAN}Docs:${NC} https://winboat.app"
    echo -e "  ${CYAN}Repo:${NC} https://github.com/TibixDev/winboat"
}

#===========================================
# HYPRLAND + DOTFILES
#===========================================

install_hyprland() {
    print_header "Hyprland Install + Dotfiles"

    echo ""
    echo -e "${YELLOW}  ⚠  WARNING: Hyprland replaces your current desktop session.${NC}"
    echo -e "${YELLOW}     Back up your system with Timeshift before proceeding!${NC}"
    echo ""
    echo -e "${CYAN}  Choose a Hyprland dotfile preset:${NC}"
    echo ""
    echo -e "  ${WHITE}1) JaKooLit${NC}  — Cyberpunk/Neon aesthetic. Fedora-native installer."
    echo -e "  ${WHITE}2) ML4W${NC}      — Professional glass/material theme. GUI settings app included."
    echo -e "  ${WHITE}3) end-4${NC}     — Most starred on GitHub (~14k ⭐). AI sidebar, adaptive colors."
    echo -e "  ${WHITE}0) Cancel${NC}"
    echo ""
    read -rp "  Select a preset [0-3]: " _hypr_choice

    case "$_hypr_choice" in
        1) _hyprland_jakoolit ;;
        2) _hyprland_ml4w ;;
        3) _hyprland_end4 ;;
        0) print_warning "Hyprland install cancelled."; return ;;
        *) print_error "Invalid choice."; return 1 ;;
    esac
}

_hyprland_jakoolit() {
    print_section "JaKooLit — Fedora Hyprland Installer"
    if ! confirm_action "Clone and launch JaKooLit Fedora-Hyprland installer?"; then
        print_warning "Cancelled."
        return
    fi
    local INSTALL_DIR="$HOME/Fedora-Hyprland"
    if [[ -d "$INSTALL_DIR" ]]; then
        print_warning "Directory $INSTALL_DIR already exists — pulling latest..."
        git -C "$INSTALL_DIR" pull 2>&1 | tee -a "$LOG_FILE"
    else
        git clone --depth=1 https://github.com/JaKooLit/Fedora-Hyprland.git "$INSTALL_DIR" \
            2>&1 | tee -a "$LOG_FILE"
    fi
    chmod +x "$INSTALL_DIR/install.sh"
    echo -e "${YELLOW}  The installer will now take over. Follow the on-screen prompts.${NC}"
    sleep 2
    cd "$INSTALL_DIR" && bash install.sh
}

_hyprland_ml4w() {
    print_section "ML4W — Professional Hyprland Dotfiles"
    if ! confirm_action "Launch ML4W stable installer?"; then
        print_warning "Cancelled."
        return
    fi
    bash <(curl -s https://ml4w.com/os/stable) 2>&1 | tee -a "$LOG_FILE"
}

_hyprland_end4() {
    print_section "end-4 — illogical-impulse Hyprland Dotfiles"
    echo -e "${RED}  Note: end-4 targets Arch primarily. On Fedora some packages may need manual adjustment.${NC}"
    if ! confirm_action "Launch end-4 installer?"; then
        print_warning "Cancelled."
        return
    fi
    bash <(curl -s https://ii.clsty.link/get) 2>&1 | tee -a "$LOG_FILE"
}

#===========================================
# GRUB BOOTLOADER REPAIR
#===========================================

repair_grub() {
    print_header "GRUB Bootloader Repair (Live USB)"

    echo ""
    echo -e "${YELLOW}  ⚠  This tool repairs a missing or broken GRUB bootloader on your Fedora"
    echo -e "     installation using a Fedora Live USB environment.${NC}"
    echo ""
    echo -e "${CYAN}  What this will do:${NC}"
    echo -e "    • Detect your Fedora root partition and EFI/boot partition"
    echo -e "    • Mount and chroot into your installed system"
    echo -e "    • Reinstall GRUB2 to the correct target disk"
    echo -e "    • Regenerate grub.cfg"
    echo -e "    • Unmount everything cleanly"
    echo ""

    # Must be run from a live environment
    if [[ ! -f /run/initramfs/live/LiveOS/squashfs.img ]] && \
       ! grep -q "rd.live" /proc/cmdline 2>/dev/null && \
       ! grep -q "liveimg" /proc/cmdline 2>/dev/null; then
        echo -e "${YELLOW}  ⚠  Live USB environment not detected.${NC}"
        echo -e "${YELLOW}     This tool is designed to run from a Fedora Live USB.${NC}"
        echo -e "${YELLOW}     Proceeding anyway — make sure you know what you are doing!${NC}"
        echo ""
        if ! confirm_action "Continue without a confirmed Live USB environment?"; then
            print_warning "GRUB repair cancelled."
            return
        fi
    fi

    # ── Step 1: List block devices ──────────────────────────────────────────
    print_section "Detecting partitions"
    echo -e "  ${CYAN}Available block devices:${NC}"
    echo ""
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT | sed 's/^/    /'
    echo ""

    # ── Step 2: Ask user for root partition ─────────────────────────────────
    local root_part efi_part target_disk
    read -rp "  Enter your Fedora ROOT partition (e.g. /dev/sda3 or /dev/nvme0n1p3): " root_part

    if [[ -z "$root_part" || ! -b "$root_part" ]]; then
        print_error "Invalid partition: '$root_part'. Must be a valid block device."
        return 1
    fi

    # ── Step 3: Auto-detect EFI or ask ─────────────────────────────────────
    local efi_candidates
    efi_candidates=$(lsblk -o NAME,FSTYPE,PARTTYPE -r | \
        awk '$2=="vfat" || $3=="c12a7328-f81f-11d2-ba4b-00a0c93ec93b" {print "/dev/"$1}' 2>/dev/null || true)

    if [[ -n "$efi_candidates" ]]; then
        echo ""
        echo -e "  ${CYAN}Possible EFI/boot partitions detected:${NC}"
        echo "$efi_candidates" | sed 's/^/    /'
        echo ""
    fi

    read -rp "  Enter your EFI partition (e.g. /dev/sda1) — leave blank if BIOS/MBR only: " efi_part

    if [[ -n "$efi_part" && ! -b "$efi_part" ]]; then
        print_error "Invalid EFI partition: '$efi_part'. Must be a valid block device or left blank."
        return 1
    fi

    # ── Step 4: Derive target disk from root partition ──────────────────────
    target_disk=$(lsblk -no PKNAME "$root_part" 2>/dev/null | head -1 || true)
    if [[ -z "$target_disk" ]]; then
        read -rp "  Could not auto-detect disk. Enter target disk (e.g. sda or nvme0n1): " target_disk
    fi
    # Strip leading /dev/ if the user or lsblk already included it
    target_disk="${target_disk#/dev/}"
    target_disk="/dev/${target_disk}"

    echo ""
    echo -e "  ${WHITE}Summary:${NC}"
    echo -e "    Root partition : ${CYAN}${root_part}${NC}"
    echo -e "    EFI partition  : ${CYAN}${efi_part:-none (BIOS/MBR mode)}${NC}"
    echo -e "    Target disk    : ${CYAN}${target_disk}${NC}"
    echo ""

    if ! confirm_action "Proceed with GRUB repair using the above settings?"; then
        print_warning "GRUB repair cancelled."
        return
    fi

    # ── Step 5: Mount root ──────────────────────────────────────────────────
    local CHROOT_MNT="/mnt/fedora_grub_repair"
    print_section "Mounting filesystems"

    sudo mkdir -p "$CHROOT_MNT"

    # Detect filesystem type for root
    local root_fstype
    root_fstype=$(blkid -o value -s TYPE "$root_part" 2>/dev/null || echo "auto")

    if [[ "$root_fstype" == "btrfs" ]]; then
        if ! run_with_spinner "Mounting Btrfs root (subvol=root)..." \
                sudo mount -o subvol=root "$root_part" "$CHROOT_MNT"; then
            run_with_spinner "Mounting Btrfs root (no subvol)..." \
                sudo mount "$root_part" "$CHROOT_MNT"
        fi
    else
        run_with_spinner "Mounting root partition..." \
            sudo mount "$root_part" "$CHROOT_MNT"
    fi
    print_success "Root mounted at $CHROOT_MNT"

    # Mount EFI if provided
    if [[ -n "$efi_part" ]]; then
        sudo mkdir -p "$CHROOT_MNT/boot/efi"
        run_with_spinner "Mounting EFI partition..." \
            sudo mount "$efi_part" "$CHROOT_MNT/boot/efi"
        print_success "EFI mounted at $CHROOT_MNT/boot/efi"
    fi

    # Also mount /boot if it is a separate partition
    local boot_part
    boot_part=$(lsblk -o NAME,PARTLABEL,MOUNTPOINT -r | \
        awk '$2=="boot" || $3=="/boot" {print "/dev/"$1}' 2>/dev/null | \
        grep -v "^$root_part$" | head -1 || true)
    if [[ -n "$boot_part" && "$boot_part" != "$root_part" ]]; then
        sudo mkdir -p "$CHROOT_MNT/boot"
        run_with_spinner "Mounting /boot partition ($boot_part)..." \
            sudo mount "$boot_part" "$CHROOT_MNT/boot"
        print_success "/boot mounted at $CHROOT_MNT/boot"
    fi

    # Bind-mount pseudo-filesystems
    print_section "Bind-mounting system filesystems"
    for fs in proc sys dev dev/pts run; do
        run_with_spinner "Binding /${fs}..." \
            sudo mount --bind "/$fs" "$CHROOT_MNT/$fs" || true
    done
    print_success "Pseudo-filesystems ready"

    # ── Step 6: Reinstall GRUB inside chroot ────────────────────────────────
    print_section "Reinstalling GRUB2"

    if [[ -n "$efi_part" ]]; then
        # UEFI path
        print_section "Installing GRUB2 (UEFI)"
        if sudo chroot "$CHROOT_MNT" /bin/bash -c "
            dnf reinstall -y grub2-efi-x64 grub2-efi-x64-modules shim-x64 2>&1
            grub2-install --target=x86_64-efi \
                --efi-directory=/boot/efi \
                --bootloader-id=fedora \
                --recheck 2>&1
        " 2>&1 | tee -a "$LOG_FILE" > /dev/null; then
            print_success "GRUB2 EFI binaries installed"
        else
            print_error "grub2-install (UEFI) had errors — check $LOG_FILE"
        fi
    else
        # BIOS/MBR path
        print_section "Installing GRUB2 (BIOS/MBR) → $target_disk"
        if sudo chroot "$CHROOT_MNT" /bin/bash -c "
            dnf reinstall -y grub2-pc grub2-pc-modules 2>&1
            grub2-install --target=i386-pc \
                --recheck '$target_disk' 2>&1
        " 2>&1 | tee -a "$LOG_FILE" > /dev/null; then
            print_success "GRUB2 MBR written to $target_disk"
        else
            print_error "grub2-install (BIOS) had errors — check $LOG_FILE"
        fi
    fi

    # ── Step 7: Regenerate grub.cfg ─────────────────────────────────────────
    print_section "Regenerating grub.cfg"
    if sudo chroot "$CHROOT_MNT" /bin/bash -c "
        grub2-mkconfig -o /boot/grub2/grub.cfg 2>&1
    " 2>&1 | tee -a "$LOG_FILE" > /dev/null; then
        print_success "grub.cfg regenerated"
    else
        print_error "grub2-mkconfig had errors — check $LOG_FILE"
    fi

    # ── Step 8: Cleanup ──────────────────────────────────────────────────────
    print_section "Unmounting filesystems"
    for fs in dev/pts dev proc sys run boot/efi boot ""; do
        sudo umount "$CHROOT_MNT/$fs" 2>/dev/null || true
    done
    sudo rmdir "$CHROOT_MNT" 2>/dev/null || true
    print_success "All filesystems unmounted"

    echo ""
    print_success "GRUB repair complete!"
    echo ""
    echo -e "  ${CYAN}Next steps:${NC}"
    echo -e "    1. Remove the Live USB"
    echo -e "    2. Reboot → your system should boot normally"
    echo -e "    3. If it still fails, check ${YELLOW}$LOG_FILE${NC} for errors"
    echo -e "    4. For Secure Boot issues: run ${WHITE}mokutil --sb-state${NC} inside the repaired system"
    echo ""
}

#===========================================
# MAIN MENU
#===========================================

show_menu() {
    clear
    echo ""
    echo "███████╗███████╗██████╗  ██████╗ ██████╗  █████╗"
    echo "██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔══██╗██╔══██╗"
    echo "█████╗  █████╗  ██║  ██║██║   ██║██████╔╝███████║"
    echo "██╔══╝  ██╔══╝  ██║  ██║██║   ██║██╔══██╗██╔══██║"
    echo "██║     ███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║"
    echo "╚═╝     ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝"
    echo "           Created by: ineednotitle               "
    echo "================================================="
    echo ""
    echo "  1)  Install EVERYTHING"
    echo ""
    echo "  -- Package Installation --"
    echo "  2)  Setup Repositories (RPM Fusion, Flathub, Terra)"
    echo "  3)  Install DNF Packages"
    echo "  4)  Install Flatpak Applications"
    echo "  5)  Clone & Build GitHub Repos"
    echo "  6)  Install GitHub Releases"
    echo ""
    echo "  -- Shell & Terminal --"
    echo "  7)  Install Oh My Posh"
    echo "  8)  Configure Fastfetch"
    echo "  9)  Install & Configure Zsh"
    echo "  10) Install & Configure Fish Shell (CachyOS-style)"
    echo ""
    echo "  -- Development Tools --"
    echo "  11) Install & Setup Homebrew (Linuxbrew)"
    echo "  12) Install WinBoat — Run Windows apps on Linux"
    echo ""
    echo "  -- Drivers & Apps --"
    echo "  13) Install NVIDIA Drivers"
    echo "  14) Install AppImages (Helium, Capacities, Affinity)"
    echo ""
    echo "  -- Security --"
    echo "  15) Install & Configure ClamAV Antivirus"
    echo "  16) Linux Security Hardening (Chris Titus)"
    echo "  17) JShielder — Full System Hardening (KDE Edition)"
    echo ""
    echo "  -- Privacy & Network --"
    echo "  18) Privacy & Network Tools (Tor, MAC spoof, WireGuard, DoT)"
    echo ""
    echo "  -- Storage --"
    echo "  19) Auto Mount All Drives"
    echo ""
    echo "  -- Help & Learning --"
    echo "  20) NOOBS GUIDE — Learn Fedora Linux"
    echo ""
    echo "  -- Privacy Extras --"
    echo "  21) Harden Browser Privacy (Firefox / LibreWolf / Zen)"
    echo ""
    echo "  -- Desktop --"
    echo "  22) Install Hyprland + Dotfiles (JaKooLit / ML4W / end-4)"
    echo ""
    echo "  -- System Recovery --"
    echo "  23) Repair GRUB Bootloader (from Fedora Live USB)"
    echo ""
    echo "  0)  Exit"
    echo ""
    read -rp "  Select an option [0-23]: " choice
}

install_everything() {
    print_header "Installing Everything - Full Setup"

    echo -e "${YELLOW}This will install all packages and configurations.${NC}"
    read -p "Continue? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Cancelled"
        return
    fi

    setup_repositories
    install_dnf_packages
    install_flatpak_packages
    clone_github_repos
    install_github_releases
    install_oh_my_posh
    configure_fastfetch
    install_homebrew
    install_winboat
    install_nvidia_drivers
    install_appimages
    install_clamav
    install_linux_hardening
    install_jshielder_hardening

    print_header "Installation Complete!"
    echo -e "  ${GREEN}Log file: $LOG_FILE${NC}"
    echo ""
    echo -e "  ${YELLOW}Next steps:${NC}"
    echo -e "    1. Restart your terminal"
    echo -e "    2. Set terminal font to a Nerd Font"
    echo -e "    3. Run option 9 to set up Zsh"
    echo -e "    4. Run option 10 to set up Fish Shell"
    echo -e "    5. Open menu option 18 for Privacy & Network setup"
    echo -e "    6. Open menu option 19 to mount all your drives"
    echo -e "    7. Run option 21 — harden Firefox/LibreWolf browser"
    echo -e "    8. New to Linux? Visit menu option 20 — Noobs Guide!"
    echo ""
    echo -e "  ${CYAN}Enjoy your new Fedora setup!${NC}"
}

#===========================================
# MAIN
#===========================================

if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Don't run this script as root!${NC}"
    echo -e "${YELLOW}Run as regular user. Script will ask for sudo when needed.${NC}"
    exit 1
fi

sudo -v
_sudo_keepalive

create_directories

echo "==> Fedora Complete Setup Script v2.0 — starting up"

while true; do
    show_menu

    case $choice in
        1)  install_everything ;;
        2)  setup_repositories ;;
        3)  install_dnf_packages ;;
        4)  install_flatpak_packages ;;
        5)  clone_github_repos ;;
        6)  install_github_releases ;;
        7)  install_oh_my_posh ;;
        8)  configure_fastfetch ;;
        9)  install_zsh ;;
        10) install_fish ;;
        11) install_homebrew ;;
        12) install_winboat ;;
        13) install_nvidia_drivers ;;
        14) install_appimages ;;
        15) install_clamav ;;
        16) install_linux_hardening ;;
        17) install_jshielder_hardening ;;
        18) privacy_network_menu ;;
        19) automount_drives ;;
        20) noobs_guide_menu ;;
        21) harden_browser_privacy ;;
        22) install_hyprland ;;
        23) repair_grub ;;
        0)
            echo -e "\n${GREEN}Goodbye! Sweet Heart <3${NC}\n"
            exit 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac

    echo ""
    read -p "Press Enter to continue..."
done
