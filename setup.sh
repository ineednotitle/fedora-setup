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
#   Version: 0.8 --beta
#   Modules: Fedora · Browsers Harding · Security · VPN · Privacy · More
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

# Directories
GITHUB_DIR="$HOME/GitHub"
LOCAL_BIN="$HOME/.local/bin"
APPIMAGE_DIR="$HOME/Applications"
JSHIELDER_BACKUP_DIR="$HOME/jshielder_backups_$(date +%Y%m%d_%H%M%S)"

# Log file
LOG_FILE="$HOME/setup_log_$(date +%Y%m%d_%H%M%S).txt"

# ── sudo keepalive ─────────────────────────────────────────────────────
# Refreshes the sudo timestamp every 55 s so long operations (DNF update,
# Flatpak batch install, etc.) never hit a mid-run "sudo: session expired".
_sudo_keepalive() {
    while true; do sudo -n true; sleep 55; done 2>/dev/null &
    _SUDO_KA_PID=$!
    # Clean up on exit: kill keepalive, restore cursor
    trap 'kill "$_SUDO_KA_PID" 2>/dev/null' EXIT
}

#===========================================
# PACKAGE LISTS
#===========================================

# DNF Packages
DNF_PACKAGES=(
    # Development
    git
    make
    cmake
    python3
    python3-pip
    nodejs
    npm

    # Utilities
    fastfetch
    tmux
    curl
    wget
    unzip
    jq
    fzf

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

# Flatpak Applications
FLATPAK_PACKAGES=(
    # Communication
    "com.discordapp.Discord"
    "org.telegram.desktop"
    "org.signal.Signal"

    # Productivity
    "md.obsidian.Obsidian"
    "org.onlyoffice.desktopeditors"

    # Development
    "com.vscodium.codium"
    "io.podman_desktop.PodmanDesktop"

    #Creativity
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
    "com.brave.Browser"
    "app.zen_browser.zen"
    "io.gitlab.librewolf-community"

    # Utilities
    "org.flameshot.Flameshot"
    "io.github.peazip.PeaZip"
    "io.github.ilya_zlobintsev.LACT"
    "io.ente.auth"
    "org.localsend.localsend_app"
    "com.github.wwmm.easyeffects"
)

# GitHub Repositories
# Format: "repo_url|branch|install_type|install_command"
# install_type: clone, make, cmake, script, cargo, go, npm
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
    # One mkdir call instead of three
    mkdir -p "$GITHUB_DIR" "$LOCAL_BIN" "$APPIMAGE_DIR"

    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        export PATH="$LOCAL_BIN:$PATH"
    fi
}

#===========================================
# INSTALLATION FUNCTIONS
#===========================================

setup_repositories() {
    print_header "Setting Up Repositories"

    print_section "Installing RPM Fusion Free"
    if ! rpm -q rpmfusion-free-release &>/dev/null; then
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
        print_success "RPM Fusion Free installed"
    else
        print_warning "RPM Fusion Free already installed"
    fi

    print_section "Installing RPM Fusion Non-Free"
    if ! rpm -q rpmfusion-nonfree-release &>/dev/null; then
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
        print_success "RPM Fusion Non-Free installed"
    else
        print_warning "RPM Fusion Non-Free already installed"
    fi

    print_section "Setting up Flathub"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    print_success "Flathub configured"

    print_section "Adding Terra repository (fyralabs)"
    if dnf repolist | grep -q "terra"; then
        print_warning "Terra repo already configured"
    else
        sudo dnf install -y \
            "https://github.com/terrapkg/subatomic-repos/raw/main/terra.repo" 2>/dev/null || \
        sudo dnf config-manager --add-repo \
            "https://terra.fyralabs.com/terra.repo" 2>/dev/null || true
        # Fallback: write the repo file directly
        if ! dnf repolist 2>/dev/null | grep -q "terra"; then
            sudo tee /etc/yum.repos.d/terra.repo > /dev/null << 'TERRA_REPO'
[terra]
name=Terra - $basearch
baseurl=https://repos.fyralabs.com/terra$releasever/$basearch/
type=rpm
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://terra.fyralabs.com/public.gpg
enabled=1
TERRA_REPO
        fi
        print_success "Terra repository added"
    fi
}

install_dnf_packages() {
    print_header "Installing DNF Packages"

    print_section "Updating system"
    sudo dnf update -y

    # ── Batch install ──────────────────────────────────────────────────
    # Build the to-install list first, then call dnf ONCE for the whole
    # batch.  Previously: one `dnf install` per package = loading the full
    # package metadata N times.  Now: one metadata load, one transaction.
    # Typical speedup: ~5 min → ~30 sec for this package list.
    print_section "Checking installed packages"
    local to_install=() pkg
    for pkg in "${DNF_PACKAGES[@]}"; do
        if rpm -q "$pkg" &>/dev/null; then
            echo -e "  ${YELLOW}already installed:${NC} $pkg"
        else
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        print_success "All packages already installed"
        return
    fi

    print_section "Installing ${#to_install[@]} package(s) in one transaction..."
    # Use PIPESTATUS to catch dnf exit code even when piped through tee
    sudo dnf install -y "${to_install[@]}" 2>&1 | tee -a "$LOG_FILE"; local _dnf_rc=${PIPESTATUS[0]}
    if [[ $_dnf_rc -eq 0 ]]; then
        print_success "All packages installed"
    else
        print_error "Some packages failed (exit $_dnf_rc) — check $LOG_FILE"
        log "DNF batch install had failures (exit $_dnf_rc)"
    fi
}

install_flatpak_packages() {
    print_header "Installing Flatpak Applications"

    # One `flatpak list` call upfront instead of once per app.
    # `flatpak list` is slow (it queries the OSTree repo); calling it in a
    # loop multiplied that cost by the number of packages.
    local installed_list
    installed_list=$(flatpak list --app --columns=application 2>/dev/null)

    local to_install=() app
    for app in "${FLATPAK_PACKAGES[@]}"; do
        if echo "$installed_list" | grep -qF "$app"; then
            echo -e "  ${YELLOW}already installed:${NC} $app"
        else
            to_install+=("$app")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        print_success "All Flatpak apps already installed"
        return
    fi

    # Install all pending apps in one flatpak transaction.
    # NOTE: We do NOT pipe through `tee` here — flatpak detects whether stdout
    # is a TTY and only shows the live progress bar / spinner when it is.
    # Piping to tee converts stdout to a pipe (non-TTY), which suppresses the
    # interactive progress display entirely.  Log the result separately instead.
    print_section "Installing ${#to_install[@]} Flatpak app(s) in one transaction..."
    if flatpak install -y flathub "${to_install[@]}"; then
        print_success "All Flatpak apps installed"
        log "Flatpak batch install succeeded: ${to_install[*]}"
    else
        print_error "Some Flatpak apps failed — check $LOG_FILE"
        log "Flatpak batch install had failures: ${to_install[*]}"
    fi
}

clone_github_repos() {
    print_header "Cloning GitHub Repositories"

    pushd "$GITHUB_DIR" > /dev/null

    local repo_entry repo_url branch install_type install_cmd repo_name
    for repo_entry in "${GITHUB_REPOS[@]}"; do
        IFS='|' read -r repo_url branch install_type install_cmd <<< "$repo_entry"
        repo_name=$(basename "$repo_url" .git)

        print_section "Processing: $repo_name"

        if [[ -d "$repo_name" ]]; then
            print_warning "Directory exists, pulling latest..."
            cd "$repo_name"
            git pull origin "$branch" &>> "$LOG_FILE"
            cd ..
        else
            echo "  Cloning $repo_url..."
            if git clone --branch "$branch" "$repo_url" &>> "$LOG_FILE"; then
                print_success "Cloned successfully"
            else
                print_error "Clone failed"
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
                echo "  Running make..."
                if eval "$install_cmd" &>> "$LOG_FILE"; then
                    print_success "Build completed"
                else
                    print_error "Build failed"
                fi
                ;;
            cmake)
                echo "  Running cmake build..."
                mkdir -p build && cd build
                if { cmake .. && make && sudo make install; } &>> "$LOG_FILE"; then
                    print_success "Build completed"
                else
                    print_error "Build failed"
                fi
                cd ..
                ;;
            script)
                echo "  Running install script..."
                if [[ -f "$install_cmd" ]]; then
                    chmod +x "$install_cmd"
                    if ./"$install_cmd" &>> "$LOG_FILE"; then
                        print_success "Script completed"
                    else
                        print_error "Script failed"
                    fi
                fi
                ;;
            cargo)
                echo "  Building with Cargo..."
                if eval "$install_cmd" &>> "$LOG_FILE"; then
                    cp target/release/* "$LOCAL_BIN/" 2>/dev/null || true
                    print_success "Build completed"
                else
                    print_error "Build failed"
                fi
                ;;
            go)
                echo "  Building with Go..."
                if go build -o "$LOCAL_BIN/$repo_name" &>> "$LOG_FILE"; then
                    print_success "Build completed"
                else
                    print_error "Build failed"
                fi
                ;;
            npm)
                echo "  Installing with npm..."
                if { npm install && npm run build --if-present; } &>> "$LOG_FILE"; then
                    print_success "Build completed"
                else
                    print_error "Build failed"
                fi
                ;;
        esac

        popd > /dev/null && pushd "$GITHUB_DIR" > /dev/null
    done
    popd > /dev/null
}

install_github_releases() {
    print_header "Installing GitHub Releases"

    # Ensure jq is present (it's in DNF_PACKAGES, but guard anyway)
    if ! check_command jq; then
        print_warning "jq not found — installing..."
        sudo dnf install -y jq &>> "$LOG_FILE"
    fi

    local temp_dir
    temp_dir=$(mktemp -d)
    # NOTE: trap is set AFTER wait loop so cleanup only runs after all
    # background subshells finish — not before them.

    # ── Parallel downloads ─────────────────────────────────────────────
    # Each release is fetched + installed in its own background subshell.
    # For 4 binaries this cuts network-bound time by ~75 %.
    _fetch_and_install_one() {
        local entry="$1" tdir="$2"
        local repo binary_name asset_pattern
        IFS='|' read -r repo binary_name asset_pattern <<< "$entry"

        if check_command "$binary_name"; then
            echo -e "  ${YELLOW}already installed:${NC} $binary_name"
            return
        fi

        local api_url="https://api.github.com/repos/$repo/releases/latest"
        local download_url
        download_url=$(curl -sf "$api_url" \
            | jq -r ".assets[] | select(.name | test(\"$asset_pattern\")) | .browser_download_url" \
            | head -1) || true

        if [[ -z "$download_url" || "$download_url" == "null" ]]; then
            echo -e "  ${RED}✗ Asset not found: $binary_name${NC}"
            log "Asset not found: $binary_name"
            return
        fi

        local filename dl_dir
        filename=$(basename "$download_url")
        dl_dir="$tdir/$binary_name"
        mkdir -p "$dl_dir"

        echo "  Downloading $binary_name..."
        if ! curl -sfL "$download_url" -o "$dl_dir/$filename"; then
            echo -e "  ${RED}✗ Download failed: $binary_name${NC}"
            log "Download failed: $binary_name"
            return
        fi

        cd "$dl_dir"
        case "$filename" in
            *.tar.gz|*.tgz) tar -xzf "$filename" ;;
            *.zip)          unzip -q "$filename" ;;
            *)
                chmod +x "$filename"
                cp "$filename" "$LOCAL_BIN/$binary_name"
                echo -e "  ${GREEN}✓ Installed $binary_name${NC}"
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
            echo -e "  ${GREEN}✓ Installed $binary_name to $LOCAL_BIN${NC}"
        else
            echo -e "  ${RED}✗ Binary not found in archive: $binary_name${NC}"
            log "Binary not found: $binary_name"
        fi
    }

    local pids=() entry
    for entry in "${GITHUB_RELEASES[@]}"; do
        _fetch_and_install_one "$entry" "$temp_dir" &
        pids+=($!)
    done

    local failed=0 pid
    for pid in "${pids[@]}"; do
        wait "$pid" || { failed=$(( failed + 1 )); } || true
    done

    [[ $failed -gt 0 ]] && print_warning "$failed download(s) had issues — check $LOG_FILE"
    print_success "GitHub Releases done"
    # Cleanup temp dir only after all background jobs have finished
    rm -rf "$temp_dir"
}

#===========================================
# OH MY POSH & FASTFETCH
#===========================================

install_oh_my_posh() {
    print_header "Installing Oh My Posh"

    if check_command oh-my-posh; then
        print_warning "Oh My Posh already installed"
        return
    fi

    print_section "Downloading Oh My Posh..."
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$LOCAL_BIN"

    mkdir -p "$HOME/.config/oh-my-posh/themes"

    print_section "Downloading themes..."
    wget -q https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip \
        -O /tmp/themes.zip
    unzip -o -q /tmp/themes.zip -d "$HOME/.config/oh-my-posh/themes"
    rm /tmp/themes.zip
    chmod u+rw "$HOME/.config/oh-my-posh/themes"/*.json 2>/dev/null || true

    if ! grep -q "oh-my-posh" "$HOME/.bashrc"; then
        cat >> "$HOME/.bashrc" << 'EOF'

# Oh My Posh
eval "$(oh-my-posh init bash --config $HOME/.config/oh-my-posh/themes/clean-detailed.omp.json)"
EOF
    fi

    if [[ -f "$HOME/.zshrc" ]] && ! grep -q "oh-my-posh" "$HOME/.zshrc"; then
        cat >> "$HOME/.zshrc" << 'EOF'

# Oh My Posh
eval "$(oh-my-posh init zsh --config $HOME/.config/oh-my-posh/themes/agnoster.omp.json)"
EOF
    fi

    print_success "Oh My Posh installed"
    print_success "Default theme: agnoster"
    echo -e "  ${CYAN}Change theme by editing ~/.bashrc${NC}"
    echo -e "  ${CYAN}Available themes: ~/.config/oh-my-posh/themes/${NC}"
    echo ""
    echo -e "  ${YELLOW}Popular themes:${NC}"
    echo -e "    - agnoster  - atomic  - dracula  - gruvbox"
    echo -e "    - catppuccin  - tokyo  - night-owl  - powerlevel10k_rainbow"
}

configure_fastfetch() {
    print_header "Configuring Fastfetch"

    if ! check_command fastfetch; then
        print_warning "Fastfetch not installed. Installing..."
        sudo dnf install -y fastfetch
    fi

    mkdir -p "$HOME/.config/fastfetch"

    print_section "Creating custom configuration..."
    cat > "$HOME/.config/fastfetch/config.jsonc" << 'EOF'
// @milksuckerboy
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "source": "${HOME}/.config/fastfetch/photo.png",
        "type": "kitty",
        "height": 20,
        "padding":{
                    "left":3,
                    "top":1,
                            },
    },
    "modules": [
        "title",
        "separator",
        "os",
        "host",
        {
            "type": "kernel",
            "format": "{release}"
        },
        "uptime",
        {
            "type": "packages",
            "combined": true
        },
        "shell",
        {
            "type": "display",
            "compactType": "original",
            "key": "Resolution"
        },
        "de",
        "wm",
        "wmtheme",
        "terminal",
        {
            "type": "terminalfont",
            "format": "{/name}{-}{/}{name}{?size} {size}{?}"
        },
        "cpu",
        {
            "type": "gpu",
            "key": "GPU",
            "format": "{name}"
        },
        {
            "type": "memory",
            "format": "{used} / {total}"
        },
        { "type": "disk",      "key": "Disk (/)", "folders": "/" },
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
            printf '\n# Fastfetch on startup\nfastfetch\n' >> "$HOME/.bashrc"
            print_success "Added fastfetch to .bashrc"
        else
            print_warning "Fastfetch already in .bashrc"
        fi
    fi

    print_success "Fastfetch configured"
    echo -e "  ${CYAN}Config location: ~/.config/fastfetch/config.jsonc${NC}"
}

#===========================================
# ADDITIONAL INSTALLERS
#===========================================

install_nerd_fonts() {
    print_header "Installing Nerd Fonts"

    local font_dir="$HOME/.local/share/fonts"
    mkdir -p "$font_dir"

    # ── Download both fonts in parallel ───────────────────────────────
    # Previously: sequential wget (download A → unzip A → download B → unzip B).
    # Now: both downloads happen simultaneously, cutting wall-clock time ~50 %.
    _dl_font() {
        local name="$1" url="$2" dir="$3"
        echo "  Fetching $name..."
        if wget -q --show-progress "$url" -O "$dir/${name}.zip"; then
            unzip -o -q "$dir/${name}.zip" -d "$dir"
            rm "$dir/${name}.zip"
            echo -e "  ${GREEN}✓ $name installed${NC}"
        else
            echo -e "  ${RED}✗ $name download failed${NC}"
        fi
    }

    _dl_font "JetBrainsMono" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" \
        "$font_dir" &
    local pid1=$!

    _dl_font "FiraCode" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip" \
        "$font_dir" &
    local pid2=$!

    wait "$pid1" || true
    wait "$pid2" || true

    print_section "Refreshing font cache..."
    fc-cache -fv &>> "$LOG_FILE"

    print_success "Nerd Fonts installed"
    echo -e "  ${CYAN}Set your terminal font to 'JetBrainsMono Nerd Font' or 'FiraCode Nerd Font'${NC}"
}

install_rust() {
    print_header "Installing Rust"

    if check_command rustc; then
        print_warning "Rust already installed"
        rustc --version
        return
    fi

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"

    print_success "Rust installed"
}

install_nvm() {
    print_header "Installing NVM (Node Version Manager)"

    if [[ -d "$HOME/.nvm" ]]; then
        print_warning "NVM already installed"
        return
    fi

    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

    print_success "NVM installed"
    echo -e "  ${CYAN}Restart terminal, then run: nvm install --lts${NC}"
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
            print_section "Installing akmod-nvidia (standard)..."
            sudo dnf install -y akmod-nvidia
            print_success "akmod-nvidia installed"
            ;;
        2)
            print_section "Installing akmod-nvidia + CUDA support..."
            sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
            print_success "akmod-nvidia + CUDA installed"
            echo -e "  ${CYAN}CUDA libraries installed for GPU compute workloads${NC}"
            ;;
        3)
            print_section "Installing akmod-nvidia-open (open kernel module)..."
            sudo dnf install -y akmod-nvidia-open
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
        # tee avoids two separate `sudo sh -c` calls
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
    echo -e "    ${WHITE}4)${NC} All of the above (parallel)"
    echo -e "    ${WHITE}0)${NC} Cancel"
    echo ""
    read -p "  Select [0-4]: " appimage_choice

    case "$appimage_choice" in
        1) _download_helium ;;
        2) _download_capacities ;;
        3) _download_affinity_installer ;;
        4)
            # All three downloads in parallel
            _download_helium &
            local pid1=$!
            _download_capacities &
            local pid2=$!
            _download_affinity_installer &
            local pid3=$!
            wait "$pid1" || true
            wait "$pid2" || true
            wait "$pid3" || true
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

# ── helper: Helium Browser ─────────────────────────────────────────────
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

    echo "  Downloading: $filename"
    if curl -L --progress-bar "$download_url" -o "$dest"; then
        chmod +x "$dest"
        print_success "Helium Browser saved to $dest"
    else
        print_error "Download failed for Helium Browser"
        rm -f "$dest"
    fi
}

# ── helper: Capacities ────────────────────────────────────────────────
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

    echo "  Downloading: $filename"
    if curl -L --progress-bar "$download_url" -o "$dest"; then
        chmod +x "$dest"
        print_success "Capacities saved to $dest"
    else
        print_error "Download failed for Capacities"
        rm -f "$dest"
    fi
}

# ── helper: Linux Affinity Installer (pinned v3.0.2) ──────────────────
_download_affinity_installer() {
    print_section "Downloading Linux Affinity Installer v3.0.2..."

    local download_url="https://github.com/ryzendew/Linux-Affinity-Installer/releases/download/3.0.2/Linux-Affinity-Installer-3.0.2.AppImage"
    local filename="Linux-Affinity-Installer-3.0.2.AppImage"
    local dest="$APPIMAGE_DIR/$filename"

    if [[ -f "$dest" ]]; then
        print_warning "Already downloaded: $filename"
        return
    fi

    echo "  Downloading: $filename"
    if curl -L --progress-bar "$download_url" -o "$dest"; then
        chmod +x "$dest"
        print_success "Linux Affinity Installer saved to $dest"
        echo -e "  ${CYAN}Run it with: ${WHITE}$dest${NC}"
        echo -e "  ${YELLOW}Note: Requires Wine/Proton to be configured. The installer will guide you.${NC}"
    else
        print_warning "Direct download failed — trying GitHub API for asset URL..."
        local api_url="https://api.github.com/repos/ryzendew/Linux-Affinity-Installer/releases/tags/3.0.2"
        local resolved_url
        resolved_url=$(curl -sf "$api_url" \
            | grep -oP '"browser_download_url":\s*"\K[^"]+' \
            | grep -i "\.AppImage$" \
            | head -1) || true

        if [[ -n "$resolved_url" ]]; then
            filename=$(basename "$resolved_url")
            dest="$APPIMAGE_DIR/$filename"
            if curl -L --progress-bar "$resolved_url" -o "$dest"; then
                chmod +x "$dest"
                print_success "Linux Affinity Installer saved to $dest"
            else
                print_error "Download failed for Linux Affinity Installer"
                rm -f "$dest"
            fi
        else
            print_error "Could not find AppImage asset for v3.0.2. Visit:"
            echo -e "  ${CYAN}https://github.com/ryzendew/Linux-Affinity-Installer/releases/tag/3.0.2${NC}"
            rm -f "$dest"
        fi
    fi
}

#===========================================
# CLAMAV ANTIVIRUS
#===========================================

install_clamav() {
    print_header "Installing & Configuring ClamAV Antivirus"

    # ── 1. Install packages ────────────────────────────────────────────
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

    # Verify clamscan is accessible
    if ! command -v clamscan &>/dev/null; then
        print_error "clamscan not found after install — aborting ClamAV setup"
        return 1
    fi
    print_success "ClamAV version: $(clamscan --version 2>/dev/null | head -1)"

    # ── 2. Prepare clamd@scan config ──────────────────────────────────
    # On Fedora, the package ships scan.conf as scan.conf.sample.
    # systemd clamd@scan.service requires /etc/clamd.d/scan.conf to exist.
    print_section "Preparing clamd scan configuration..."
    local _clamd_conf="/etc/clamd.d/scan.conf"
    local _clamd_sample="/etc/clamd.d/scan.conf.sample"

    if [[ ! -f "$_clamd_conf" ]]; then
        if [[ -f "$_clamd_sample" ]]; then
            sudo cp "$_clamd_sample" "$_clamd_conf"
            print_success "Created $_clamd_conf from sample"
        else
            # Generate a minimal working config if neither file exists
            sudo mkdir -p /etc/clamd.d
            sudo tee "$_clamd_conf" > /dev/null << 'CLAMD_CONF'
# ClamAV clamd@scan config — written by setuplinux.sh
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

    # Ensure the socket directory exists with correct ownership
    sudo mkdir -p /run/clamd.scan
    sudo chown clamscan:clamscan /run/clamd.scan 2>/dev/null || true
    sudo chmod 750 /run/clamd.scan 2>/dev/null || true

    # ── 3. Update virus database ───────────────────────────────────────
    # Stop both clamav-freshclam AND clamd before updating — both lock
    # /var/lib/clamav and will cause freshclam to fail if running.
    print_section "Updating virus database..."
    sudo systemctl stop clamav-freshclam 2>/dev/null || true
    sudo systemctl stop clamd@scan       2>/dev/null || true
    sleep 1

    if sudo freshclam --datadir=/var/lib/clamav 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Virus database updated"
    else
        print_warning "freshclam had warnings — may just be a rate-limit; continuing"
    fi

    # ── 4. Enable clamav-freshclam auto-updater ────────────────────────
    print_section "Enabling clamav-freshclam (daily auto-update)..."
    sudo systemctl enable clamav-freshclam --now 2>&1 | tee -a "$LOG_FILE" || \
        print_warning "clamav-freshclam failed to start — check: journalctl -u clamav-freshclam"
    print_success "clamav-freshclam enabled"

    # ── 5. Enable clamd@scan daemon ───────────────────────────────────
    # The virusgroup group is created by the clamav package.
    # We add the user so they can use clamdscan without sudo.
    print_section "Enabling clamd@scan daemon..."
    if getent group virusgroup &>/dev/null; then
        sudo gpasswd -a "${USER}" virusgroup 2>/dev/null \
            && print_success "Added ${USER} to virusgroup" \
            || print_warning "Could not add ${USER} to virusgroup"
    else
        print_warning "virusgroup not found — skipping group add (log out/in not needed)"
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

    # ── 6. Create quarantine directory ────────────────────────────────
    local quarantine_dir="$HOME/clamav-quarantine"
    mkdir -p "$quarantine_dir"
    print_success "Quarantine directory: $quarantine_dir"

    # ── 7. Scheduled daily scan via cron ──────────────────────────────
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

    # ── 8. Desktop notification script ────────────────────────────────
    echo ""
    read -p "  Install desktop threat-notification script? [y/N]: " setup_notify
    if [[ "$setup_notify" =~ ^[Yy]$ ]]; then
        local notify_script="/usr/local/bin/clamav-notify.sh"
        sudo tee "$notify_script" > /dev/null << 'NOTIFY_EOF'
#!/bin/bash
# ClamAV desktop notification — runs every 5 min via cron
LOGFILE="/var/log/clamd.scan"
LASTCHECK="/var/tmp/clamav-notify-lastcheck"
[[ ! -f "$LASTCHECK" ]] && touch "$LASTCHECK"
NEW_THREATS=$(find "$LOGFILE" -newer "$LASTCHECK" -exec grep -i "FOUND" {} \; 2>/dev/null)
if [[ -n "$NEW_THREATS" ]]; then
    DISPLAY=:0 notify-send -u critical "ClamAV Alert" \
        "Malware detected! Check /var/log/clamd.scan for details."
fi
touch "$LASTCHECK"
NOTIFY_EOF
        sudo chmod +x "$notify_script"

        if crontab -l 2>/dev/null | grep -qF "clamav-notify"; then
            print_warning "Notification cron job already exists — skipping"
        else
            ( crontab -l 2>/dev/null; echo "*/5 * * * * $notify_script" ) | crontab -
            print_success "Threat notification script installed (checks every 5 min)"
        fi
    fi

    # ── 9. Optional: ClamTk GUI ───────────────────────────────────────
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

    # ── 10. Summary ───────────────────────────────────────────────────
    echo ""
    print_success "ClamAV setup complete!"
    echo -e "  ${CYAN}Manual scan:${NC}      sudo clamscan -r -i /home/"
    echo -e "  ${CYAN}Quick scan:${NC}       sudo clamscan -r -i --no-summary /home/"
    echo -e "  ${CYAN}Daemon scan:${NC}      sudo clamdscan -r -i /home/"
    echo -e "  ${CYAN}Quarantine dir:${NC}   $quarantine_dir"
    echo -e "  ${CYAN}DB update logs:${NC}   sudo journalctl -u clamav-freshclam"
    echo -e "  ${CYAN}Daemon logs:${NC}      sudo journalctl -u clamd@scan"
    [[ "$setup_cron" =~ ^[Yy]$ ]] && \
        echo -e "  ${YELLOW}Note: Log out & back in for virusgroup membership to take effect.${NC}"
}

#===========================================
# LINUX SECURITY HARDENING (Chris Titus)
# Covers the 3 biggest Linux security mistakes:
#   1) No firewall / brute-force protection (firewalld + fail2ban)
#   2) SELinux not enforcing (mandatory access control)
#   3) Blindly trusting too many repos / GPG keys
# Plus: sysctl kernel/network hardening
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

    # Bail out on cancel or empty
    if [[ -z "$harden_input" || "$harden_input" == "0" ]]; then
        print_warning "Cancelled"
        return
    fi

    # Expand "5" → all individual steps
    if echo " $harden_input " | grep -q " 5 \| 5$\|^5 \|^5$"; then
        harden_input="1 2 3 4"
    fi

    # Helper: returns 0 if step $1 was selected
    _step_selected() { echo " $harden_input " | grep -qw "$1"; }

    local applied=()

    # ══════════════════════════════════════════════════════════════════
    # STEP 1 — Firewall + Fail2ban
    # ══════════════════════════════════════════════════════════════════
    if _step_selected 1; then
        print_section "Step 1: Firewall (firewalld) + Fail2ban"

        echo "  Enabling firewalld..."
        sudo systemctl enable firewalld --now
        # Wait for firewalld to be fully ready before issuing commands
        sleep 2

        # --set-default-zone is standalone — cannot be paired with --permanent
        sudo firewall-cmd --set-default-zone=public

        echo "  Configuring firewalld rules..."
        sudo firewall-cmd --permanent --add-service=ssh   2>/dev/null || true
        sudo firewall-cmd --permanent --add-service=http  2>/dev/null || true
        sudo firewall-cmd --permanent --add-service=https 2>/dev/null || true

        # SSH rate-limit: max 10 new connections/min (mirrors `ufw limit 22/tcp`)
        # Remove existing rule first to avoid duplicates on re-runs
        sudo firewall-cmd --permanent \
            --remove-rich-rule='rule service name="ssh" limit value="10/m" accept' 2>/dev/null || true
        sudo firewall-cmd --permanent \
            --add-rich-rule='rule service name="ssh" limit value="10/m" accept' 2>/dev/null || true

        sudo firewall-cmd --reload
        print_success "firewalld enabled — SSH rate-limited, HTTP/HTTPS open, all else blocked"

        echo ""
        echo "  Installing fail2ban..."
        if ! rpm -q fail2ban &>/dev/null; then
            sudo dnf install -y fail2ban fail2ban-firewalld 2>&1 | tee -a "$LOG_FILE" || true
            local _f2b_rc=${PIPESTATUS[0]}
            [[ $_f2b_rc -ne 0 ]] && print_error "fail2ban install failed (exit $_f2b_rc)"
        else
            print_warning "fail2ban already installed"
        fi

        sudo tee /etc/fail2ban/jail.local > /dev/null << 'F2B_EOF'
[DEFAULT]
# Ban duration: 1 hour; find window: 10 min; max retries: 5
bantime  = 3600
findtime = 600
maxretry = 5
# Use firewalld instead of raw iptables on Fedora
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
        print_success "fail2ban enabled — SSH: 3 retries → 2 hr ban; default: 5 retries → 1 hr ban"
        applied+=("firewalld + fail2ban")
    fi

    # ══════════════════════════════════════════════════════════════════
    # STEP 2 — SELinux Enforcing
    # ══════════════════════════════════════════════════════════════════
    if _step_selected 2; then
        print_section "Step 2: SELinux Enforcing Mode"

        local selinux_status
        selinux_status=$(getenforce 2>/dev/null || echo "Unknown")
        echo "  Current SELinux state: ${selinux_status}"

        if [[ "$selinux_status" == "Enforcing" ]]; then
            print_success "SELinux is already Enforcing — no change needed"
        else
            if [[ "$selinux_status" == "Permissive" ]]; then
                echo "  SELinux is Permissive (logs but does not block). Setting to Enforcing..."
                sudo setenforce 1 2>/dev/null \
                    || print_warning "Could not set Enforcing at runtime (container?)"
            elif [[ "$selinux_status" == "Disabled" ]]; then
                echo -e "  ${YELLOW}SELinux is fully Disabled. A config edit + reboot is required.${NC}"
            fi

            if [[ -f /etc/selinux/config ]]; then
                sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
                print_success "SELinux set to 'enforcing' in /etc/selinux/config (effective after reboot)"
            fi

            if [[ "$selinux_status" == "Disabled" ]]; then
                sudo touch /.autorelabel
                print_warning "Filesystem relabel scheduled — next boot will relabel (takes a few minutes)"
            fi
        fi
        applied+=("SELinux enforcing")
    fi

    # ══════════════════════════════════════════════════════════════════
    # STEP 3 — Repository & GPG Key Audit
    # ══════════════════════════════════════════════════════════════════
    if _step_selected 3; then
        print_section "Step 3: Repository & GPG Key Audit"

        echo ""
        echo -e "  ${CYAN}Enabled DNF repositories:${NC}"
        echo "  ─────────────────────────────────────────────────────────"
        sudo dnf repolist enabled 2>/dev/null \
            | awk 'NR>1 {printf "    %-40s %s\n", $1, $NF}' || true
        echo "  ─────────────────────────────────────────────────────────"

        local repo_count
        repo_count=$(sudo dnf repolist enabled 2>/dev/null | tail -n +2 | wc -l)
        echo -e "\n  ${WHITE}Total enabled repos: ${repo_count}${NC}"

        if [[ $repo_count -gt 6 ]]; then
            echo -e "  ${YELLOW}⚠  ${repo_count} repos detected. Chris Titus recommends keeping only"
            echo -e "     fedora, updates, and RPM Fusion. Extra repos can silently override"
            echo -e "     base packages and introduce supply-chain risks.${NC}"
        else
            print_success "Repo count looks reasonable (${repo_count})"
        fi

        echo ""
        echo -e "  ${CYAN}Imported GPG keys:${NC}"
        rpm -qa gpg-pubkey --qf "    %{summary}\n" 2>/dev/null | sort || true
        echo ""
        echo -e "  ${YELLOW}Tip: Remove untrusted keys with: ${WHITE}sudo rpm -e gpg-pubkey-<ID>${NC}"
        echo ""

        read -rp "  Open /etc/yum.repos.d/ for manual review? [y/N]: " open_repos
        if [[ "$open_repos" =~ ^[Yy]$ ]]; then
            if command -v xdg-open &>/dev/null; then
                xdg-open /etc/yum.repos.d/ 2>/dev/null || ls -la /etc/yum.repos.d/
            else
                ls -la /etc/yum.repos.d/
            fi
        fi
        applied+=("repo/GPG audit")
    fi

    # ══════════════════════════════════════════════════════════════════
    # STEP 4 — sysctl Kernel & Network Hardening
    # ══════════════════════════════════════════════════════════════════
    if _step_selected 4; then
        print_section "Step 4: sysctl Kernel & Network Hardening"
        echo -e "  ${CYAN}Writing /etc/sysctl.d/99-hardening.conf...${NC}"

        sudo tee /etc/sysctl.d/99-hardening.conf > /dev/null << 'SYSCTL_EOF'
# ── ChrisTitusTech / secure-linux kernel hardening ───────────────────

# Prevent IP spoofing (reverse path filter)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# SYN flood / SYN cookie protection
net.ipv4.tcp_syncookies = 1

# Disable ICMP redirect acceptance (prevents MITM route injection)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Do not send ICMP redirects (we are not a router)
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Ignore ICMP broadcast requests (Smurf attack mitigation)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP error responses
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Do not accept source-routed packets
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Log packets with impossible source addresses (martians)
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# TCP time-wait assassination protection (RFC 1337)
net.ipv4.tcp_rfc1337 = 1

# Address space layout randomisation — full randomisation
kernel.randomize_va_space = 2

# Restrict kernel pointer exposure to root only
kernel.kptr_restrict = 1

# Restrict kernel log access to root only
kernel.dmesg_restrict = 1

# Disable magic SysRq key (reduces physical attack surface)
kernel.sysrq = 0
SYSCTL_EOF

        sudo tee /etc/host.conf > /dev/null << 'HOSTCONF_EOF'
order bind,hosts
multi on
HOSTCONF_EOF

        sudo sysctl --system &>/dev/null
        print_success "sysctl hardening applied and active (persisted in /etc/sysctl.d/99-hardening.conf)"
        applied+=("sysctl hardening")
    fi

    # ══════════════════════════════════════════════════════════════════
    # Summary — only show steps that were actually run
    # ══════════════════════════════════════════════════════════════════
    echo ""
    if [[ ${#applied[@]} -eq 0 ]]; then
        print_warning "No valid steps were selected."
        return
    fi

    print_success "Hardening complete! Applied: ${applied[*]}"
    echo ""
    echo -e "  ${YELLOW}Useful commands:${NC}"
    _step_selected 1 && echo -e "    ${WHITE}sudo fail2ban-client status sshd${NC}   — view SSH bans" || true
    _step_selected 1 && echo -e "    ${WHITE}sudo firewall-cmd --list-all${NC}       — show active firewall rules" || true
    _step_selected 2 && echo -e "    ${WHITE}getenforce${NC}                         — confirm SELinux state" || true
    _step_selected 4 && echo -e "    ${WHITE}sudo sysctl -a | grep rp_filter${NC}    — verify network hardening" || true
    echo ""
    echo -e "  ${YELLOW}A reboot is recommended to ensure all changes are fully active.${NC}"
}

#===========================================
# JSHIELDER — FULL SYSTEM HARDENING (KDE)
# Based on JShielder by Jason Soto @JsiTech
# https://github.com/Jsitech/JShielder
# Fedora KDE Edition — integrated for non-root sudo execution
#===========================================

# ── JShielder internal helpers (mapped to setup.sh style) ────────────────────
_js_info()  { echo -e "${CYAN}  [*]${NC} $*"; log "JSHIELDER INFO: $*"; }
_js_ok()    { print_success "$*"; log "JSHIELDER OK: $*"; }
_js_warn()  { print_warning "$*"; log "JSHIELDER WARN: $*"; }
_js_err()   { print_error "$*";   log "JSHIELDER ERR: $*"; }
_js_pause() {
    echo
    read -rp "  Press ENTER to continue (or type 'x' to skip this step): " _js_ans
    [[ "${_js_ans,,}" == "x" ]] && return 1 || return 0
}

# Backup a file before modifying (sudo-safe)
_js_backup() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local dest="${JSHIELDER_BACKUP_DIR}$(dirname "$file")"
        sudo mkdir -p "$dest"
        sudo cp -p "$file" "$dest/" && log "JSHIELDER BACKUP: $file → $dest/" || true
    fi
}

# ── Write a file to a system path via sudo tee ───────────────────────────────
# Usage: _js_tee /path/to/dest << 'EOF' ... EOF
_js_tee() { sudo tee "$1" > /dev/null; }

# =============================================================================
# JS-1  Install Security Tools
# =============================================================================
_js_install_tools() {
    print_section "JShielder Step 1/14: Installing Security Tools"

    _js_info "Enabling EPEL repository..."
    if ! sudo dnf repolist enabled 2>/dev/null | grep -qi epel; then
        sudo dnf install -y epel-release &>>"$LOG_FILE" \
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
        if sudo dnf install -y "$pkg" &>>"$LOG_FILE"; then
            _js_ok "Installed: $pkg"
        else
            _js_warn "Could not install: $pkg (skipping)"
        fi
    done
}

# =============================================================================
# JS-2  Hostname
# =============================================================================
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

# =============================================================================
# JS-3  Create Admin User + SSH Key
# =============================================================================
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
        _js_ok "User '$_js_au' created and added to wheel (sudo) group."
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

# =============================================================================
# JS-4  SSH Hardening
# =============================================================================
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

# CIS Benchmark cipher suite
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
        _js_info "Updating SELinux + firewalld for SSH port ${_js_port}..."
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

# =============================================================================
# JS-5  Kernel Hardening (sysctl) — extends setup.sh Step 4 with more params
# =============================================================================
_js_harden_kernel() {
    print_section "JShielder Step 5/14: Extended Kernel Hardening (sysctl)"
    _js_backup "/etc/sysctl.d/99-hardening.conf"

    sudo tee /etc/sysctl.d/99-jshielder.conf > /dev/null << 'SYSCTL_JS'
# JShielder Fedora KDE — Extended Kernel Hardening
# Supplements 99-hardening.conf (Chris Titus) with additional CIS params

# TCP hardening
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
net.ipv4.tcp_fin_timeout = 15

# Disable IPv6 router advertisements
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# Disable IP forwarding (not a router)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Exploitation mitigations
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
kernel.perf_event_paranoid = 3
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
fs.suid_dumpable = 0

# Filesystem hardening
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_regular = 2
fs.protected_fifos = 2
SYSCTL_JS

    sudo sysctl --system &>/dev/null
    _js_ok "Extended kernel parameters applied (99-jshielder.conf)."
}

# =============================================================================
# JS-6  Disable Unused Filesystems & Protocols
# =============================================================================
_js_disable_unused() {
    print_section "JShielder Step 6/14: Disable Unused Filesystems & Protocols"

    sudo tee /etc/modprobe.d/jshielder-blacklist.conf > /dev/null << 'MODPROBE'
# JShielder — Blacklisted Kernel Modules
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
    _js_warn "vfat and bluetooth NOT blacklisted here — KDE step handles bluetooth separately."
}

# =============================================================================
# JS-7  Account Policy & UMASK
# =============================================================================
_js_account_policy() {
    print_section "JShielder Step 7/14: Account Policy & Password Hardening"

    # UMASK
    _js_backup "/etc/profile"
    grep -q "umask 027" /etc/profile || echo "umask 027" | sudo tee -a /etc/profile > /dev/null
    grep -q "umask 027" /etc/bashrc  || echo "umask 027" | sudo tee -a /etc/bashrc  > /dev/null
    _js_ok "UMASK set to 027 in /etc/profile and /etc/bashrc."

    # Password quality
    _js_backup "/etc/security/pwquality.conf"
    sudo tee /etc/security/pwquality.conf > /dev/null << 'PWQUAL'
# JShielder — Password Quality Policy
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

    # Login aging
    _js_backup "/etc/login.defs"
    sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/'  /etc/login.defs
    sudo sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   7/'   /etc/login.defs
    sudo sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/'  /etc/login.defs
    sudo sed -i 's/^UMASK.*/UMASK           027/'          /etc/login.defs
    _js_ok "Password aging: max 90d, min 7d, warn 14d."

    # faillock (PAM account lockout)
    _js_backup "/etc/security/faillock.conf"
    sudo tee /etc/security/faillock.conf > /dev/null << 'FLOCK'
# JShielder — faillock account lockout
deny = 5
fail_interval = 900
unlock_time = 900
silent
audit
even_deny_root
FLOCK
    _js_ok "Account lockout: 5 failures → 15-min lockout (even for root)."
}

# =============================================================================
# JS-8  Auditd (CIS Benchmark rules)
# =============================================================================
_js_auditd() {
    print_section "JShielder Step 8/14: Auditd — CIS Benchmark Rules"
    _js_backup "/etc/audit/auditd.conf"

    sudo sed -i 's/^max_log_file_action.*/max_log_file_action = ROTATE/' /etc/audit/auditd.conf
    sudo sed -i 's/^num_logs.*/num_logs = 10/'                           /etc/audit/auditd.conf
    sudo sed -i 's/^max_log_file .*/max_log_file = 50/'                  /etc/audit/auditd.conf

    sudo tee /etc/audit/rules.d/jshielder.rules > /dev/null << 'AUDITRULES'
# JShielder — Audit Rules (CIS Benchmark)
-D
-b 8192
-f 2

# Date/time changes
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# User/group management
-w /etc/group  -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow  -p wa -k identity

# Network config
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
-w /etc/hosts         -p wa -k system-locale
-w /etc/NetworkManager -p wa -k system-locale
-w /etc/issue         -p wa -k system-locale
-w /etc/issue.net     -p wa -k system-locale

# SELinux policy
-w /etc/selinux/ -p wa -k MAC-policy

# Login/logout
-w /var/log/lastlog   -p wa -k logins
-w /var/run/faillock/ -p wa -k logins

# Session
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k logins
-w /var/log/btmp -p wa -k logins

# Privilege escalation
-a always,exit -F arch=b64 -S setuid -F auid>=1000 -F auid!=4294967295 -k priv_esc
-a always,exit -F arch=b32 -S setuid -F auid>=1000 -F auid!=4294967295 -k priv_esc

# Permission changes
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod

# Unsuccessful file access
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM  -F auid>=1000 -F auid!=4294967295 -k access

# Mounts
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts

# Sudo/sudoers changes
-w /etc/sudoers   -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope
-a always,exit -F arch=b64 -C euid!=uid -F euid=0 -F auid>=1000 -F auid!=4294967295 -S execve -k actions

# Module load/unload
-w /sbin/insmod  -p x -k modules
-w /sbin/rmmod   -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules

# Immutable — MUST be last
-e 2
AUDITRULES

    sudo augenrules --load 2>>"$LOG_FILE" \
        || sudo auditctl -R /etc/audit/rules.d/jshielder.rules 2>>"$LOG_FILE" \
        || _js_warn "augenrules/auditctl failed; rules will load on next reboot."
    sudo systemctl enable --now auditd \
        && _js_ok "Auditd enabled and running with CIS rules." \
        || _js_warn "Auditd failed to start — check journalctl -u auditd"
}

# =============================================================================
# JS-9  SELinux (defer to setup.sh option 15 step 2, but enforce here too)
# =============================================================================
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
                && _js_warn "Filesystem relabel scheduled — next boot may take a few minutes."
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

# =============================================================================
# JS-10  RKHunter & AIDE
# =============================================================================
_js_ids() {
    print_section "JShielder Step 10/14: RKHunter & AIDE File Integrity"

    if command -v rkhunter &>/dev/null; then
        _js_info "Updating rkhunter database..."
        sudo rkhunter --update --nocolors 2>>"$LOG_FILE" || _js_warn "rkhunter update failed (network?)."
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
        _js_info "Initializing AIDE database (may take several minutes)..."
        sudo aide --init 2>>"$LOG_FILE" || true
        if sudo test -f /var/lib/aide/aide.db.new.gz; then
            sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
            _js_ok "AIDE database → /var/lib/aide/aide.db.gz"
        elif sudo test -f /var/lib/aide/aide.db.new; then
            sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
            _js_ok "AIDE database → /var/lib/aide/aide.db"
        else
            _js_warn "AIDE init may have failed — check $LOG_FILE"
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

# =============================================================================
# JS-11  Secure Cron
# =============================================================================
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

# =============================================================================
# JS-12  Secure File Permissions
# =============================================================================
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

    _js_info "Logging world-writable files to $LOG_FILE (not auto-fixed)..."
    sudo find / -xdev -type f -perm -0002 2>/dev/null >> "$LOG_FILE" || true
    _js_ok "World-writable file list appended to log."
}

# =============================================================================
# JS-13  Login Banners (MOTD)
# =============================================================================
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
    _js_ok "Login banners configured (/etc/issue, /etc/issue.net, /etc/motd)."
}

# =============================================================================
# JS-14  KDE-Specific Hardening
# =============================================================================
_js_kde_hardening() {
    print_section "JShielder Step 14/14: KDE Plasma Hardening"

    # KWallet — close when idle
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

    # Disable KRFB (KDE VNC remote desktop)
    sudo systemctl disable --now krfb 2>/dev/null \
        && _js_warn "KDE remote desktop (KRFB/VNC) disabled." || true

    # Screen lock policy
    sudo mkdir -p /etc/xdg
    sudo tee /etc/xdg/kscreenlockerrc > /dev/null << 'SCREENLOCK'
[Daemon]
Autolock=true
LockGrace=5
LockOnResume=true
Timeout=5
SCREENLOCK
    _js_ok "KDE screen lock: 5-minute auto-lock, lock on resume."

    # SDDM — disable autologin
    if [[ -f /etc/sddm.conf ]]; then
        _js_backup "/etc/sddm.conf"
        sudo sed -i 's/^User=.*/User=/' /etc/sddm.conf
        sudo sed -i 's/^Session=.*/Session=/' /etc/sddm.conf
        _js_ok "SDDM autologin disabled."
    fi

    # Bluetooth
    read -rp "  Disable Bluetooth? [y/N]: " _js_bt
    if [[ "${_js_bt,,}" == "y" ]]; then
        sudo systemctl disable --now bluetooth 2>/dev/null || true
        echo "install bluetooth /bin/true" \
            | sudo tee -a /etc/modprobe.d/jshielder-blacklist.conf > /dev/null
        _js_ok "Bluetooth disabled."
    fi

    # Baloo file indexer (privacy)
    read -rp "  Disable KDE file indexer (Baloo)? [y/N]: " _js_baloo
    if [[ "${_js_baloo,,}" == "y" ]]; then
        if command -v balooctl &>/dev/null; then
            balooctl disable && _js_ok "Baloo indexing disabled."
        else
            sudo mkdir -p /etc/xdg/KDE
            sudo tee /etc/xdg/baloofilerc > /dev/null << 'BALOO'
[Basic Settings]
Indexing-Enabled=false
BALOO
            _js_ok "Baloo disabled via /etc/xdg/baloofilerc."
        fi
    fi

    # Auto-updates
    if command -v dnf-automatic &>/dev/null || sudo dnf install -y dnf-automatic &>>"$LOG_FILE"; then
        sudo sed -i 's/^upgrade_type.*/upgrade_type = security/'  /etc/dnf/automatic.conf 2>/dev/null || true
        sudo sed -i 's/^apply_updates.*/apply_updates = yes/'     /etc/dnf/automatic.conf 2>/dev/null || true
        sudo systemctl enable --now dnf-automatic-install.timer \
            && _js_ok "Automatic security updates enabled." \
            || _js_warn "dnf-automatic timer failed to start."
    fi

    # Process accounting & sysstat
    sudo systemctl enable --now psacct  2>/dev/null && _js_ok "Process accounting (psacct) enabled." || true
    sudo systemctl enable --now sysstat 2>/dev/null && _js_ok "sysstat enabled." || true
}

# =============================================================================
# MAIN ENTRY — install_jshielder_hardening()
# Called from menu option 16 and install_everything()
# =============================================================================
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
        0)
            print_warning "JShielder cancelled."
            return
            ;;
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
        *)
            print_error "Invalid choice."
            return
            ;;
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
    echo -e "    ${WHITE}sudo ausearch -k perm_mod${NC}        — view audit events"
    echo -e "    ${WHITE}getenforce${NC}                       — confirm SELinux state"
    echo ""
    echo -e "  ${YELLOW}⚠  A REBOOT is recommended to fully apply all changes.${NC}"
}

#===========================================
# GRUB HARDENING + KERNEL LOCKDOWN
# Adds: kernel lockdown mode, CPU exploit
# mitigations, recovery mode disabled,
# optional GRUB superuser password.
#===========================================

install_grub_hardening() {
    print_header "GRUB Hardening + Kernel Lockdown"

    [[ -f /etc/default/grub ]] && sudo cp /etc/default/grub \
        "${JSHIELDER_BACKUP_DIR}/grub.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

    # ── Kernel lockdown=confidentiality ──────────────────────────────
    # Blocks: unsigned kernel modules, /dev/mem reads, hibernation
    # exploits, kprobes, raw BPF writes — even from root.
    print_section "Enabling kernel lockdown=confidentiality..."
    if ! grep -q "lockdown=confidentiality" /etc/default/grub 2>/dev/null; then
        sudo sed -i \
            's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 lockdown=confidentiality"/' \
            /etc/default/grub
        print_success "lockdown=confidentiality added to kernel cmdline."
    else
        print_warning "lockdown=confidentiality already set."
    fi

    # ── CPU mitigations ───────────────────────────────────────────────
    # Forces mitigations for Spectre v1/v2, Spectre v4 (SSBD),
    # L1TF, MDS — disables SMT to fully close MDS side-channels.
    print_section "Enforcing CPU security mitigations (Spectre/Meltdown/MDS)..."
    if ! grep -q "mitigations=auto" /etc/default/grub 2>/dev/null; then
        sudo sed -i \
            's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 mitigations=auto,nosmt spectre_v2=on spec_store_bypass_disable=on l1tf=full,force mds=full,nosmt"/' \
            /etc/default/grub
        print_success "CPU exploit mitigations enforced."
    else
        print_warning "CPU mitigations already configured."
    fi

    # ── Disable recovery mode ─────────────────────────────────────────
    # Recovery entries boot directly to a root shell — no password needed.
    print_section "Disabling GRUB recovery mode entries..."
    if grep -q "^GRUB_DISABLE_RECOVERY" /etc/default/grub 2>/dev/null; then
        sudo sed -i 's/^GRUB_DISABLE_RECOVERY=.*/GRUB_DISABLE_RECOVERY="true"/' /etc/default/grub
    else
        echo 'GRUB_DISABLE_RECOVERY="true"' | sudo tee -a /etc/default/grub > /dev/null
    fi
    print_success "Recovery mode disabled — prevents root shell bypass at boot."

    # ── GRUB superuser password ───────────────────────────────────────
    echo ""
    echo -e "  ${YELLOW}A GRUB password prevents an attacker with physical access from"
    echo -e "  editing boot parameters to strip SELinux or lockdown at boot time.${NC}"
    read -rp "  Set GRUB superuser password? [y/N]: " _grub_pw
    if [[ "${_grub_pw,,}" == "y" ]]; then
        echo -e "  ${CYAN}Enter a strong password for GRUB superuser 'security':${NC}"
        local _grub_hash
        _grub_hash=$(grub2-mkpasswd-pbkdf2 2>/dev/null | grep -o 'grub.pbkdf2.*' || true)
        if [[ -n "$_grub_hash" ]]; then
            sudo tee /etc/grub.d/40_custom_security > /dev/null << GRUBPW
#!/bin/sh
exec tail -n +3 \$0
# JShielder Fedora — GRUB superuser (generated $(date))
set superusers="security"
password_pbkdf2 security ${_grub_hash}
GRUBPW
            sudo chmod 700 /etc/grub.d/40_custom_security
            print_success "GRUB superuser 'security' configured."
            print_warning "Remember this password — required to edit GRUB entries."
        else
            print_error "grub2-mkpasswd-pbkdf2 failed — skipping GRUB password."
        fi
    fi

    # ── Rebuild GRUB ─────────────────────────────────────────────────
    print_section "Rebuilding GRUB configuration..."
    if sudo grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null \
            || sudo grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg 2>/dev/null; then
        print_success "GRUB config rebuilt."
    else
        print_warning "grub2-mkconfig failed — run manually:"
        echo -e "    ${WHITE}sudo grub2-mkconfig -o /boot/grub2/grub.cfg${NC}"
    fi

    echo ""
    print_warning "Reboot required for kernel lockdown and CPU mitigations to activate."
    echo -e "  ${CYAN}After reboot, verify:${NC}"
    echo -e "    ${WHITE}cat /sys/kernel/security/lockdown${NC}"
    echo -e "    ${WHITE}grep . /sys/devices/system/cpu/vulnerabilities/*${NC}"
}

#===========================================
# LYNIS SECURITY AUDIT (standalone)
#===========================================

run_lynis_audit() {
    print_header "Lynis — Full System Security Audit"

    if ! check_command lynis; then
        print_section "Installing Lynis..."
        sudo dnf install -y lynis 2>&1 | tee -a "$LOG_FILE"
    fi

    echo -e "  ${CYAN}Select audit mode:${NC}"
    echo -e "    ${WHITE}1)${NC} Quick scan (warnings/suggestions summary)"
    echo -e "    ${WHITE}2)${NC} Full audit — detailed report (recommended)"
    echo -e "    ${WHITE}3)${NC} Show last saved report"
    echo -e "    ${WHITE}0)${NC} Cancel"
    echo ""
    read -rp "  Choice [2]: " _ly_c; _ly_c="${_ly_c:-2}"

    case "$_ly_c" in
        1)
            sudo lynis audit system --quick --no-colors 2>/dev/null \
                | grep -E "^\[|\bWARNING\b|\bSUGGESTION\b|\bHardening index\b" | head -60
            ;;
        2)
            local _report="$HOME/lynis_report_$(date +%Y%m%d_%H%M%S).txt"
            sudo lynis audit system --no-colors 2>/dev/null | tee "$_report"
            echo ""
            print_success "Full report saved: $_report"
            echo -e "  ${CYAN}Hardening index:${NC}"
            grep -i "hardening index" "$_report" 2>/dev/null || true
            ;;
        3)
            local _last
            _last=$(ls -t "$HOME"/lynis_report_*.txt 2>/dev/null | head -1)
            if [[ -n "$_last" ]]; then
                grep -E "WARNING|SUGGESTION|Hardening index" "$_last" | head -60
                echo -e "  ${CYAN}Full report: $_last${NC}"
            else
                print_warning "No previous report found. Run option 2 first."
            fi
            ;;
        0) return ;;
        *) print_error "Invalid choice" ;;
    esac
}

#===========================================
# DISK ENCRYPTION CHECK + ENCRYPTED SWAP
#===========================================

check_and_setup_encryption() {
    print_header "Disk Encryption Check + Encrypted Swap"

    # ── LUKS check ────────────────────────────────────────────────────
    print_section "Checking LUKS disk encryption status..."
    local _luks_devs
    _luks_devs=$(lsblk -o NAME,TYPE 2>/dev/null | awk '/crypt/{print $1}' || true)

    if [[ -n "$_luks_devs" ]]; then
        print_success "LUKS encryption active: ${_luks_devs}"
    else
        local _dm_devs
        _dm_devs=$(sudo dmsetup ls 2>/dev/null | grep -v "No devices" || true)
        if [[ -n "$_dm_devs" ]]; then
            print_success "Device-mapper (likely LUKS) detected:"
            echo "$_dm_devs" | sed 's/^/    /'
        else
            echo ""
            echo -e "  ${RED}⚠  No LUKS encryption detected on this system.${NC}"
            echo -e "  ${YELLOW}Full disk encryption must be configured during Fedora install."
            echo -e "  Reinstall and choose 'Encrypt my data' on the storage screen.${NC}"
            echo ""
        fi
    fi

    # ── Encrypted swap ────────────────────────────────────────────────
    print_section "Setting up encrypted swap..."
    local _swap_devs
    _swap_devs=$(swapon --show=NAME --noheadings 2>/dev/null || true)

    if [[ -z "$_swap_devs" ]]; then
        print_warning "No active swap found."
        echo -e "    ${WHITE}1)${NC} Create encrypted swap file (2 GB)"
        echo -e "    ${WHITE}2)${NC} Skip"
        read -rp "  Choice [2]: " _sc; _sc="${_sc:-2}"
        if [[ "$_sc" == "1" ]]; then
            print_section "Creating 2 GB encrypted swap file..."
            sudo fallocate -l 2G /swapfile 2>/dev/null \
                || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
            sudo chmod 600 /swapfile
            sudo mkswap /swapfile
            sudo swapon /swapfile
            echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
            print_success "Swap file created and activated."
        fi
    else
        local _swap_part
        _swap_part=$(echo "$_swap_devs" | grep "^/dev/" | head -1 || true)

        if [[ -n "$_swap_part" ]] && ! grep -q "swap.*cipher" /etc/crypttab 2>/dev/null; then
            echo -e "  ${CYAN}Current swap: ${_swap_part}${NC}"
            echo -e "  ${YELLOW}Encrypting swap prevents passwords and keys left in swap"
            echo -e "  from being read after shutdown.${NC}"
            read -rp "  Encrypt swap ${_swap_part} with random key per boot? [y/N]: " _enc_sw
            if [[ "${_enc_sw,,}" == "y" ]]; then
                # Random key per boot — no persistent secret needed for swap
                echo "cryptswap ${_swap_part} /dev/urandom swap,cipher=aes-xts-plain64,size=256,hash=sha256" \
                    | sudo tee -a /etc/crypttab > /dev/null
                sudo sed -i "s|${_swap_part}|/dev/mapper/cryptswap|g" /etc/fstab 2>/dev/null || true
                grep -q "cryptswap" /etc/fstab || \
                    echo "/dev/mapper/cryptswap none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
                sudo dracut --force 2>/dev/null || true
                print_success "Encrypted swap configured (new random key every boot)."
                print_warning "Reboot required to activate."
            fi
        else
            print_success "Swap is already encrypted or inside an encrypted volume."
        fi
    fi

    # ── Hibernation / suspend-to-disk ────────────────────────────────
    print_section "Checking hibernation (suspend-to-disk) status..."
    if grep -rq "resume=" /etc/default/grub 2>/dev/null \
            || grep -rq "resume=" /etc/kernel/cmdline 2>/dev/null; then
        print_warning "Hibernation is enabled — writes RAM (incl. keys) to swap unencrypted."
        read -rp "  Disable hibernation? (recommended unless you need it) [Y/n]: " _hib
        if [[ ! "${_hib,,}" == "n" ]]; then
            sudo sed -i 's/ resume=[^ "]*//g' /etc/default/grub 2>/dev/null || true
            sudo grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null \
                || sudo grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg 2>/dev/null || true
            print_success "Hibernation disabled."
        fi
    else
        print_success "Hibernation not configured — good."
    fi
}

#===========================================
# SYSTEMD SERVICE HARDENING + IMMUTABLE FILES
#===========================================

install_systemd_hardening() {
    print_header "Systemd Service Hardening + Immutable Files"

    # ── Per-service security overrides ───────────────────────────────
    # NoNewPrivileges: service cannot gain extra privileges via setuid
    # PrivateTmp:      service gets its own isolated /tmp
    # ProtectSystem:   /usr and /boot read-only for the service
    # ProtectHome:     service cannot read /home
    print_section "Applying hardened systemd overrides to common services..."
    local services=(sshd crond rsyslog systemd-resolved NetworkManager)
    for svc in "${services[@]}"; do
        if systemctl list-unit-files "${svc}.service" &>/dev/null 2>&1; then
            local _odir="/etc/systemd/system/${svc}.service.d"
            sudo mkdir -p "$_odir"
            sudo tee "${_odir}/hardening.conf" > /dev/null << SVCCONF
[Service]
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=read-only
ProtectSystem=strict
ReadWritePaths=/var/run /var/log /tmp
SVCCONF
            print_success "Hardened: ${svc}.service"
        fi
    done
    sudo systemctl daemon-reload 2>/dev/null || true

    # ── Immutable flag on critical files ─────────────────────────────
    # chattr +i means even root cannot modify without first doing chattr -i.
    # This stops a compromised root process silently editing passwd/shadow.
    print_section "Setting immutable flag on critical system files..."
    local _immutable_files=(
        /etc/passwd
        /etc/shadow
        /etc/group
        /etc/gshadow
        /etc/sudoers
        /etc/ssh/sshd_config
    )
    for f in "${_immutable_files[@]}"; do
        if [[ -f "$f" ]]; then
            sudo chattr +i "$f" 2>/dev/null \
                && print_success "Immutable: $f" \
                || print_warning "chattr +i failed on $f (filesystem may not support it)"
        fi
    done
    echo ""
    print_warning "To edit these files later: sudo chattr -i <file>  (then re-run chattr +i after)"

    # ── Logwatch daily security digest ───────────────────────────────
    print_section "Configuring Logwatch daily security digest..."
    if ! check_command logwatch; then
        sudo dnf install -y logwatch 2>&1 | tee -a "$LOG_FILE"
    fi
    sudo tee /etc/logwatch/conf/logwatch.conf > /dev/null << 'LOGWATCH'
LogDir = /var/log
TmpDir = /var/cache/logwatch
Output = stdout
Format = text
MailTo = root
MailFrom = logwatch
Range = yesterday
Detail = Med
Service = All
LOGWATCH
    sudo tee /etc/cron.daily/00logwatch > /dev/null << 'LOGWATCHCRON'
#!/bin/bash
/usr/sbin/logwatch --output mail --mailto root --detail high 2>/dev/null || true
LOGWATCHCRON
    sudo chmod +x /etc/cron.daily/00logwatch
    print_success "Logwatch daily digest scheduled (results mailed to root)."

    echo ""
    print_warning "Reboot recommended to fully apply systemd sandbox changes."
    echo -e "  ${CYAN}To read security digest:${NC} ${WHITE}sudo logwatch --output stdout --detail high${NC}"
}

#===========================================
# BROWSER PRIVACY HARDENING
# Deploys hardened user.js to Firefox/
# LibreWolf profiles — arkenfox-based.
# Covers: anti-fingerprint, no WebRTC leak,
# no telemetry, HTTPS-only, DoH.
#===========================================

harden_browser_privacy() {
    print_header "Browser Privacy Hardening (Firefox / LibreWolf)"

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
    echo -e "    • Disables search bar keystroke leaking (suggestions off)"
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
// ── JShielder Fedora — Hardened user.js ─────────────────────────────
// Based on arkenfox user.js (https://github.com/arkenfox/user.js)
// Applied by setuplinux.sh — edit cautiously, some sites may break.

// ── Telemetry & data collection ──────────────────────────────────────
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("browser.discovery.enabled", false);
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);
user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);

// ── Fingerprinting resistance ─────────────────────────────────────────
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.resistFingerprinting.block_mozAddonManager", true);
user_pref("webgl.disabled", true);
user_pref("media.peerconnection.enabled", false);
user_pref("media.peerconnection.ice.no_host", true);
user_pref("geo.enabled", false);
user_pref("geo.provider.use_gpsd", false);
user_pref("geo.provider.use_geoclue", false);
user_pref("browser.send_pings", false);
user_pref("dom.battery.enabled", false);
user_pref("dom.gamepad.enabled", false);
user_pref("device.sensors.enabled", false);

// ── Privacy: referrers, cookies, tracking ────────────────────────────
user_pref("network.http.referer.XOriginPolicy", 2);
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);
user_pref("network.http.referer.spoofSource", true);
user_pref("privacy.firstparty.isolate", true);
user_pref("network.cookie.cookieBehavior", 5);
user_pref("network.cookie.lifetimePolicy", 2);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);

// ── HTTPS only ────────────────────────────────────────────────────────
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_pbm", true);

// ── DNS over HTTPS (Quad9) ────────────────────────────────────────────
user_pref("network.trr.mode", 2);
user_pref("network.trr.uri", "https://dns.quad9.net/dns-query");
user_pref("network.trr.custom_uri", "https://dns.quad9.net/dns-query");

// ── Search & URL bar ─────────────────────────────────────────────────
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.urlbar.speculativeConnect.enabled", false);
user_pref("browser.fixup.alternate.enabled", false);

// ── Auto-clear on close ───────────────────────────────────────────────
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("privacy.clearOnShutdown.cache", true);
user_pref("privacy.clearOnShutdown.cookies", false);
user_pref("privacy.clearOnShutdown.downloads", false);
user_pref("privacy.clearOnShutdown.formdata", true);
user_pref("privacy.clearOnShutdown.history", false);
user_pref("privacy.clearOnShutdown.sessions", true);
user_pref("privacy.clearOnShutdown.offlineApps", true);
user_pref("privacy.clearOnShutdown.siteSettings", false);

// ── Safe browsing off (phones home to Google) ────────────────────────
user_pref("browser.safebrowsing.malware.enabled", false);
user_pref("browser.safebrowsing.phishing.enabled", false);
user_pref("browser.safebrowsing.downloads.enabled", false);
user_pref("browser.safebrowsing.provider.google4.updateURL", "");
user_pref("browser.safebrowsing.provider.google4.reportURL", "");

// ── Misc hardening ───────────────────────────────────────────────────
user_pref("dom.event.clipboardevents.enabled", false);
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("extensions.pocket.enabled", false);
user_pref("identity.fxaccounts.enabled", false);
user_pref("browser.uitour.enabled", false);
USERJS
        print_success "Hardened user.js deployed → ${browser_name} profile."
        print_warning "Restart ${browser_name} to apply. Some sites may need per-site exceptions."
    }

    local found=0

    # Helper: scan a base dir and harden all *.default* profile subdirs found
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

    # ── Firefox ───────────────────────────────────────────────────────
    # DNF / native install
    _scan_and_harden "$HOME/.mozilla/firefox" "Firefox"
    # Flatpak install (org.mozilla.firefox)
    _scan_and_harden "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox" "Firefox (Flatpak)"

    # ── LibreWolf ─────────────────────────────────────────────────────
    # Native / COPR install
    _scan_and_harden "$HOME/.librewolf" "LibreWolf"
    # Flatpak install (io.gitlab.librewolf-community)
    _scan_and_harden "$HOME/.var/app/io.gitlab.librewolf-community/.librewolf" "LibreWolf (Flatpak)"

    # ── Zen Browser ───────────────────────────────────────────────────
    # Native install
    _scan_and_harden "$HOME/.zen" "Zen Browser" 2
    # Flatpak install (app.zen_browser.zen)
    _scan_and_harden "$HOME/.var/app/app.zen_browser.zen/.zen" "Zen Browser (Flatpak)" 2

    if [[ $found -eq 0 ]]; then
        print_warning "No browser profiles found (checked native + Flatpak locations)."
        echo -e "  ${CYAN}Launch your browser at least once to create a profile, then re-run.${NC}"
        echo -e "  ${CYAN}Checked paths:${NC}"
        echo -e "    ~/.mozilla/firefox                              (Firefox DNF)"
        echo -e "    ~/.var/app/org.mozilla.firefox/                 (Firefox Flatpak)"
        echo -e "    ~/.librewolf                                    (LibreWolf native)"
        echo -e "    ~/.var/app/io.gitlab.librewolf-community/       (LibreWolf Flatpak)"
        echo -e "    ~/.zen                                          (Zen Browser native)"
        echo -e "    ~/.var/app/app.zen_browser.zen/                 (Zen Browser Flatpak)"
    else
        print_success "Hardened $found profile(s) across Firefox / LibreWolf / Zen Browser."
    fi
}

#===========================================
# HACKING TOOLS — Kali Linux Toolkit
# Installs tools from the Kali Linux rolling
# repo, pinned LOW priority so Kali packages
# NEVER override Fedora system packages.
# For legal security research / pentest / CTF.
#===========================================

# ── Helpers ───────────────────────────────────────────────────────────
_hk_ok()     { echo -e "${GREEN}  ✓${NC} $*"; }
_hk_warn()   { echo -e "${YELLOW}  !${NC} $*"; }
_hk_err()    { echo -e "${RED}  ✗${NC} $*"; }
_hk_info()   { echo -e "${CYAN}  ›${NC} $*"; }
_hk_header() { echo -e "\n${RED}━━  $*  ━━${NC}\n"; }
_hk_sep()    { echo -e "  ──────────────────────────────────────────────${NC}"; }

# ── Add Kali repo (DNF / Fedora) ─────────────────────────────────────
# Kali publishes an RPM repo usable on any Fedora/RHEL base.
# Priority=200 keeps it well below Fedora's default (~99).
# Tools are ONLY installed when explicitly requested.
_hk_add_kali_repo() {
    if [[ -f /etc/yum.repos.d/kali-tools.repo ]]; then
        _hk_info "Kali repo already configured."
        return 0
    fi

    _hk_info "Adding Kali Linux rolling repository for Fedora (RPM)..."

    sudo tee /etc/yum.repos.d/kali-tools.repo > /dev/null << 'KALIREPO'
[kali-tools]
name=Kali Linux Tools (Fedora)
baseurl=https://http.kali.org/kali/dists/kali-rolling/main/binary-amd64/
# Note: Kali does not ship native RPMs for all tools.
# This repo is a placeholder — many tools are installed via pip/go/cargo/git.
enabled=0
gpgcheck=0
priority=200
KALIREPO

    _hk_warn "Note: Kali does not publish a full native RPM repo."
    _hk_info "Tools are installed via DNF (EPEL/Fedora repos), pip, go, cargo, and git."
    _hk_info "This matches how Kali tools work on non-Debian distros."
}

# ── Install list with pass/fail report ───────────────────────────────
_hk_install_pkgs() {
    local category="$1"; shift
    local pkgs=("$@")
    local installed=0 failed=0

    _hk_info "Installing ${#pkgs[@]} packages for: ${category}"
    echo ""

    for pkg in "${pkgs[@]}"; do
        if rpm -q "$pkg" &>/dev/null 2>&1; then
            echo -e "  ${YELLOW}already installed:${NC} $pkg"
            installed=$((installed+1))
        elif sudo dnf install -y "$pkg" &>>"$LOG_FILE" 2>&1; then
            echo -e "  ${GREEN}✓${NC} $pkg"
            installed=$((installed+1))
        else
            echo -e "  ${RED}✗${NC} $pkg (not in repos — may need manual install)${NC}"
            failed=$((failed+1))
        fi
    done

    echo ""
    _hk_sep
    echo -e "  ${GREEN}Installed/present: ${installed}${NC}   ${RED}Not found: ${failed}${NC}"
    _hk_sep
    [[ $failed -gt 0 ]] && _hk_warn "Some tools not in DNF repos — check $LOG_FILE for details."
}

# =============================================================================
# CATEGORY FUNCTIONS — matching Kali Linux menu organisation
# =============================================================================

_hk_cat_information_gathering() {
    _hk_header "Information Gathering"
    echo -e "  Network recon, DNS enumeration, OSINT, port scanning, fingerprinting${NC}"
    echo ""
    local pkgs=(
        nmap              # Industry-standard port/service scanner
        masscan           # Fastest internet-scale port scanner
        netdiscover       # ARP-based LAN host discovery
        arp-scan          # ARP scanner
        fping             # Parallel ICMP ping sweep
        hping3            # Packet crafting and TCP/IP testing
        whois             # WHOIS domain lookup
        bind-utils        # dig, nslookup, host
        dnsenum           # DNS enumeration and zone transfer
        dnsrecon          # DNS recon and brute-force
        fierce            # DNS scanner / subdomain finder
        theHarvester      # OSINT email/domain/host harvesting
        recon-ng          # Web reconnaissance framework
        dmitry            # Information gathering tool
        enum4linux        # SMB/NetBIOS enumeration
        smbclient         # SMB share enumeration
        nbtscan           # NetBIOS name scanner
        onesixtyone       # SNMP scanner
        snmpcheck         # SNMP enumeration tool
        p0f               # Passive OS fingerprinting
        nikto             # Web server vulnerability scanner
        whatweb           # Web technology fingerprinting
        wafw00f           # WAF detection tool
        gobuster          # Dir/DNS/vhost brute-forcer
        ffuf              # Fast web fuzzer
        dirb              # Web content scanner
        eyewitness        # Web app screenshotter
        spiderfoot        # Automated OSINT framework
        subfinder         # Subdomain discovery
    )
    _hk_install_pkgs "Information Gathering" "${pkgs[@]}"
}

_hk_cat_vulnerability_analysis() {
    _hk_header "Vulnerability Analysis"
    echo -e "  Scanners, fuzzers, CVE detection${NC}"
    echo ""
    local pkgs=(
        openvas-scanner   # OpenVAS vulnerability scanner daemon
        gvm               # Greenbone Vulnerability Manager
        nikto             # Web server scanner
        wapiti            # Web application vulnerability scanner
        zaproxy           # OWASP ZAP web proxy/scanner
        lynis             # Local system security auditing
        checksec          # Binary security property checker
        binwalk           # Firmware analysis and extraction
        sqlmap            # SQL injection detection/exploitation
        commix            # Command injection exploiter
        sslyze            # TLS/SSL configuration analyser
        sslscan           # TLS/SSL cipher suite scanner
        testssl           # TLS/SSL testing tool
    )
    _hk_install_pkgs "Vulnerability Analysis" "${pkgs[@]}"
}

_hk_cat_web_application() {
    _hk_header "Web Application Hacking"
    echo -e "  SQL injection, XSS, fuzzing, proxies, CMS scanners${NC}"
    echo ""
    local pkgs=(
        burpsuite         # Web proxy / security testing suite
        zaproxy           # OWASP ZAP intercepting proxy
        sqlmap            # Automated SQL injection tool
        commix            # Command injection scanner
        wfuzz             # Web application fuzzer
        ffuf              # Fast web fuzzer (recursive)
        gobuster          # Directory/file/DNS brute-forcer
        dirb              # Web content scanner
        nikto             # Web server scanner
        whatweb           # Web fingerprinting
        wafw00f           # WAF fingerprinting
        wpscan            # WordPress vulnerability scanner
        joomscan          # Joomla vulnerability scanner
        nuclei            # Template-based vulnerability scanner
        httpx             # Fast HTTP toolkit
        arjun             # HTTP parameter discovery
        sublist3r         # Subdomain enumeration
        dirsearch         # Web path discovery tool
    )
    _hk_install_pkgs "Web Application" "${pkgs[@]}"
}

_hk_cat_exploitation() {
    _hk_header "Exploitation Tools"
    echo -e "  Frameworks, exploit helpers, shellcode generation${NC}"
    echo ""
    local pkgs=(
        metasploit        # The Metasploit Framework
        exploitdb         # Exploit Database (searchsploit CLI)
        beef              # Browser Exploitation Framework
        set               # Social Engineering Toolkit
        veil              # AV-evasion payload generator
        shellter          # Dynamic shellcode injection tool
        gdb               # GNU Debugger
        ltrace            # Library call tracer
        strace            # System call tracer
        radare2           # Reverse engineering framework
        ghidra            # NSA reverse engineering / decompiler
        binwalk           # Binary analysis and extraction
        checksec          # Binary hardening checker
        ropper            # ROP gadget finder
        python3-pwntools  # CTF/exploit development library
    )
    _hk_install_pkgs "Exploitation" "${pkgs[@]}"
}

_hk_cat_post_exploitation() {
    _hk_header "Post Exploitation"
    echo -e "  Persistence, lateral movement, AD attacks, privilege escalation${NC}"
    echo ""
    local pkgs=(
        crackmapexec      # Active Directory Swiss Army knife
        evil-winrm        # WinRM shell for pentesting
        impacket          # Python AD/SMB/Kerberos tools
        bloodhound        # AD attack path visualiser
        neo4j             # BloodHound database backend
        pypykatz          # Python Mimikatz port (Linux)
        python3-ldap3     # LDAP library for AD recon
        pspy              # Process monitor (no root needed)
        linux-exploit-suggester  # Linux privesc CVE finder
        linpeas           # Linux privilege escalation script
    )
    _hk_install_pkgs "Post Exploitation" "${pkgs[@]}"
}

_hk_cat_password_attacks() {
    _hk_header "Password Attacks"
    echo -e "  Hash cracking, brute force, wordlist tools${NC}"
    echo ""
    local pkgs=(
        hashcat           # GPU-accelerated password cracker
        john              # John the Ripper password cracker
        hydra             # Network login brute-forcer
        medusa            # Parallel network login auditor
        ncrack            # Network authentication cracker
        wordlists         # Wordlist collection (rockyou etc.)
        crunch            # Custom wordlist generator
        cewl              # Wordlist from website content
        hashid            # Hash type identifier
        hash-identifier   # Hash identifier (alternative)
        fcrackzip         # ZIP password cracker
        pdfcrack          # PDF password cracker
        rarcrack          # RAR/ZIP/7z cracker
    )
    _hk_install_pkgs "Password Attacks" "${pkgs[@]}"
}

_hk_cat_wireless() {
    _hk_header "Wireless Attacks"
    echo -e "  WiFi auditing, Bluetooth, SDR, RFID/NFC${NC}"
    echo ""
    local pkgs=(
        aircrack-ng       # WiFi security auditing suite
        kismet            # Wireless network detector/sniffer
        wifite            # Automated wireless auditor
        hostapd           # WiFi access point daemon (rogue AP)
        dnsmasq           # DHCP/DNS for rogue AP
        bettercap         # Modern MITM and WiFi attack framework
        pixiewps          # WPS pixie dust attack
        reaver            # WPS brute-force tool
        cowpatty          # WPA dictionary attack
        hcxtools          # WiFi capture file converter (hashcat)
        hcxdumptool       # WiFi capture tool
        bluez             # Bluetooth stack and tools
        bluez-tools       # Bluetooth utilities
        gnuradio          # SDR toolkit
        gqrx              # SDR receiver GUI
        rtl-sdr           # RTL-SDR driver and tools
        hackrf            # HackRF SDR tools
        libnfc            # NFC library and tools
    )
    _hk_install_pkgs "Wireless Attacks" "${pkgs[@]}"
}

_hk_cat_sniffing_spoofing() {
    _hk_header "Sniffing & Spoofing"
    echo -e "  Packet capture, MITM, ARP/DNS spoofing, SSL stripping${NC}"
    echo ""
    local pkgs=(
        wireshark         # Network protocol analyser (GUI)
        tshark            # Wireshark CLI
        tcpdump           # Packet capture
        ettercap          # MITM framework
        bettercap         # Modern MITM framework
        dsniff            # Password sniffer suite (arpspoof, etc.)
        mitmproxy         # Interactive SSL-capable MITM proxy
        responder         # LLMNR/NBT-NS/MDNS poisoner
        dnschef           # DNS proxy/forger
        tcpreplay         # Replay captured network traffic
        scapy             # Python packet manipulation library
        yersinia          # Layer 2 protocol attack tool
        netsniff-ng       # Linux network performance toolkit
        p0f               # Passive OS fingerprinting
    )
    _hk_install_pkgs "Sniffing & Spoofing" "${pkgs[@]}"
}

_hk_cat_forensics() {
    _hk_header "Digital Forensics"
    echo -e "  Disk imaging, memory analysis, file carving, artefact analysis${NC}"
    echo ""
    local pkgs=(
        autopsy           # Digital forensics GUI (Sleuth Kit frontend)
        sleuthkit         # The Sleuth Kit CLI tools
        volatility        # Memory forensics framework
        foremost          # File recovery by header/footer
        scalpel           # File carving tool
        photorec          # File recovery
        testdisk          # Partition and boot record recovery
        dc3dd             # Forensic dd with hashing and logging
        dcfldd            # Enhanced dd with hashing
        bulk-extractor    # Bulk data extractor
        binwalk           # Firmware and binary analysis
        exiftool          # Metadata reader/writer
        yara              # Malware pattern matching rules
        ssdeep            # Fuzzy hashing
        hashdeep          # Recursive multi-hash tool
        steghide          # Image steganography
        stegseek          # Fast steghide brute-forcer
        outguess          # Steganography tool
        radare2           # Binary/malware analysis
        strings           # Extract printable strings from binaries
    )
    _hk_install_pkgs "Digital Forensics" "${pkgs[@]}"
}

_hk_cat_reverse_engineering() {
    _hk_header "Reverse Engineering"
    echo -e "  Disassemblers, debuggers, decompilers, binary analysis${NC}"
    echo ""
    local pkgs=(
        ghidra            # NSA decompiler and RE suite
        radare2           # Reverse engineering framework
        cutter            # Radare2 GUI frontend
        gdb               # GNU Debugger
        pwndbg            # GDB plugin for exploit development
        edb               # OllyDbg-style debugger for Linux
        ltrace            # Library call tracer
        strace            # System call tracer
        valgrind          # Memory analysis / dynamic RE
        binwalk           # Firmware extraction
        upx               # UPX packer/unpacker
        apktool           # Android APK reverse engineering
        jadx              # Android APK decompiler (DEX to Java)
        frida             # Dynamic instrumentation toolkit
        python3-frida     # Frida Python bindings
        objdump           # Object file disassembler
        readelf           # ELF file analyser
        checksec          # Binary hardening property checker
        python3-pwntools  # CTF/exploit development library
        ropper            # ROP gadget finder
    )
    _hk_install_pkgs "Reverse Engineering" "${pkgs[@]}"
}

_hk_cat_network_attacks() {
    _hk_header "Network Attacks"
    echo -e "  MITM, tunnelling, pivoting, SMB, Kerberos, proxying${NC}"
    echo ""
    local pkgs=(
        nmap              # Port and service scanner
        masscan           # Fast port scanner
        ncat              # Nmap netcat
        socat             # Socket relay tool
        proxychains-ng    # Route traffic through proxies/Tor
        sshuttle          # Transparent SSH VPN/proxy
        chisel            # Fast TCP/UDP tunneller over HTTP
        iodine            # DNS tunnelling
        ptunnel-ng        # ICMP tunnelling
        httptunnel        # HTTP-based tunnel
        hping3            # Packet crafting tool
        scapy             # Python packet manipulation
        ike-scan          # VPN/IKE fingerprinting
        onesixtyone       # SNMP scanner
        impacket          # SMB/RPC/Kerberos Python tools
        crackmapexec      # SMB/AD attack toolkit
        responder         # NBT-NS/LLMNR/mDNS poisoner
        coercer           # Windows auth coercion tool
    )
    _hk_install_pkgs "Network Attacks" "${pkgs[@]}"
}

_hk_cat_social_engineering() {
    _hk_header "Social Engineering"
    echo -e "  Phishing frameworks, payload delivery, credential harvesting${NC}"
    echo ""
    local pkgs=(
        set               # Social Engineer Toolkit
        beef              # Browser Exploitation Framework
        gophish           # Open-source phishing simulation
        evilginx2         # Phishing / session hijacking proxy
        msfvenom          # Metasploit payload generator
        veil              # AV-evasion payload framework
        shellter          # Shellcode injection tool
        powersploit       # PowerShell post-exploitation
        nishang           # PowerShell offensive scripts
    )
    _hk_install_pkgs "Social Engineering" "${pkgs[@]}"
}

_hk_cat_ctf_tools() {
    _hk_header "CTF & Binary Exploitation"
    echo -e "  CTF frameworks, ROP tools, steganography, cryptography${NC}"
    echo ""
    local pkgs=(
        python3-pwntools  # The CTF exploit dev library
        pwndbg            # GDB plugin for CTF and exploit dev
        gdb               # GNU Debugger
        ropper            # ROP gadget finder
        checksec          # Binary security flags checker
        qemu-system-x86   # x86 system emulation for CTF
        qemu-user-static  # Multi-arch binary execution
        gdb-multiarch     # GDB multi-architecture support
        steghide          # Steganography embed/extract
        stegseek          # Fast steghide brute-forcer
        outguess          # Steganography tool
        exiftool          # Metadata extraction
        foremost          # File carving
        binwalk           # Binary analysis
        hashcat           # Hash cracking
        john              # John the Ripper
        python3-z3        # Z3 SMT solver (crypto CTF)
        python3-gmpy2     # GMP Python bindings (RSA CTF)
        python3-cryptography  # Python crypto library
    )
    _hk_install_pkgs "CTF & Binary Exploitation" "${pkgs[@]}"
}

_hk_cat_cloud_containers() {
    _hk_header "Cloud & Container Security"
    echo -e "  AWS/GCP/Azure, Docker/Kubernetes, secrets scanning${NC}"
    echo ""
    local pkgs=(
        awscli            # AWS CLI
        azure-cli         # Azure CLI
        kubectl           # Kubernetes CLI
        helm              # Kubernetes package manager
        moby-engine       # Docker (Moby engine)
        trivy             # Container/image vulnerability scanner
        grype             # Container vulnerability scanner
        syft              # Software Bill of Materials generator
        falco             # Cloud-native security runtime monitor
        kube-bench        # Kubernetes CIS benchmark tool
        kube-hunter       # Kubernetes penetration testing
        pacu              # AWS exploitation framework
        prowler           # AWS/GCP/Azure security scanner
        gitleaks          # Secret detection in git repositories
        trufflehog        # Credential leak scanner
        nuclei            # Template-based vulnerability scanner
    )
    _hk_install_pkgs "Cloud & Container Security" "${pkgs[@]}"
}

_hk_cat_anonymity() {
    _hk_header "Anonymity & Anti-Forensics"
    echo -e "  Tor, proxy chains, MAC spoofing, trace wiping, encryption${NC}"
    echo ""
    local pkgs=(
        tor               # Tor anonymity network
        torsocks          # Route applications through Tor
        proxychains-ng    # Proxy chaining for anonymity
        macchanger        # MAC address spoofing tool
        bleachbit         # System and browser trace cleaner
        secure-delete     # Secure file deletion (srm/sfill)
        mat2              # Metadata anonymisation tool
        exiftool          # Metadata reader and stripper
        wipe              # Secure file overwrite utility
        scrub             # Disk scrubbing tool
        i2p               # I2P anonymity network
        veracrypt         # On-disk encrypted containers
    )
    _hk_install_pkgs "Anonymity & Anti-Forensics" "${pkgs[@]}"
}

# =============================================================================
# HACKING TOOLS MAIN MENU
# =============================================================================

hacking_tools_menu() {
    _hk_add_kali_repo || true

    while true; do
        clear

        cat << 'HACKBANNER'
    
      💀  HACKING TOOLS — Kali Linux Toolkit on Fedora  💀
      Categories match the official Kali Linux menu
      
      ⚠  FOR LEGAL USE ONLY: authorised penetration testing,
      security research, and CTF challenges only.
      Unauthorised use of these tools is illegal.
      
      
      Individual Categories
      1)  Information Gathering    (nmap, masscan, amass, theHarv.)
      2)  Vulnerability Analysis   (OpenVAS, nikto, sqlmap, sslyze)
      3)  Web Application Hacking  (Burp, ZAP, sqlmap, ffuf, wfuzz)
      4)  Exploitation             (Metasploit, BeEF, SET, radare2)
      5)  Post Exploitation        (CME, BloodHound, pypykatz, pspy)
      6)  Password Attacks         (hashcat, john, hydra, crunch)
      7)  Wireless Attacks         (aircrack, kismet, wifite, SDR)
      8)  Sniffing & Spoofing      (Wireshark, bettercap, Responder)
      9)  Digital Forensics        (Autopsy, Volatility, Sleuth Kit)
      10) Reverse Engineering      (Ghidra, radare2, GDB, frida)
      11) Network Attacks          (tunnels, pivoting, SMB, proxies)
      12) Social Engineering       (SET, GoPhish, Evilginx2, Veil)
      13) CTF & Binary Exploitation (pwntools, ROP, steg, crypto)
      14) Cloud & Container Sec.   (Trivy, Pacu, Prowler, kubectl)
      15) Anonymity & Anti-Forensics (Tor, proxychains, srm, mat2)
      
      Bulk Install
      16) Install ALL categories   (full toolkit — 400+ tools)
      17) Install kali-linux-top10 (top 10 essential tools)
      
      Utilities
      18) Update all hacking tools
      19) Show installed tools summary
      
      0)  Return to main menu
      
HACKBANNER
        echo -e "${NC}"

        read -rp "  Select [0-19]: " _hk_c
        echo ""

        case "$_hk_c" in
            1)  _hk_cat_information_gathering ;;
            2)  _hk_cat_vulnerability_analysis ;;
            3)  _hk_cat_web_application ;;
            4)  _hk_cat_exploitation ;;
            5)  _hk_cat_post_exploitation ;;
            6)  _hk_cat_password_attacks ;;
            7)  _hk_cat_wireless ;;
            8)  _hk_cat_sniffing_spoofing ;;
            9)  _hk_cat_forensics ;;
            10) _hk_cat_reverse_engineering ;;
            11) _hk_cat_network_attacks ;;
            12) _hk_cat_social_engineering ;;
            13) _hk_cat_ctf_tools ;;
            14) _hk_cat_cloud_containers ;;
            15) _hk_cat_anonymity ;;
            16)
                print_header "Installing ALL Hacking Tool Categories"
                echo -e "${RED}This will attempt to install 400+ tools via DNF. Takes a while.${NC}"
                read -p "  Continue? [y/N]: " _hk_all
                if [[ "$_hk_all" =~ ^[Yy]$ ]]; then
                    _hk_cat_information_gathering
                    _hk_cat_vulnerability_analysis
                    _hk_cat_web_application
                    _hk_cat_exploitation
                    _hk_cat_post_exploitation
                    _hk_cat_password_attacks
                    _hk_cat_wireless
                    _hk_cat_sniffing_spoofing
                    _hk_cat_forensics
                    _hk_cat_reverse_engineering
                    _hk_cat_network_attacks
                    _hk_cat_social_engineering
                    _hk_cat_ctf_tools
                    _hk_cat_cloud_containers
                    _hk_cat_anonymity
                    print_success "All categories complete. See $LOG_FILE for failures."
                fi
                ;;
            17)
                print_header "Installing Kali Top-10 Essential Tools"
                _hk_info "Installing the 10 most critical security tools..."
                local _top10=(
                    nmap metasploit sqlmap aircrack-ng
                    john hashcat hydra wireshark nikto gobuster
                )
                for _t in "${_top10[@]}"; do
                    rpm -q "$_t" &>/dev/null \
                        && echo -e "  ${YELLOW}already installed:${NC} $_t" \
                        || { sudo dnf install -y "$_t" &>>"$LOG_FILE" \
                             && echo -e "  ${GREEN}✓${NC} $_t" \
                             || echo -e "  ${RED}✗${NC} $_t"; }
                done
                print_success "Top-10 tools install complete."
                ;;
            18)
                print_header "Updating All Hacking Tools"
                sudo dnf update -y 2>&1 | tee -a "$LOG_FILE"
                print_success "All tools updated."
                ;;
            19)
                print_header "Installed Hacking Tools Summary"
                local _check=(
                    nmap masscan metasploit sqlmap hydra
                    aircrack-ng wireshark hashcat john radare2
                    ghidra gobuster ffuf nikto zaproxy
                    volatility3 bloodhound crackmapexec
                    autopsy binwalk foremost steghide
                    checksec nuclei pwndbg
                )
                echo ""
                local _found=0 _miss=0
                for t in "${_check[@]}"; do
                    if rpm -q "$t" &>/dev/null 2>&1 || check_command "$t" 2>/dev/null; then
                        echo -e "  ${GREEN}✓${NC} $t"
                        _found=$((_found+1))
                    else
                        echo -e "  ${RED}✗${NC} $t"
                        _miss=$((_miss+1))
                    fi
                done
                echo ""
                _hk_sep
                echo -e "  ${GREEN}Installed: ${_found}${NC}  ${RED}Not found: ${_miss}${NC}  (of ${#_check[@]} key tools checked)"
                _hk_sep
                ;;
            0)
                print_success "Returning to main menu."
                return
                ;;
            *)
                print_warning "Invalid choice: ${_hk_c}"
                ;;
        esac

        echo ""
        read -rp "  Press Enter to continue..." _dummy
    done
}

#===========================================
# MAIN MENU
#===========================================

#=============================================================================
# PRIVACY & NETWORK — IP Privacy Manager (integrated from ipprivacy.sh)
# All functions namespaced with _priv_ to avoid conflicts with setup.sh.
# Requires root — the menu wrapper calls all functions via `sudo bash`.
#=============================================================================

# ── Config ───────────────────────────────────────────────────────────────────
_PRIV_BACKUP_DIR="/etc/ip-privacy-backups"
_PRIV_STATE_FILE="/etc/ip-privacy-backups/.state"
_PRIV_TOR_USER=""
_PRIV_TOR_TRANS_PORT=9040
_PRIV_TOR_DNS_PORT=9053
_PRIV_TOR_VIRT_NET="10.192.0.0/10"

# ── Helpers (scoped; reuse setup.sh colours which are identical) ─────────────
_priv_info()   { echo -e "${GREEN}[+]${NC} $*"; }
_priv_warn()   { echo -e "${YELLOW}[!]${NC} $*"; }
_priv_error()  { echo -e "${RED}[x]${NC} $*"; }
_priv_header() { echo ""; echo -e "${CYAN}── $* ──${NC}"; }

_priv_pause() {
    echo ""
    read -rp "${CYAN}Press Enter to return to menu...${NC}" _dummy
}

# ── Utility functions ─────────────────────────────────────────────────────────
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
    echo "  Interface : ${iface:-unknown}${NC}"
    echo "  Local IP  : $(ip -4 addr show "${iface}" 2>/dev/null | awk '/inet / {print $2}')${NC}"
    echo "  MAC       : $(ip link show "${iface}" 2>/dev/null | awk '/ether/ {print $2}')${NC}"
    echo "  Fetching public IP..."
    local ext_ip
    ext_ip=$(curl -s --max-time 10 https://ifconfig.me 2>/dev/null || true)
    [[ -z "$ext_ip" ]] && ext_ip=$(curl -s --max-time 10 https://api.ipify.org 2>/dev/null || true)
    [[ -z "$ext_ip" ]] && ext_ip=$(curl -s --max-time 10 https://icanhazip.com 2>/dev/null || echo "unavailable")
    echo "  Public IP : ${ext_ip}${NC}"
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

_priv_save_state() {
    sudo mkdir -p "$_PRIV_BACKUP_DIR"
    echo "$1" | sudo tee -a "$_PRIV_STATE_FILE" >/dev/null
}

_priv_check_state() {
    [[ -f "$_PRIV_STATE_FILE" ]] && sudo grep -q "$1" "$_PRIV_STATE_FILE" 2>/dev/null
}

_priv_clear_state() {
    sudo rm -f "$_PRIV_STATE_FILE"
}

_priv_detect_tor_user() {
    local candidate
    for candidate in toranon debian-tor _tor tor; do
        if id "$candidate" &>/dev/null; then
            _PRIV_TOR_USER="$candidate"
            return 0
        fi
    done
    local unit_user
    unit_user=$(grep -oP '(?<=^User=).*' /usr/lib/systemd/system/tor.service 2>/dev/null || true)
    if [[ -n "$unit_user" ]] && id "$unit_user" &>/dev/null; then
        _PRIV_TOR_USER="$unit_user"
        return 0
    fi
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

# ── iptables reset ────────────────────────────────────────────────────────────
_priv_iptables_full_reset() {
    _priv_header "Resetting ALL iptables rules to defaults"
    local table
    for table in filter nat mangle raw security; do
        sudo iptables  -t "$table" -F 2>/dev/null || true
        sudo iptables  -t "$table" -X 2>/dev/null || true
        sudo iptables  -t "$table" -Z 2>/dev/null || true
        sudo ip6tables -t "$table" -F 2>/dev/null || true
        sudo ip6tables -t "$table" -X 2>/dev/null || true
        sudo ip6tables -t "$table" -Z 2>/dev/null || true
    done
    sudo iptables  -P INPUT ACCEPT 2>/dev/null || true
    sudo iptables  -P FORWARD ACCEPT 2>/dev/null || true
    sudo iptables  -P OUTPUT ACCEPT 2>/dev/null || true
    sudo ip6tables -P INPUT ACCEPT 2>/dev/null || true
    sudo ip6tables -P FORWARD ACCEPT 2>/dev/null || true
    sudo ip6tables -P OUTPUT ACCEPT 2>/dev/null || true
    _priv_info "IPv4 + IPv6 iptables: all rules flushed, policies set to ACCEPT."
}

# ── Connectivity check ────────────────────────────────────────────────────────
_priv_check_connectivity() {
    _priv_header "Checking internet connectivity"
    local attempt
    for attempt in 1 2 3; do
        _priv_info "Attempt ${attempt}/3..."
        if host google.com &>/dev/null 2>&1 || nslookup google.com &>/dev/null 2>&1; then
            _priv_info "DNS resolution: OK"
        else
            _priv_warn "DNS resolution failed on attempt ${attempt}"
            [[ $attempt -lt 3 ]] && sleep 2 && continue
        fi
        if curl -s --max-time 8 https://www.google.com &>/dev/null; then
            _priv_info "HTTPS connectivity: OK"
            return 0
        elif curl -s --max-time 8 http://www.google.com &>/dev/null; then
            _priv_info "HTTP connectivity: OK"
            return 0
        else
            _priv_warn "HTTP connectivity failed on attempt ${attempt}"
        fi
        sleep 2
    done
    _priv_error "Internet connectivity check FAILED after 3 attempts."
    echo "  Attempting emergency network repair..."
    _priv_emergency_repair
    return 1
}

# ── Emergency network repair ──────────────────────────────────────────────────
_priv_emergency_repair() {
    _priv_header "Emergency Network Repair"

    _priv_info "Step 1: Flushing all iptables..."
    _priv_iptables_full_reset

    _priv_info "Step 2: Fixing DNS..."
    sudo rm -f /etc/resolv.conf 2>/dev/null || true
    sudo tee /etc/resolv.conf >/dev/null <<'EOF'
# Emergency DNS - written by ip-privacy restore
nameserver 45.90.28.0
nameserver 45.90.30.0
nameserver 9.9.9.9
EOF
    _priv_info "Wrote emergency /etc/resolv.conf"

    _priv_info "Step 3: Restarting NetworkManager..."
    sudo systemctl restart NetworkManager 2>/dev/null || true
    sleep 3

    _priv_info "Step 4: Bringing up network connection..."
    local conn
    conn=$(nmcli -t -f NAME connection show 2>/dev/null | head -1)
    if [[ -n "$conn" ]]; then
        nmcli connection down "$conn" 2>/dev/null || true
        sleep 1
        nmcli connection up "$conn" 2>/dev/null || true
        sleep 3
    fi

    _priv_info "Step 5: Testing connectivity..."
    if curl -s --max-time 8 https://www.google.com &>/dev/null; then
        _priv_info "Network RECOVERED!"
        return 0
    fi

    _priv_warn "Step 6: Last resort — full network stack restart..."
    sudo systemctl restart systemd-resolved 2>/dev/null || true
    sudo systemctl restart NetworkManager 2>/dev/null || true
    sleep 5

    nmcli connection show 2>/dev/null | tail -n +2 | while read -r line; do
        local name
        name=$(echo "$line" | awk '{print $1}')
        nmcli connection up "$name" 2>/dev/null || true
    done
    sleep 3

    if curl -s --max-time 8 https://www.google.com &>/dev/null; then
        _priv_info "Network RECOVERED after full restart!"
    else
        _priv_error "Network still down. Try manually:"
        echo "    sudo systemctl restart NetworkManager"
        echo "    nmcli connection show && nmcli connection up <name>"
    fi
}

#=============================================================================
# TOR TRANSPARENT PROXY
#=============================================================================
_priv_install_tor() {
    if ! command -v tor &>/dev/null; then
        _priv_info "Installing Tor..."
        if ! sudo dnf install -y tor; then
            _priv_error "Failed to install Tor."
            return 1
        fi
    else
        _priv_info "Tor is already installed."
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
    _priv_info "Detected Tor user: ${_PRIV_TOR_USER}${NC}"

    _priv_header "Checking for port conflicts"
    local port_5353_user
    port_5353_user=$(ss -tlnup 2>/dev/null | grep ":5353 " | head -1 || true)
    if [[ -n "$port_5353_user" ]]; then
        _priv_warn "Port 5353 in use (likely avahi-daemon). Using alt DNS port."
    fi

    _PRIV_TOR_DNS_PORT=$(_priv_find_free_port "$_PRIV_TOR_DNS_PORT")   || return 1
    _PRIV_TOR_TRANS_PORT=$(_priv_find_free_port "$_PRIV_TOR_TRANS_PORT") || return 1
    _priv_info "Tor DNS port:   ${_PRIV_TOR_DNS_PORT}${NC}"
    _priv_info "Tor Trans port: ${_PRIV_TOR_TRANS_PORT}${NC}"

    _priv_backup_file /etc/tor/torrc

    local tor_data_dir="/var/lib/tor"
    if [[ -d "$tor_data_dir" ]]; then
        sudo chown -R "${_PRIV_TOR_USER}:${_PRIV_TOR_USER}" "$tor_data_dir" 2>/dev/null || true
        sudo chmod 700 "$tor_data_dir" 2>/dev/null || true
    fi

    sudo tee /etc/tor/torrc >/dev/null <<EOF
## Transparent proxy config — managed by setup.sh ip-privacy module

VirtualAddrNetworkIPv4 ${_PRIV_TOR_VIRT_NET}
AutomapHostsOnResolve 1

TransPort 127.0.0.1:${_PRIV_TOR_TRANS_PORT}
DNSPort 127.0.0.1:${_PRIV_TOR_DNS_PORT}
SocksPort 127.0.0.1:9050

Log notice syslog
ClientRejectInternalAddresses 1
EOF

    sudo mkdir -p /var/log/tor
    sudo chown "${_PRIV_TOR_USER}:${_PRIV_TOR_USER}" /var/log/tor 2>/dev/null || true
    sudo chmod 750 /var/log/tor

    # SELinux handling
    if command -v getenforce &>/dev/null; then
        local se_status
        se_status=$(getenforce 2>/dev/null || echo "Disabled")
        if [[ "$se_status" == "Enforcing" ]]; then
            _priv_warn "SELinux is Enforcing — adding Tor port labels..."
            if ! command -v semanage &>/dev/null; then
                sudo dnf install -y policycoreutils-python-utils 2>/dev/null || true
            fi
            if command -v semanage &>/dev/null; then
                sudo semanage port -a -t tor_port_t -p tcp "$_PRIV_TOR_TRANS_PORT" 2>/dev/null || \
                    sudo semanage port -m -t tor_port_t -p tcp "$_PRIV_TOR_TRANS_PORT" 2>/dev/null || true
                sudo semanage port -a -t tor_port_t -p tcp "$_PRIV_TOR_DNS_PORT" 2>/dev/null || \
                    sudo semanage port -m -t tor_port_t -p tcp "$_PRIV_TOR_DNS_PORT" 2>/dev/null || true
                sudo semanage port -a -t tor_port_t -p udp "$_PRIV_TOR_DNS_PORT" 2>/dev/null || \
                    sudo semanage port -m -t tor_port_t -p udp "$_PRIV_TOR_DNS_PORT" 2>/dev/null || true
            fi
            sudo restorecon -Rv /etc/tor/ /var/lib/tor/ /var/log/tor/ 2>/dev/null || true
            sudo setsebool -P tor_bind_all_unreserved_ports 1 2>/dev/null || true
            _priv_info "SELinux rules applied."
        fi
    fi

    # Save clean iptables before any Tor modification
    if [[ ! -f "${_PRIV_BACKUP_DIR}/iptables-v4-clean.rules" ]]; then
        sudo mkdir -p "$_PRIV_BACKUP_DIR"
        sudo iptables-save  > "${_PRIV_BACKUP_DIR}/iptables-v4-clean.rules" 2>/dev/null || true
        sudo ip6tables-save > "${_PRIV_BACKUP_DIR}/iptables-v6-clean.rules" 2>/dev/null || true
        _priv_info "Saved clean iptables rules (pre-Tor)."
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
    _priv_info "Using Tor UID: ${tor_uid} (user: ${_PRIV_TOR_USER})"

    sudo iptables -F
    sudo iptables -t nat -F
    sudo iptables -t nat -X 2>/dev/null || true

    # NAT: skip Tor's own traffic and LAN
    sudo iptables -t nat -A OUTPUT -m owner --uid-owner "$tor_uid" -j RETURN
    local net
    for net in 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
        sudo iptables -t nat -A OUTPUT -d "$net" -j RETURN
    done

    # NAT: redirect DNS and TCP through Tor
    sudo iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports "$_PRIV_TOR_DNS_PORT"
    sudo iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports "$_PRIV_TOR_DNS_PORT"
    sudo iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports "$_PRIV_TOR_TRANS_PORT"

    # FILTER: allow established, loopback, Tor user, LAN; drop the rest
    sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    sudo iptables -A OUTPUT -o lo -j ACCEPT
    sudo iptables -A OUTPUT -m owner --uid-owner "$tor_uid" -j ACCEPT
    for net in 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
        sudo iptables -A OUTPUT -d "$net" -j ACCEPT
    done
    sudo iptables -A OUTPUT -j REJECT

    # Block IPv6 (leaks via v6 bypass Tor)
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
    _priv_info "Checking via Tor Project API..."
    local check_ip
    check_ip=$(curl -s --max-time 20 --socks5-hostname 127.0.0.1:9050 \
               https://check.torproject.org/api/ip 2>/dev/null || true)
    if [[ -n "$check_ip" ]]; then
        echo "  Tor Project: ${check_ip}${NC}"
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

    echo ""
    _priv_info "Validating Tor configuration..."
    local verify_output
    verify_output=$(tor --verify-config 2>&1) || true
    if echo "$verify_output" | grep -qi "^\[err\]\|Reading config failed"; then
        _priv_error "Tor configuration has errors:"
        echo "$verify_output" | grep -i "err\|failed" | sed 's/^/  /'
        return 1
    fi
    _priv_info "Config is valid."

    echo ""
    _priv_info "Final torrc:"
    echo -e "${CYAN}"
    grep -v "^#\|^$" /etc/tor/torrc | sed 's/^/    /'
    echo -e "${NC}"

    _priv_info "Ensuring ports are free..."
    sudo fuser -k "${_PRIV_TOR_DNS_PORT}/tcp"   2>/dev/null || true
    sudo fuser -k "${_PRIV_TOR_DNS_PORT}/udp"   2>/dev/null || true
    sudo fuser -k "${_PRIV_TOR_TRANS_PORT}/tcp" 2>/dev/null || true
    sleep 1

    sudo systemctl daemon-reload 2>/dev/null || true
    sudo systemctl stop tor 2>/dev/null || true
    sleep 1

    _priv_info "Starting Tor service..."
    sudo systemctl start tor 2>&1 || true
    sleep 2

    if ! systemctl is-active --quiet tor 2>/dev/null; then
        _priv_error "Tor failed to start!"
        echo ""
        echo -e "${YELLOW}  ── Tor Log (last 25 lines) ──${NC}"
        journalctl -u tor --no-pager -n 25 2>/dev/null || true
        echo -e "${YELLOW}  ── End Log ──${NC}"
        return 1
    fi

    sudo systemctl enable tor 2>/dev/null || true
    _priv_save_state "tor_running"
    _priv_info "Tor service is running!"

    _priv_info "Waiting for bootstrap..."
    local waited=0 max_wait=45 last_pct=""
    while [[ $waited -lt $max_wait ]]; do
        if ! systemctl is-active --quiet tor 2>/dev/null; then
            _priv_error "Tor died during bootstrap."
            return 1
        fi
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
    [[ $waited -ge $max_wait ]] && _priv_warn "Bootstrap incomplete after ${max_wait}s — may still connect."

    echo ""
    if ! _priv_tor_iptables_up; then
        _priv_error "iptables failed. Stopping Tor..."
        sudo systemctl stop tor 2>/dev/null || true
        return 1
    fi

    echo ""
    _priv_info "Tor transparent proxy is ACTIVE."
    sleep 2
    _priv_tor_verify
    _priv_show_current_ip
}

_priv_tor_stop() {
    _priv_header "Stopping Tor Transparent Proxy"

    _priv_info "Step 1: Resetting iptables to defaults..."
    _priv_iptables_full_reset

    _priv_info "Step 2: Stopping Tor service..."
    sudo systemctl stop    tor 2>/dev/null || true
    sudo systemctl disable tor 2>/dev/null || true
    _priv_info "Tor service stopped."

    if [[ -f "${_PRIV_BACKUP_DIR}/torrc.orig" ]]; then
        sudo cp "${_PRIV_BACKUP_DIR}/torrc.orig" /etc/tor/torrc
        _priv_info "Restored original torrc."
    fi

    _priv_info "Step 3: Ensuring DNS is working..."
    if ! host google.com &>/dev/null 2>&1; then
        _priv_warn "DNS is broken — fixing..."
        sudo rm -f /etc/resolv.conf 2>/dev/null || true
        sudo tee /etc/resolv.conf >/dev/null <<'EOF'
nameserver 45.90.28.0
nameserver 45.90.30.0
nameserver 9.9.9.9
EOF
        sudo systemctl restart NetworkManager 2>/dev/null || true
        sleep 3
    fi
    _priv_info "DNS check passed."

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
        _priv_info "Control port unavailable. Restarting Tor..."
        sudo systemctl restart tor
        sleep 5
    fi
    sleep 5
    _priv_tor_verify
    _priv_show_current_ip
}

#=============================================================================
# MAC ADDRESS RANDOMIZATION
#=============================================================================
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
    _priv_info "MAC randomization config written."
    _priv_info "Restarting NetworkManager..."
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
    _priv_info "Interface: ${iface}  |  Connection: ${conn}"
    local new_mac
    new_mac=$(printf '02:%02x:%02x:%02x:%02x:%02x' \
        $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) \
        $((RANDOM%256)) $((RANDOM%256)))
    nmcli connection modify "$conn" ethernet.cloned-mac-address "$new_mac"
    nmcli connection modify "$conn" ipv6.addr-gen-mode eui64 2>/dev/null || true
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
    local iface
    iface=$(_priv_get_default_iface)
    [[ -n "$iface" ]] && _priv_info "Current MAC: $(ip link show "${iface}" 2>/dev/null | awk '/ether/ {print $2}')"
}

#=============================================================================
# IPv6 PRIVACY EXTENSIONS
#=============================================================================
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
    _priv_info "Kernel IPv6 privacy extensions enabled."
    local conn
    conn=$(_priv_get_active_connection)
    if [[ -n "$conn" ]]; then
        nmcli connection modify "$conn" ipv6.ip6-privacy 2 2>/dev/null || true
        nmcli connection modify "$conn" ipv6.addr-gen-mode stable-privacy 2>/dev/null || true
        _priv_info "NM IPv6 privacy set for '${conn}'."
    fi
    _priv_save_state "ipv6_privacy"
    _priv_info "IPv6 privacy extensions are active."
}

#=============================================================================
# DNS-OVER-TLS — NextDNS / Quad9
#=============================================================================
_priv_dns_private() {
    _priv_header "Configuring Private DNS (NextDNS + DNS-over-TLS)"
    if [[ -f /etc/resolv.conf && ! -L /etc/resolv.conf ]]; then
        _priv_backup_file /etc/resolv.conf
    fi
    if ! systemctl list-unit-files systemd-resolved.service &>/dev/null; then
        sudo dnf install -y systemd-resolved 2>/dev/null || true
    fi
    sudo mkdir -p /etc/systemd/resolved.conf.d
    sudo tee /etc/systemd/resolved.conf.d/90-dns-privacy.conf >/dev/null <<'EOF'
[Resolve]
DNSOverTLS=opportunistic
DNS=45.90.28.0#dns.nextdns.io 45.90.30.0#dns.nextdns.io
FallbackDNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
Domains=~.
MulticastDNS=no
LLMNR=no
Cache=yes
CacheFromLocalhost=no
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
    _priv_info "DNS-over-TLS configured with NextDNS."
    echo ""
    echo "  Primary:${NC}   45.90.28.0 (NextDNS)"
    echo "  Secondary:${NC} 45.90.30.0 (NextDNS)"
    echo "  Fallback:${NC}  9.9.9.9 (Quad9)"
    echo ""
    echo -e "  ${CYAN}Tip: Get a custom NextDNS config ID at https://nextdns.io${NC}"
    if command -v resolvectl &>/dev/null; then
        _priv_info "Current DNS status:"
        resolvectl status 2>/dev/null | grep -E "DNS Server|DNS Domain|DNSOverTLS" | sed 's/^/  /' || true
    fi
    echo ""
    _priv_info "Testing DNS resolution..."
    if host google.com &>/dev/null 2>&1; then
        _priv_info "DNS resolution: OK"
    else
        _priv_warn "DNS test failed. Retrying after restart..."
        sudo systemctl restart systemd-resolved 2>/dev/null || true
        sleep 2
        if host google.com &>/dev/null 2>&1; then
            _priv_info "DNS fixed after restart."
        else
            _priv_error "DNS still broken. Reverting..."
            _priv_dns_restore
        fi
    fi
}

_priv_dns_restore() {
    _priv_header "Restoring DNS to defaults"
    sudo rm -f /etc/systemd/resolved.conf.d/90-dns-privacy.conf
    sudo rm -f /etc/NetworkManager/conf.d/90-dns-resolved.conf
    sudo rm -f /etc/resolv.conf 2>/dev/null || true
    if [[ -f "${_PRIV_BACKUP_DIR}/resolv.conf.orig" ]]; then
        sudo cp "${_PRIV_BACKUP_DIR}/resolv.conf.orig" /etc/resolv.conf
        _priv_info "Restored original resolv.conf from backup."
    else
        sudo tee /etc/resolv.conf >/dev/null <<'EOF'
# Generated by setup.sh ip-privacy restore
nameserver 45.90.28.0
nameserver 45.90.30.0
nameserver 9.9.9.9
EOF
        _priv_info "Wrote default resolv.conf with NextDNS + Quad9."
    fi
    sudo systemctl restart systemd-resolved 2>/dev/null || true
    sudo systemctl restart NetworkManager 2>/dev/null || true
    sleep 3
    _priv_info "DNS restored."
}

#=============================================================================
# WIREGUARD VPN
#=============================================================================
_priv_wg_setup() {
    _priv_header "WireGuard VPN Setup"
    if ! command -v wg &>/dev/null; then
        _priv_info "Installing WireGuard tools..."
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
            if nmcli connection import type wireguard file "${wg_dir}/${wg_name}.conf" 2>/dev/null; then
                _priv_info "Imported via NetworkManager. Activating..."
                nmcli connection up "$wg_name" 2>/dev/null || true
            else
                sudo systemctl enable --now "wg-quick@${wg_name}" 2>/dev/null || true
            fi
            sleep 3
            _priv_show_current_ip
            ;;
        2)
            local privkey pubkey
            privkey=$(wg genkey)
            pubkey=$(echo "$privkey" | wg pubkey)
            echo ""
            _priv_info "Generated keypair:"
            echo "  Private: ${privkey}${NC}"
            echo "  Public:  ${pubkey}${NC}"
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
        *)  _priv_warn "Invalid choice." ;;
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

#=============================================================================
# FULL PRIVACY MODE (all-in-one)
#=============================================================================
_priv_full_on() {
    _priv_header "FULL PRIVACY MODE — Activating all protections"
    echo ""
    _priv_ipv6_privacy;          echo ""
    _priv_dns_private;           echo ""
    _priv_mac_randomize_persistent; echo ""
    _priv_tor_start;             echo ""
    _priv_save_state "full_privacy"
    echo -e "${GREEN}+----------------------------------------------+"
    echo "|   FULL PRIVACY MODE IS NOW ACTIVE            |"
    echo "|                                              |"
    echo "|   [+] MAC address randomized                |"
    echo "|   [+] IPv6 privacy extensions enabled       |"
    echo "|   [+] DNS-over-TLS (NextDNS) configured     |"
    echo "|   [+] All traffic routed through Tor        |"
    echo "|                                              |"
    echo "|   Select option 12 in privacy menu to undo  |"
    echo "+----------------------------------------------+${NC}"
}

_priv_full_off() {
    _priv_header "RESTORING ALL SETTINGS TO DEFAULTS"
    echo ""
    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Reset ALL iptables rules (IPv4 + IPv6)"
    echo "  2. Stop Tor"
    echo "  3. Restore DNS"
    echo "  4. Restore MAC address"
    echo "  5. Remove IPv6 privacy sysctl"
    echo "  6. Verify internet connectivity"
    echo ""
    read -rp "${YELLOW}Continue? [y/N]: ${NC}" confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { _priv_info "Cancelled."; return 0; }
    echo ""

    _priv_info "STEP 1/6: Resetting iptables..."
    _priv_iptables_full_reset

    _priv_info "STEP 2/6: Stopping Tor..."
    sudo systemctl stop    tor 2>/dev/null || true
    sudo systemctl disable tor 2>/dev/null || true
    [[ -f "${_PRIV_BACKUP_DIR}/torrc.orig" ]] && \
        sudo cp "${_PRIV_BACKUP_DIR}/torrc.orig" /etc/tor/torrc 2>/dev/null || true
    _priv_info "Tor stopped."

    _priv_info "STEP 3/6: Restoring DNS..."
    sudo rm -f /etc/systemd/resolved.conf.d/90-dns-privacy.conf 2>/dev/null || true
    sudo rm -f /etc/NetworkManager/conf.d/90-dns-resolved.conf  2>/dev/null || true
    sudo rm -f /etc/resolv.conf 2>/dev/null || true
    if [[ -f "${_PRIV_BACKUP_DIR}/resolv.conf.orig" ]]; then
        sudo cp "${_PRIV_BACKUP_DIR}/resolv.conf.orig" /etc/resolv.conf
        _priv_info "Restored original resolv.conf."
    else
        sudo tee /etc/resolv.conf >/dev/null <<'EOF'
nameserver 45.90.28.0
nameserver 45.90.30.0
nameserver 9.9.9.9
EOF
        _priv_info "Wrote default resolv.conf (NextDNS + Quad9)."
    fi
    sudo systemctl restart systemd-resolved 2>/dev/null || true

    _priv_info "STEP 4/6: Restoring MAC address..."
    sudo rm -f /etc/NetworkManager/conf.d/90-mac-randomize.conf 2>/dev/null || true
    local conn
    conn=$(nmcli -t -f NAME connection show 2>/dev/null | head -1)
    [[ -n "$conn" ]] && nmcli connection modify "$conn" ethernet.cloned-mac-address "" 2>/dev/null || true

    _priv_info "STEP 5/6: Removing IPv6 privacy sysctl..."
    sudo rm -f /etc/sysctl.d/90-ipv6-privacy.conf 2>/dev/null || true
    sudo sysctl --system >/dev/null 2>&1 || true

    _priv_info "STEP 6/6: Restarting network stack..."
    sudo systemctl restart NetworkManager 2>/dev/null || true
    sleep 4

    local waited=0
    while [[ $waited -lt 15 ]]; do
        nmcli -t -f STATE general 2>/dev/null | grep -q "connected" && break
        sleep 1; waited=$((waited + 1))
    done

    if ! nmcli -t -f STATE general 2>/dev/null | grep -q "connected"; then
        _priv_warn "NM not fully connected. Trying to bring up connection..."
        conn=$(nmcli -t -f NAME connection show 2>/dev/null | head -1)
        [[ -n "$conn" ]] && nmcli connection up "$conn" 2>/dev/null || true
        sleep 3
    fi

    _priv_clear_state
    echo ""
    _priv_check_connectivity
    _priv_show_current_ip

    echo -e "${GREEN}+----------------------------------------------+"
    echo "|   ALL SETTINGS RESTORED TO DEFAULTS          |"
    echo "|   [-] iptables reset (IPv4 + IPv6)          |"
    echo "|   [-] Tor stopped                           |"
    echo "|   [-] DNS restored (NextDNS + Quad9)        |"
    echo "|   [-] MAC address restored                  |"
    echo "|   [-] IPv6 privacy removed                  |"
    echo "|   [-] Internet connectivity verified        |"
    echo "+----------------------------------------------+${NC}"
}

#=============================================================================
# LEAK TEST
#=============================================================================
_priv_leak_test() {
    _priv_header "Privacy Leak Test"
    echo ""
    echo -e "[Public IP]${NC}"
    local ext_ip
    ext_ip=$(curl -s --max-time 10 https://ifconfig.me 2>/dev/null || \
             curl -s --max-time 10 https://api.ipify.org 2>/dev/null || echo "unavailable")
    echo "  Public IP: ${ext_ip}${NC}"

    echo ""
    echo -e "[Tor Check]${NC}"
    local tor_check
    tor_check=$(curl -s --max-time 15 https://check.torproject.org/api/ip 2>/dev/null || echo "unavailable")
    echo "  Tor API: ${tor_check}${NC}"

    echo ""
    echo -e "[DNS Check]${NC}"
    if command -v resolvectl &>/dev/null; then
        resolvectl status 2>/dev/null | grep -E "DNS Server|DNSOverTLS" | sed 's/^/  /' || echo "  (no info)"
    fi
    local dns_result
    dns_result=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || echo "dig not available")
    echo "  OpenDNS resolver IP: ${dns_result}${NC}"

    echo ""
    echo -e "[Browser Tests]${NC}"
    echo "  DNS leaks:    https://dnsleaktest.com"
    echo "  WebRTC:       https://browserleaks.com/webrtc"
    echo "  Full check:   https://ipleak.net"
    echo ""
}

#=============================================================================
# DIAGNOSTICS
#=============================================================================
_priv_diagnose() {
    _priv_header "System Diagnostics"

    echo -e "[Tor]${NC}"
    echo "  Installed:   $(command -v tor &>/dev/null && echo 'yes' || echo 'no')"
    echo "  Service:     $(systemctl is-active tor 2>/dev/null || echo 'inactive')"
    echo "  Enabled:     $(systemctl is-enabled tor 2>/dev/null || echo 'disabled')"
    if _priv_detect_tor_user; then
        echo "  User:        ${_PRIV_TOR_USER} (UID $(id -u "$_PRIV_TOR_USER" 2>/dev/null))"
    else
        echo -e "  User:        ${RED}NOT FOUND${NC}"
    fi

    echo ""
    echo -e "[Config validation]${NC}"
    command -v tor &>/dev/null && tor --verify-config 2>&1 | tail -3 | sed 's/^/  /' || true

    echo ""
    echo -e "[Ports]${NC}"
    echo "  ${_PRIV_TOR_DNS_PORT}/tcp (Tor DNS):"
    ss -tlnup 2>/dev/null | grep ":${_PRIV_TOR_DNS_PORT} " | sed 's/^/    /' || echo "    (free)"
    echo "  ${_PRIV_TOR_TRANS_PORT}/tcp (Tor Trans):"
    ss -tlnup 2>/dev/null | grep ":${_PRIV_TOR_TRANS_PORT} " | sed 's/^/    /' || echo "    (free)"
    echo "  9050 (Tor SOCKS):"
    ss -tlnup 2>/dev/null | grep ":9050 " | sed 's/^/    /' || echo "    (free)"

    echo ""
    echo -e "[SELinux]${NC}"
    if command -v getenforce &>/dev/null; then
        echo "  Status: $(getenforce 2>/dev/null)"
        echo "  Tor denials:"
        ausearch -m avc -c tor --raw 2>/dev/null | tail -3 | sed 's/^/    /' || echo "    (none)"
    else
        echo "  Not installed"
    fi

    echo ""
    echo -e "[Network]${NC}"
    local iface
    iface=$(_priv_get_default_iface)
    echo "  NM state:    $(nmcli -t -f STATE general 2>/dev/null || echo 'unknown')"
    echo "  Interface:   ${iface:-none}"
    echo "  Connection:  $(_priv_get_active_connection)"
    echo "  Gateway:     $(ip route show default 2>/dev/null | awk '{print $3; exit}')"

    echo ""
    echo -e "[DNS]${NC}"
    echo "  /etc/resolv.conf:"
    [[ -L /etc/resolv.conf ]] && echo "    (symlink -> $(readlink /etc/resolv.conf))"
    grep -v "^#\|^$" /etc/resolv.conf 2>/dev/null | sed 's/^/    /' || echo "    (missing)"
    echo "  Test: $(host google.com 2>&1 | head -1)"

    echo ""
    echo -e "[iptables IPv4]${NC}"
    echo "  INPUT:   $(sudo iptables -L INPUT   2>/dev/null | head -1 | grep -o 'policy [A-Z]*')"
    echo "  FORWARD: $(sudo iptables -L FORWARD 2>/dev/null | head -1 | grep -o 'policy [A-Z]*')"
    echo "  OUTPUT:  $(sudo iptables -L OUTPUT  2>/dev/null | head -1 | grep -o 'policy [A-Z]*')"
    echo "  NAT OUTPUT rules: $(sudo iptables -t nat -L OUTPUT 2>/dev/null | tail -n +3 | wc -l)"

    echo ""
    echo -e "[iptables IPv6]${NC}"
    echo "  INPUT:   $(sudo ip6tables -L INPUT   2>/dev/null | head -1 | grep -o 'policy [A-Z]*')"
    echo "  OUTPUT:  $(sudo ip6tables -L OUTPUT  2>/dev/null | head -1 | grep -o 'policy [A-Z]*')"

    echo ""
    echo -e "[State file]${NC}"
    if [[ -f "$_PRIV_STATE_FILE" ]]; then
        cat "$_PRIV_STATE_FILE" | sed 's/^/    /'
    else
        echo "    (no state saved)"
    fi

    echo ""
    echo -e "[Tor log (last 15 lines)]${NC}"
    journalctl -u tor --no-pager -n 15 2>/dev/null | sed 's/^/  /' || echo "  (no logs)"

    echo ""
    echo -e "[Current torrc]${NC}"
    if [[ -f /etc/tor/torrc ]]; then
        grep -v "^#\|^$" /etc/tor/torrc | sed 's/^/  /'
    else
        echo "  (not found)"
    fi
    echo ""
}

#=============================================================================
# YGGDRASIL MESH VPN (integrated)
# Ref: https://yggdrasil-network.github.io/configuration.html
#      https://yggdrasil-network.github.io/installation-linux-rpm.html
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
            _ygg_sep
            echo -e "  Yggdrasil Status${NC}"
            _ygg_sep
            systemctl status yggdrasil --no-pager -l 2>&1 | head -20
            echo ""
            echo -e "  IPv6 address (tun0)${NC}"
            ip -6 addr show tun0 2>/dev/null | grep inet6 | awk '{print "  "$2}' \
                || echo "  (not yet — service may still be starting)"
            echo ""
            echo -e "  Self info${NC}"
            sudo yggdrasilctl getSelf 2>/dev/null | python3 -m json.tool 2>/dev/null \
                || echo "  (admin socket not ready)"
            echo ""
            echo -e "  Connected peers${NC}"
            sudo yggdrasilctl getPeers 2>/dev/null | python3 -m json.tool 2>/dev/null \
                || echo "  (no peers yet)"
            return
            ;;
        2)
            print_section "Uninstalling Yggdrasil..."
            sudo systemctl stop    yggdrasil 2>/dev/null || true
            sudo systemctl disable yggdrasil 2>/dev/null || true
            sudo dnf remove -y yggdrasil    2>/dev/null || true
            sudo dnf copr disable neilalexander/yggdrasil-go -y 2>/dev/null || true
            sudo rm -f /etc/yggdrasil.conf
            sudo rm -f /usr/local/bin/yggdrasil-status
            sudo rm -f /etc/xdg/autostart/yggdrasil-notify.desktop
            sudo rm -f /usr/share/applications/yggdrasil-status.desktop
            print_success "Yggdrasil removed."
            return
            ;;
        1) ;;  # fall through to install
        *) print_error "Invalid choice."; return ;;
    esac

    # ── STEP 1: System update ────────────────────────────────────────────────
    print_section "Updating system packages..."
    sudo dnf update -y -q
    _ygg_ok "System up to date."

    # ── STEP 2: Install via official COPR ───────────────────────────────────
    # Source: https://yggdrasil-network.github.io/installation-linux-rpm.html
    #   dnf copr enable neilalexander/yggdrasil-go
    #   dnf install yggdrasil
    print_section "Installing Yggdrasil (official COPR: neilalexander/yggdrasil-go)..."
    sudo dnf copr enable -y neilalexander/yggdrasil-go
    sudo dnf install -y yggdrasil
    local _ygg_ver
    _ygg_ver=$(yggdrasil -version 2>/dev/null | awk '{print $NF}' || echo "unknown")
    _ygg_ok "Installed — version: ${_ygg_ver}"

    # ── STEP 3: Generate config ──────────────────────────────────────────────
    # Official command: yggdrasil -genconf > /etc/yggdrasil.conf
    # Config path used by the RPM package: /etc/yggdrasil.conf (single file)
    # HJSON format preserves comments and is the recommended default.
    local _ygg_conf="/etc/yggdrasil.conf"
    print_section "Generating configuration (HJSON format)..."
    if [[ -f "$_ygg_conf" ]]; then
        local _ygg_bak="${_ygg_conf}.bak.$(date +%Y%m%d_%H%M%S)"
        _ygg_warn "Existing config found — backing up to ${_ygg_bak}"
        sudo cp "$_ygg_conf" "$_ygg_bak"
    fi
    sudo yggdrasil -genconf | sudo tee "$_ygg_conf" >/dev/null
    sudo chmod 600 "$_ygg_conf"
    _ygg_ok "Config written to ${_ygg_conf} (chmod 600 — contains private key)"

    # ── STEP 4: Inject peers ─────────────────────────────────────────────────
    # Peer URI formats per official docs:
    #   tcp://hostname:port       — direct TCP
    #   tls://hostname:port       — TCP + TLS (DPI-resistant)
    #   quic://hostname:port      — QUIC/UDP (good behind NAT)
    # Keep to 2-3 nearby peers for home use.
    # Find live peers at: https://publicpeers.neilalexander.dev/
    print_section "Injecting public peers..."

    # Write peers to a temp file, then pass it as an argument to Python.
    # This avoids fragile variable expansion inside heredocs.
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

    # Python reads the root-owned config via sudo cat, patches it in memory,
    # then writes to a temp file which we sudo-copy back (avoids permission issues).
    local _ygg_patched_tmp
    _ygg_patched_tmp=$(mktemp)
    sudo cat "$_ygg_conf" | python3 - "$_ygg_peers_tmp" "$_ygg_patched_tmp" <<'PYEOF'
import sys, re, pathlib
peers_file, out_file = sys.argv[1], sys.argv[2]
content = sys.stdin.read()
with open(peers_file) as pf:
    block = pf.read().strip()
patched = re.sub(r'Peers:\s*\[.*?\]', 'Peers: ' + block, content, flags=re.DOTALL)
pathlib.Path(out_file).write_text(patched)
print("  Peers injected.")
PYEOF
    sudo cp "$_ygg_patched_tmp" "$_ygg_conf"
    sudo chmod 600 "$_ygg_conf"
    rm -f "$_ygg_peers_tmp" "$_ygg_patched_tmp"
    _ygg_ok "Peers configured. Edit ${_ygg_conf} to customise."
    _ygg_info "Find peers near you: https://publicpeers.neilalexander.dev/"

    # ── STEP 5: Firewall ─────────────────────────────────────────────────────
    print_section "Configuring firewall..."
    if systemctl is-active --quiet firewalld; then
        local _ygg_port
        _ygg_port=$(grep -oP '(?<=:)\d+(?=")' "$_ygg_conf" | head -1 2>/dev/null || echo "9001")
        [[ "$_ygg_port" =~ ^[0-9]+$ ]] || _ygg_port="9001"
        sudo firewall-cmd --permanent --add-port="${_ygg_port}/tcp" -q
        sudo firewall-cmd --permanent --add-port="${_ygg_port}/udp" -q
        sudo firewall-cmd --permanent --zone=trusted --add-interface=tun0 -q 2>/dev/null || true
        sudo firewall-cmd --reload -q
        _ygg_ok "Firewall: port ${_ygg_port} TCP/UDP opened; tun0 trusted."
    else
        _ygg_warn "firewalld not running — skipping firewall config."
    fi

    # ── STEP 6: Enable service ───────────────────────────────────────────────
    print_section "Enabling systemd service..."
    sudo systemctl daemon-reload
    sudo systemctl enable yggdrasil
    sudo systemctl restart yggdrasil
    sleep 3
    if systemctl is-active --quiet yggdrasil; then
        _ygg_ok "yggdrasil.service is running."
    else
        _ygg_warn "Service not running. Check logs:"
        _ygg_warn "  sudo journalctl -u yggdrasil -n 60 --no-pager"
    fi

    # ── KDE integration ───────────────────────────────────────────────────────
    print_section "Installing KDE desktop integration..."

    sudo tee /usr/local/bin/yggdrasil-status >/dev/null <<'YGG_STATUS'
#!/usr/bin/env bash
B='\033[1;36m'; N='\033[0m'
hdr() { echo -e "\n${B}━━  $* ━━${N}"; }
hdr "Yggdrasil Network Status"
hdr "Service"
systemctl status yggdrasil --no-pager -l 2>&1 | head -20
hdr "IPv6 address (tun0)"
ip -6 addr show tun0 2>/dev/null | grep inet6 | awk '{print "  "$2}' \
    || echo "  (not yet)"
hdr "Self info  →  yggdrasilctl getSelf"
sudo yggdrasilctl getSelf 2>/dev/null | python3 -m json.tool 2>/dev/null \
    || echo "  (admin socket not ready)"
hdr "Connected peers  →  yggdrasilctl getPeers"
sudo yggdrasilctl getPeers 2>/dev/null | python3 -m json.tool 2>/dev/null \
    || echo "  (no peers)"
hdr "Quick reference"
cat <<'CMDS'
  sudo nano /etc/yggdrasil.conf         — edit peers / config
  sudo systemctl restart yggdrasil      — apply changes
  sudo yggdrasilctl getSelf             — address & public key
  sudo journalctl -u yggdrasil -f       — live logs
CMDS
YGG_STATUS
    sudo chmod +x /usr/local/bin/yggdrasil-status

    sudo mkdir -p /etc/xdg/autostart
    sudo tee /etc/xdg/autostart/yggdrasil-notify.desktop >/dev/null <<'DESK'
[Desktop Entry]
Type=Application
Name=Yggdrasil Network Notifier
Exec=bash -c 'sleep 10 && systemctl is-active --quiet yggdrasil && kdialog --title "Yggdrasil Network" --passivepopup "Yggdrasil mesh VPN is running.\nRun: yggdrasil-status" 7'
Icon=network-vpn
Hidden=false
X-KDE-autostart-phase=2
NoDisplay=false
DESK

    sudo mkdir -p /usr/share/applications
    sudo tee /usr/share/applications/yggdrasil-status.desktop >/dev/null <<'DESK'
[Desktop Entry]
Version=1.0
Type=Application
Name=Yggdrasil Status
GenericName=Mesh VPN Status
Comment=View Yggdrasil network status and connected peers
Exec=konsole --hold -e yggdrasil-status
Icon=network-vpn
Terminal=false
Categories=Network;Security;
Keywords=yggdrasil;vpn;ipv6;mesh;
DESK

    _ygg_ok "KDE integration complete."

    # ── Summary ───────────────────────────────────────────────────────────────
    _ygg_sep
    echo ""
    local _ygg_addr
    _ygg_addr=$(ip -6 addr show tun0 2>/dev/null | grep inet6 | awk '{print $2}' | head -1 || true)
    if [[ -n "$_ygg_addr" ]]; then
        echo -e "  Your Yggdrasil IPv6 address: ${CYAN}${_ygg_addr}${NC}"
    else
        echo -e "  ${YELLOW}IPv6 address will appear shortly — run: sudo yggdrasilctl getSelf${NC}"
    fi
    echo ""
    echo "  Commands:"
    echo "    yggdrasil-status                  — terminal status viewer"
    echo "    sudo yggdrasilctl getSelf         — node address & key"
    echo "    sudo nano /etc/yggdrasil.conf     — edit peers / config"
    echo "    sudo systemctl restart yggdrasil  — apply config changes"
    echo "    sudo journalctl -u yggdrasil -f   — live logs"
    echo ""
    echo -e "  ${YELLOW}Backup /etc/yggdrasil.conf — it contains your private key!${NC}"
    _ygg_sep
}

#=============================================================================
# PRIVACY & NETWORK — SUB-MENU
# Called from main menu option 17. Does NOT call exit 0 — returns to main.
#=============================================================================
privacy_network_menu() {
    print_header "Privacy & Network Tools"

    # Ensure required tools are present (install silently if missing)
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

        # Status bar (instant — no external curl)
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
        echo -e "  ${GREEN} 1)${NC}  Start Tor transparent proxy    (hide public IP)"
        echo -e "  ${GREEN} 2)${NC}  Get new Tor identity            (new exit IP)"
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
        echo "       (encrypted IPv6 mesh, self-hosted, no central server)"
        echo ""
        echo -e "  ─── All-in-One ───────────────────────────────────${NC}"
        echo -e "  ${GREEN}12)${NC}  FULL PRIVACY MODE  (Tor + MAC random + DoT + IPv6)"
        echo -e "  ${GREEN}13)${NC}  RESTORE EVERYTHING to defaults"
        echo ""
        echo -e "  ─── Info & Troubleshoot ──────────────────────────${NC}"
        echo -e "  ${GREEN}14)${NC}  Run privacy leak test"
        echo -e "  ${GREEN}15)${NC}  Show current IP info (with public IP)"
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
# AUTO MOUNT — ALL DRIVES (INTERNAL & EXTERNAL)
#===========================================

# ── Helpers ───────────────────────────────────────────────────────────────────
_mnt_ok()   { echo -e "${GREEN}  ✓${NC}  $*"; }
_mnt_warn() { echo -e "${YELLOW}  !${NC}  $*"; }
_mnt_err()  { echo -e "${RED}  ✗${NC}  $*"; }
_mnt_info() { echo -e "${CYAN}  ›${NC}  $*"; }
_mnt_sep()  { echo -e "  ──────────────────────────────────────────────${NC}"; }

# ── Detect filesystem type label (human-readable) ─────────────────────────────
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

# ── Install filesystem drivers if missing ────────────────────────────────────
_mnt_ensure_drivers() {
    local need_ntfs=false need_exfat=false need_btrfs=false

    # Scan all block devices for filesystem types that need extra packages
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
    # udisks2 — needed for automatic USB mounting via KDE / udev rules
    command -v udisksctl &>/dev/null || pkgs+=(udisks2)
    # gvfs — needed for Dolphin to show mounted drives
    rpm -q gvfs &>/dev/null          || pkgs+=(gvfs gvfs-smb gvfs-mtp gvfs-gphoto2)

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        _mnt_info "Installing missing filesystem packages: ${pkgs[*]}"
        sudo dnf install -y "${pkgs[@]}" &>>"$LOG_FILE" \
            && _mnt_ok "Filesystem packages installed." \
            || _mnt_warn "Some packages failed — continuing anyway."
    else
        _mnt_ok "All required filesystem drivers are present."
    fi
}

# ── Scan block devices and build mount table ──────────────────────────────────
_mnt_scan_devices() {
    # Returns lines: DEVICE|FSTYPE|SIZE|LABEL|UUID|CURRENT_MOUNTPOINT
    lsblk -rno NAME,FSTYPE,SIZE,LABEL,UUID,MOUNTPOINT 2>/dev/null \
        | awk '$2 != "" && $2 != "swap" && $2 != "LVM2_member" && $2 != "linux_raid_member" {
            dev="/dev/"$1; print dev"|"$2"|"$3"|"$4"|"$5"|"$6
        }'
}

# ── Show current drive table ──────────────────────────────────────────────────
_mnt_show_drive_table() {
    echo ""
    echo -e "  ${CYAN}Detected Block Devices:${NC}"
    _mnt_sep
    printf "  %-12s %-22s %-8s %-20s %-s\n" \
           "DEVICE" "FILESYSTEM" "SIZE" "LABEL/UUID" "MOUNTPOINT"
    _mnt_sep

    local dev fstype sz label uuid mnt display_label
    while IFS='|' read -r dev fstype sz label uuid mnt; do
        display_label="${label:-${uuid:0:8}}"
        [[ -z "$display_label" ]] && display_label="(none)"
        local mnt_display="${mnt:-(not mounted)}"
        local fs_label
        fs_label=$(_mnt_fstype_label "$fstype")
        printf "  %-12s %-22s %-8s %-20s %-s\n" \
               "$dev" "$fs_label" "$sz" "$display_label" "$mnt_display"
    done < <(_mnt_scan_devices)
    _mnt_sep
    echo ""
}

# ── Generate a safe mount directory name ─────────────────────────────────────
_mnt_make_mountpoint() {
    local dev="$1" label="$2" uuid="$3"
    local base
    # Prefer label → UUID prefix → device basename
    if [[ -n "$label" ]]; then
        # Sanitise: keep alphanumeric, dash, underscore
        base=$(echo "$label" | tr ' ' '_' | tr -cd '[:alnum:]_-' | head -c 32)
    elif [[ -n "$uuid" ]]; then
        base="disk_${uuid:0:8}"
    else
        base="disk_$(basename "$dev")"
    fi
    echo "/mnt/${base}"
}

# ── Mount one device ──────────────────────────────────────────────────────────
_mnt_mount_device() {
    local dev="$1" fstype="$2" label="$3" uuid="$4"

    local mountpoint
    mountpoint=$(_mnt_make_mountpoint "$dev" "$label" "$uuid")

    # If already mounted somewhere, just report it
    local existing_mnt
    existing_mnt=$(lsblk -rno MOUNTPOINT "$dev" 2>/dev/null | grep -v '^$' | head -1)
    if [[ -n "$existing_mnt" ]]; then
        _mnt_warn "$(basename "$dev") already mounted at ${existing_mnt} — skipping."
        return 0
    fi

    sudo mkdir -p "$mountpoint"

    # Build mount options per filesystem type
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
        # Try auto-detect (let kernel pick the driver)
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

# ── Write persistent /etc/fstab entries ──────────────────────────────────────
_mnt_write_fstab() {
    local dev="$1" fstype="$2" label="$3" uuid="$4"

    if [[ -z "$uuid" ]]; then
        _mnt_warn "$(basename "$dev") has no UUID — cannot write reliable fstab entry."
        return 0
    fi

    local mountpoint
    mountpoint=$(_mnt_make_mountpoint "$dev" "$label" "$uuid")

    # Check if entry already exists (by UUID)
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
        ext4)
            opts="defaults,noatime,nofail,x-systemd.device-timeout=10s"
            dump=0; pass=2
            ;;
        ext3|ext2)
            opts="defaults,noatime,nofail,x-systemd.device-timeout=10s"
            dump=0; pass=2
            ;;
        xfs)
            opts="defaults,noatime,nofail,x-systemd.device-timeout=10s"
            dump=0; pass=2
            ;;
        btrfs)
            opts="defaults,noatime,compress=zstd,nofail,x-systemd.device-timeout=10s"
            dump=0; pass=0
            ;;
        *)
            opts="defaults,nofail,x-systemd.device-timeout=10s"
            dump=0; pass=0
            ;;
    esac

    local display_label="${label:-(no label)}"
    {
        echo ""
        echo "# Added by setup.sh auto-mount — $(date '+%Y-%m-%d %H:%M')"
        echo "# Device: ${dev}  Label: ${display_label}"
        printf 'UUID=%-38s %-30s %-10s %-50s %s %s\n' \
               "$uuid" "$mountpoint" "$fstype" "$opts" "$dump" "$pass"
    } | sudo tee -a /etc/fstab >/dev/null

    _mnt_ok "fstab entry added for ${dev} (UUID ${uuid:0:8}…) → ${mountpoint}"
}

# ── Setup udev rules for USB auto-mount ──────────────────────────────────────
_mnt_setup_udev() {
    _mnt_info "Setting up udev rules for automatic USB/external drive mounting..."

    # Rule: when a USB storage device with a filesystem is plugged in,
    # trigger udisks2 to auto-mount it (KDE Plasma handles the GUI popup).
    sudo tee /etc/udev/rules.d/99-automount.rules >/dev/null <<'UDEV'
# Auto-mount USB and external drives via systemd-mount when plugged in
# Created by setup.sh auto-mount module

# USB mass storage — trigger systemd to auto-mount on filesystem appearance
ACTION=="add", SUBSYSTEMS=="usb", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", \
    RUN+="/usr/bin/systemd-mount --no-block --collect --automount=yes %N"
UDEV

    sudo udevadm control --reload-rules 2>/dev/null && _mnt_ok "udev rules reloaded." \
        || _mnt_warn "udev reload failed — rules will apply after reboot."
}

# ── Setup systemd automount units for all fstab entries ──────────────────────
_mnt_reload_systemd() {
    _mnt_info "Reloading systemd daemon and activating fstab mounts..."
    sudo systemctl daemon-reload 2>/dev/null || true
    sudo systemctl reset-failed  2>/dev/null || true

    # Mount everything in fstab that isn't already mounted
    if sudo mount -a 2>>"$LOG_FILE"; then
        _mnt_ok "All fstab entries mounted successfully."
    else
        _mnt_warn "Some fstab mounts had errors — check ${LOG_FILE}"
    fi

    # ── Targeted verification of only the entries we just added ───────
    # We do NOT use `findmnt --verify` on the whole fstab because it
    # reports warnings for /boot, EFI, and other entries that are only
    # available at specific boot stages — causing false-positive failures
    # and reverting perfectly valid entries.
    # Instead: check only UUIDs we wrote (lines tagged with our comment).

    local _bad_uuids=0
    local _added_uuids
    _added_uuids=$(grep -A1 "Added by setup.sh auto-mount" /etc/fstab 2>/dev/null \
        | grep "^UUID=" | awk '{print $1}' | sed 's/UUID=//' || true)

    local _uuid
    for _uuid in $_added_uuids; do
        # Check the device for this UUID actually exists on the system
        if ! blkid -U "$_uuid" &>/dev/null 2>&1; then
            _mnt_err "UUID=${_uuid:0:8}… not found on this system — reverting that entry."
            # Remove the full 3-line block (blank + 2 comment lines + UUID line)
            # using Python to avoid sed multi-line limitations
            sudo python3 - /etc/fstab "$_uuid" <<'PYREVERT'
import sys, re
fstab_path, uuid = sys.argv[1], sys.argv[2]
with open(fstab_path) as f:
    content = f.read()
# Remove the full block: blank line + comment header + device comment + UUID entry
cleaned = re.sub(
    r'\n# Added by setup\.sh auto-mount[^\n]*\n# Device:[^\n]*\nUUID=' + re.escape(uuid) + r'[^\n]*',
    '',
    content
)
with open(fstab_path, 'w') as f:
    f.write(cleaned)
PYREVERT
            _bad_uuids=$(( _bad_uuids + 1 ))
        else
            _mnt_ok "UUID=${_uuid:0:8}… verified on this system."
        fi
    done

    if [[ $_bad_uuids -gt 0 ]]; then
        _mnt_warn "$_bad_uuids invalid fstab entr(ies) removed. Your system is safe."
        sudo systemctl daemon-reload 2>/dev/null || true
        return 1
    fi

    _mnt_ok "All added fstab entries verified — no issues found."
    return 0
}

# ── Install udisks2 policy for non-root mounting in KDE ──────────────────────
_mnt_setup_polkit() {
    _mnt_info "Configuring polkit so regular users can mount/unmount drives in KDE..."

    sudo mkdir -p /etc/polkit-1/rules.d
    sudo tee /etc/polkit-1/rules.d/99-udisks2-mount.rules >/dev/null <<'POLKIT'
// Allow local users to mount/unmount/format storage devices via udisks2
// (Required for Dolphin file manager and KDE device notifier)
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

# ── Main auto-mount function (called from menu) ───────────────────────────────
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
    echo -e "    ${WHITE}6)${NC} Remove auto-mount fstab entries added by this tool"
    echo -e "    ${WHITE}0)${NC} Cancel"
    echo ""
    read -rp "  Choice [1]: " _mnt_choice; _mnt_choice="${_mnt_choice:-1}"

    case "$_mnt_choice" in
        0)
            print_warning "Cancelled."
            return
            ;;
        4)
            _mnt_show_drive_table
            return
            ;;
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
                _mnt_err "Could not unmount ${_umnt_dev} (may not be mounted or is busy)"
            fi
            return
            ;;
        6)
            print_section "Removing auto-mount fstab entries added by this tool..."
            if ! grep -q "Added by setup.sh auto-mount" /etc/fstab 2>/dev/null; then
                print_warning "No entries added by this tool found in /etc/fstab"
                return
            fi
            # Backup first
            sudo cp /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d_%H%M%S)"
            # Remove blocks from '# Added by setup.sh' comment to next blank line
            sudo python3 - /etc/fstab <<'PYCLEAN'
import sys, re
with open(sys.argv[1]) as f:
    content = f.read()
# Remove sections that start with "# Added by setup.sh auto-mount"
cleaned = re.sub(
    r'\n# Added by setup\.sh auto-mount.*?(?=\n[^#\n]|\Z)',
    '',
    content,
    flags=re.DOTALL
)
with open(sys.argv[1], 'w') as f:
    f.write(cleaned)
print("Done.")
PYCLEAN
            _mnt_ok "Removed auto-mount entries from /etc/fstab"
            sudo systemctl daemon-reload 2>/dev/null || true
            return
            ;;
    esac

    # ── For options 1, 2, 3 ───────────────────────────────────────────────────
    local do_fstab=false do_udev=false
    case "$_mnt_choice" in
        1) do_fstab=false; do_udev=false ;;
        2) do_fstab=true;  do_udev=true  ;;
        3) do_fstab=false; do_udev=true  ;;
    esac

    print_section "Step 1/5 — Installing filesystem drivers..."
    _mnt_ensure_drivers

    print_section "Step 2/5 — Scanning block devices..."
    _mnt_show_drive_table

    # Backup fstab before touching it
    if $do_fstab; then
        local fstab_bak="/etc/fstab.bak.$(date +%Y%m%d_%H%M%S)"
        sudo cp /etc/fstab "$fstab_bak"
        _mnt_ok "fstab backed up to ${fstab_bak}"
    fi

    print_section "Step 3/5 — Mounting drives..."
    local mounted=0 skipped=0 failed=0
    local dev fstype sz label uuid mnt

    while IFS='|' read -r dev fstype sz label uuid mnt; do
        # Skip already-mounted, swap, system partitions
        if [[ -n "$mnt" ]]; then
            _mnt_info "$(basename "$dev") already mounted at ${mnt} — skipping."
            skipped=$((skipped + 1))
            continue
        fi

        # Skip loop devices and CD-ROMs
        if [[ "$dev" == /dev/loop* || "$dev" == /dev/sr* || "$dev" == /dev/zram* ]]; then
            _mnt_info "$(basename "$dev") is a loop/optical/zram device — skipping."
            skipped=$((skipped + 1))
            continue
        fi

        # Skip boot and EFI partitions (protect the system!)
        if [[ "$fstype" == "vfat" ]] && lsblk -rno PARTTYPE "$dev" 2>/dev/null \
                | grep -qi "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"; then
            _mnt_info "$(basename "$dev") is EFI System Partition — skipping."
            skipped=$((skipped + 1))
            continue
        fi
        if sudo file -sL "$dev" 2>/dev/null | grep -qi "boot sector"; then
            _mnt_info "$(basename "$dev") looks like a boot partition — skipping."
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

    print_section "Step 4/5 — USB plug-and-play setup..."
    if $do_udev; then
        _mnt_setup_polkit
        _mnt_setup_udev
        _mnt_info "Enabling udisks2 service..."
        sudo systemctl enable --now udisks2 2>/dev/null \
            && _mnt_ok "udisks2 is running." \
            || _mnt_warn "udisks2 enable failed (may already be active)."
    else
        _mnt_info "Skipped (choose option 2 or 3 to enable USB auto-mount)."
    fi

    print_section "Step 5/5 — Applying and verifying..."
    if $do_fstab; then
        _mnt_reload_systemd
    fi

    # ── Summary ───────────────────────────────────────────────────────────────
    echo ""
    _mnt_sep
    echo -e "  Mount Summary:${NC}"
    echo -e "    ${GREEN}Mounted:${NC}  ${mounted}"
    echo -e "    ${YELLOW}Skipped:${NC}  ${skipped}"
    echo -e "    ${RED}Failed:${NC}   ${failed}"
    _mnt_sep
    echo ""
    echo -e "  Current mounts in /mnt:${NC}"
    findmnt --real -o TARGET,SOURCE,FSTYPE,SIZE,OPTIONS \
        --target /mnt 2>/dev/null | head -30 || true
    echo ""

    if $do_fstab; then
        echo -e "  ${CYAN}Drives will remount automatically on every boot.${NC}"
        echo -e "  ${CYAN}To undo: run option 18 → sub-option 6 (Remove fstab entries).${NC}"
    else
        echo -e "  ${YELLOW}Note: Mounts are SESSION ONLY (no fstab). Reboot will lose them.${NC}"
        echo -e "  ${YELLOW}Run again and choose option 2 to make them permanent.${NC}"
    fi
    echo ""
    log "Auto-mount complete: mounted=$mounted skipped=$skipped failed=$failed fstab=$do_fstab"
}

#===========================================
# NOOBS GUIDE — Friendly First-Time Setup
#===========================================

_nb_header() {
    echo ""
        echo ""
}

_nb_tip() {
    echo -e "  ${YELLOW}💡 Tip:${NC} $*"
}

_nb_step() {
    echo -e "  ${GREEN}▶  Step $1:${NC} $2"
}

_nb_explain() {
    echo -e "  ${CYAN}ℹ  ${NC}$*"
}

_nb_warn() {
    echo -e "  ${RED}⚠  ${NC}$*"
}

_nb_pause() {
    echo ""
    echo -e "  Press Enter to continue, or type 'q' to return to menu...${NC}"
    read -r _nb_input
    [[ "$_nb_input" == "q" ]] && return 1
    return 0
}

# ── Individual guide sections ─────────────────────────────────────────────────

_nb_guide_welcome() {
    _nb_header "Welcome to Fedora Linux! 🎉"

    echo -e "  Congratulations on installing Fedora! Here's what you need to know:"
    echo ""
    echo -e "  What is Fedora?${NC}"
    _nb_explain "Fedora is a free, open-source Linux distribution sponsored by Red Hat."
    _nb_explain "It's known for being cutting-edge, stable, and security-focused."
    _nb_explain "KDE Plasma is the desktop environment — it looks and feels like Windows,"
    _nb_explain "but it's completely different under the hood (and much more powerful)."
    echo ""

    echo -e "  What is this setup script?${NC}"
    _nb_explain "This script automates everything a new user needs to do after installing"
    _nb_explain "Fedora — from installing software to hardening security. Use the menu"
    _nb_explain "options one by one, or choose option 1 to do everything at once."
    echo ""

    echo -e "  Golden rules for new Linux users:${NC}"
    echo -e "    ${GREEN}1)${NC} Never run this script as root (it handles sudo itself)"
    echo -e "    ${GREEN}2)${NC} Read what a command does before running it"
    echo -e "    ${GREEN}3)${NC} The terminal is your best friend — don't be scared of it"
    echo -e "    ${GREEN}4)${NC} Google is your co-pilot — the Fedora community is huge"
    echo -e "    ${GREEN}5)${NC} Back up your /home folder regularly"
    echo ""

    _nb_tip "The Fedora forums (discussion.fedoraproject.org) are extremely friendly to beginners!"
    _nb_pause || return
}

_nb_guide_terminal() {
    _nb_header "Using the Terminal 💻"

    echo -e "  Opening a terminal:${NC}"
    _nb_explain "Right-click the desktop → Open Terminal"
    _nb_explain "Or press: Ctrl + Alt + T  (if configured)"
    _nb_explain "Or search for 'Konsole' in the app menu (KDE's default terminal)"
    echo ""

    echo -e "  Essential terminal commands:${NC}"
    printf "  %-35s %s\n" "COMMAND" "WHAT IT DOES"
    echo "  ─────────────────────────────────────────────────────────────"
    printf "  ${GREEN}%-35s${NC} %s\n" "ls"                    "List files in current directory"
    printf "  ${GREEN}%-35s${NC} %s\n" "ls -la"                "List files (detailed, including hidden)"
    printf "  ${GREEN}%-35s${NC} %s\n" "cd /path/to/folder"    "Change directory"
    printf "  ${GREEN}%-35s${NC} %s\n" "cd ~"                  "Go to your home directory"
    printf "  ${GREEN}%-35s${NC} %s\n" "cd .."                 "Go up one directory"
    printf "  ${GREEN}%-35s${NC} %s\n" "pwd"                   "Show current directory path"
    printf "  ${GREEN}%-35s${NC} %s\n" "mkdir myfolder"        "Create a new folder"
    printf "  ${GREEN}%-35s${NC} %s\n" "cp file1 file2"        "Copy a file"
    printf "  ${GREEN}%-35s${NC} %s\n" "mv file1 file2"        "Move/rename a file"
    printf "  ${GREEN}%-35s${NC} %s\n" "rm file"               "Delete a file"
    printf "  ${GREEN}%-35s${NC} %s\n" "rm -rf folder"         "Delete a folder (careful!)"
    printf "  ${GREEN}%-35s${NC} %s\n" "cat file.txt"          "Show file contents"
    printf "  ${GREEN}%-35s${NC} %s\n" "nano file.txt"         "Edit a file (easy text editor)"
    printf "  ${GREEN}%-35s${NC} %s\n" "clear"                 "Clear the terminal screen"
    printf "  ${GREEN}%-35s${NC} %s\n" "history"               "Show command history"
    printf "  ${GREEN}%-35s${NC} %s\n" "man ls"                "Show manual for any command"
    printf "  ${GREEN}%-35s${NC} %s\n" "Ctrl + C"              "Cancel/stop a running command"
    printf "  ${GREEN}%-35s${NC} %s\n" "Ctrl + L"              "Clear screen (same as clear)"
    printf "  ${GREEN}%-35s${NC} %s\n" "Tab"                   "Auto-complete filenames/commands"
    printf "  ${GREEN}%-35s${NC} %s\n" "↑ arrow"               "Previous command in history"
    echo ""

    _nb_tip "You can copy-paste in Konsole with Ctrl+Shift+C and Ctrl+Shift+V"
    _nb_pause || return
}

_nb_guide_packages() {
    _nb_header "Installing Software on Fedora 📦"

    echo -e "  There are 3 main ways to install software:${NC}"
    echo ""

    echo -e "  ${GREEN}1) DNF — The main package manager${NC}"
    _nb_explain "Like an App Store for the terminal. Most software is here."
    echo ""
    printf "  %-45s %s\n" "COMMAND" "WHAT IT DOES"
    echo "  ─────────────────────────────────────────────────────────────"
    printf "  ${CYAN}%-45s${NC} %s\n" "sudo dnf install firefox"      "Install Firefox"
    printf "  ${CYAN}%-45s${NC} %s\n" "sudo dnf remove firefox"       "Uninstall Firefox"
    printf "  ${CYAN}%-45s${NC} %s\n" "sudo dnf update"               "Update ALL software"
    printf "  ${CYAN}%-45s${NC} %s\n" "sudo dnf search vlc"           "Search for VLC"
    printf "  ${CYAN}%-45s${NC} %s\n" "sudo dnf info vlc"             "Show info about VLC"
    printf "  ${CYAN}%-45s${NC} %s\n" "dnf list installed"            "List installed packages"
    echo ""

    echo -e "  ${GREEN}2) Flatpak — Universal app packages (sandboxed)${NC}"
    _nb_explain "Flatpak apps are self-contained and work on any Linux distro."
    _nb_explain "Good for apps that aren't in the DNF repo (e.g. Discord, VSCode)."
    echo ""
    printf "  ${CYAN}%-45s${NC} %s\n" "flatpak install flathub com.discordapp.Discord" "Install Discord"
    printf "  ${CYAN}%-45s${NC} %s\n" "flatpak uninstall com.discordapp.Discord"        "Uninstall it"
    printf "  ${CYAN}%-45s${NC} %s\n" "flatpak update"                                  "Update all Flatpaks"
    echo ""

    echo -e "  ${GREEN}3) RPM files — Like .exe files on Windows${NC}"
    _nb_explain "If a website gives you a .rpm file (e.g. Google Chrome), install it with:"
    printf "  ${CYAN}%-45s${NC}\n" "sudo dnf install ./google-chrome.rpm"
    echo ""

    _nb_tip "Always prefer DNF over downloading random files from the internet!"
    _nb_tip "This script's option 2 sets up extra repos (RPM Fusion) for more software like VLC."
    _nb_pause || return
}

_nb_guide_sudo() {
    _nb_header "Understanding sudo & Permissions 🔐"

    echo -e "  What is sudo?${NC}"
    _nb_explain "'sudo' means 'superuser do' — it temporarily grants admin power."
    _nb_explain "It's like 'Run as Administrator' on Windows, but safer."
    _nb_explain "You'll be asked for YOUR password (not a root password)."
    echo ""

    echo -e "  Why NOT to use sudo all the time:${NC}"
    _nb_warn "Running random commands with sudo can break your system!"
    _nb_warn "Never paste sudo commands from the internet without reading them first."
    _nb_explain "Good rule: only use sudo when you get a 'Permission denied' error"
    _nb_explain "and you know why you need elevated access."
    echo ""

    echo -e "  File permissions explained:${NC}"
    echo ""
    echo -e "  When you run ${CYAN}ls -la${NC}, you see something like:"
    echo -e "  ${GREEN}-rwxr-xr-x  1 alice  alice  12345  script.sh${NC}"
    echo ""
    echo -e "  The permission string ${CYAN}-rwxr-xr-x${NC} means:"
    echo -e "    ${WHITE}r${NC} = read    ${WHITE}w${NC} = write    ${WHITE}x${NC} = execute    ${WHITE}-${NC} = no permission"
    echo -e "    Position 1:    file type (- = file, d = directory, l = symlink)"
    echo -e "    Positions 2-4: ${CYAN}owner${NC} permissions  (you)"
    echo -e "    Positions 5-7: ${CYAN}group${NC} permissions  (your group)"
    echo -e "    Positions 8-10:${CYAN}others${NC} permissions (everyone else)"
    echo ""
    printf "  %-30s %s\n" "COMMAND" "WHAT IT DOES"
    echo "  ──────────────────────────────────────────────────"
    printf "  ${CYAN}%-30s${NC} %s\n" "chmod +x script.sh"   "Make a file executable"
    printf "  ${CYAN}%-30s${NC} %s\n" "chmod 644 file.txt"   "Owner: rw, Group: r, Others: r"
    printf "  ${CYAN}%-30s${NC} %s\n" "chmod 755 folder"     "Owner: rwx, Group: rx, Others: rx"
    printf "  ${CYAN}%-30s${NC} %s\n" "chown alice file.txt" "Change file owner to alice"
    echo ""
    _nb_pause || return
}

_nb_guide_updates() {
    _nb_header "Keeping Your System Updated 🔄"

    echo -e "  Why updates matter:${NC}"
    _nb_explain "Updates fix security holes, bugs, and add new features."
    _nb_explain "On Linux, updates are safe and won't break your system (usually)."
    _nb_explain "Unlike Windows, Linux updates don't require reboots (except kernel)."
    echo ""

    echo -e "  How to update:${NC}"
    echo ""
    printf "  ${GREEN}%-40s${NC} %s\n" "sudo dnf update"          "Update everything"
    printf "  ${GREEN}%-40s${NC} %s\n" "sudo dnf update --refresh" "Force refresh repos first"
    printf "  ${GREEN}%-40s${NC} %s\n" "flatpak update"           "Update Flatpak apps separately"
    printf "  ${GREEN}%-40s${NC} %s\n" "sudo dnf autoremove"      "Remove unused dependencies"
    printf "  ${GREEN}%-40s${NC} %s\n" "sudo dnf clean all"       "Clear the package cache"
    echo ""

    echo -e "  Automatic updates:${NC}"
    _nb_explain "This script's option 16 (JShielder) can set up automatic security updates."
    _nb_explain "Alternatively, enable GNOME Software / Discover to auto-update in the background."
    echo ""

    echo -e "  After a kernel update:${NC}"
    _nb_tip "Reboot after a kernel update to start using the new kernel."
    _nb_tip "Your old kernel is kept as a fallback — accessible from the GRUB boot menu."
    echo ""
    _nb_pause || return
}

_nb_guide_kde() {
    _nb_header "Getting Around KDE Plasma 🖥️"

    echo -e "  KDE Plasma essentials:${NC}"
    echo ""
    printf "  %-30s %s\n" "SHORTCUT/ELEMENT" "WHAT IT DOES"
    echo "  ──────────────────────────────────────────────────────────"
    printf "  ${GREEN}%-30s${NC} %s\n" "Super key (Windows key)"      "Open application launcher"
    printf "  ${GREEN}%-30s${NC} %s\n" "Alt + F2"                     "Run command dialog"
    printf "  ${GREEN}%-30s${NC} %s\n" "Ctrl + Alt + T"               "Open terminal (if set)"
    printf "  ${GREEN}%-30s${NC} %s\n" "Alt + F4"                     "Close window"
    printf "  ${GREEN}%-30s${NC} %s\n" "Super + D"                    "Show desktop"
    printf "  ${GREEN}%-30s${NC} %s\n" "Super + L"                    "Lock screen"
    printf "  ${GREEN}%-30s${NC} %s\n" "Print Screen"                 "Take a screenshot"
    printf "  ${GREEN}%-30s${NC} %s\n" "Right-click desktop"          "Desktop context menu"
    printf "  ${GREEN}%-30s${NC} %s\n" "System Settings"              "All KDE settings (like Control Panel)"
    printf "  ${GREEN}%-30s${NC} %s\n" "Dolphin"                      "File manager (like Explorer)"
    printf "  ${GREEN}%-30s${NC} %s\n" "Konsole"                      "Terminal emulator"
    printf "  ${GREEN}%-30s${NC} %s\n" "Discover"                     "Graphical app store"
    echo ""

    echo -e "  Customising KDE:${NC}"
    _nb_explain "Right-click the taskbar → Edit Panel to add/remove items"
    _nb_explain "System Settings → Appearance → Global Theme to change the look"
    _nb_explain "System Settings → Workspace → Desktop Effects for animations"
    echo ""

    echo -e "  Virtual desktops (multiple workspaces):${NC}"
    _nb_explain "KDE supports multiple virtual desktops — like having multiple screens."
    _nb_explain "Use Ctrl+F1/F2/F3 to switch between them."
    _nb_explain "Right-click the taskbar → Add Widget → Pager to see them visually."
    echo ""
    _nb_pause || return
}

_nb_guide_files() {
    _nb_header "File System Layout 📂"

    echo -e "  Linux directory structure (different from Windows!):${NC}"
    echo ""
    printf "  %-20s %s\n" "DIRECTORY" "PURPOSE"
    echo "  ──────────────────────────────────────────────────────────────────"
    printf "  ${CYAN}%-20s${NC} %s\n" "/"             "Root — the top of everything (like C:\\ on Windows)"
    printf "  ${CYAN}%-20s${NC} %s\n" "/home/YOU"     "YOUR personal folder — where all your stuff lives"
    printf "  ${CYAN}%-20s${NC} %s\n" "/etc"          "System configuration files (be careful here)"
    printf "  ${CYAN}%-20s${NC} %s\n" "/usr"          "Programs and libraries installed system-wide"
    printf "  ${CYAN}%-20s${NC} %s\n" "/bin /usr/bin" "Executable programs (ls, cat, dnf, etc.)"
    printf "  ${CYAN}%-20s${NC} %s\n" "/tmp"          "Temporary files — wiped on reboot"
    printf "  ${CYAN}%-20s${NC} %s\n" "/var"          "Variable data (logs, caches, databases)"
    printf "  ${CYAN}%-20s${NC} %s\n" "/var/log"      "System logs — check here when things break"
    printf "  ${CYAN}%-20s${NC} %s\n" "/mnt"          "Where extra drives are mounted (this script uses it)"
    printf "  ${CYAN}%-20s${NC} %s\n" "/media"        "Where USB drives auto-mount via KDE"
    printf "  ${CYAN}%-20s${NC} %s\n" "/dev"          "Device files (disks, USB ports, etc.)"
    printf "  ${CYAN}%-20s${NC} %s\n" "/proc"         "Virtual filesystem — running processes"
    printf "  ${CYAN}%-20s${NC} %s\n" "/sys"          "Virtual filesystem — hardware info"
    echo ""

    echo -e "  Hidden files:${NC}"
    _nb_explain "Files starting with . are hidden (like .bashrc, .config, .ssh)"
    _nb_explain "In Dolphin: press Ctrl+H to show hidden files"
    _nb_explain "In terminal: ls -la shows hidden files"
    echo ""

    _nb_tip "Your browser downloads, documents, etc. live in /home/YOUR_USERNAME/"
    _nb_tip "Back up your /home folder — everything else can be reinstalled from scratch"
    _nb_pause || return
}

_nb_guide_networking() {
    _nb_header "Networking on Fedora 🌐"

    echo -e "  Check your connection:${NC}"
    echo ""
    printf "  ${GREEN}%-35s${NC} %s\n" "ip addr"                  "Show all IP addresses"
    printf "  ${GREEN}%-35s${NC} %s\n" "ip route"                 "Show network routes"
    printf "  ${GREEN}%-35s${NC} %s\n" "nmcli general status"     "Show NetworkManager status"
    printf "  ${GREEN}%-35s${NC} %s\n" "nmcli connection show"    "Show saved connections"
    printf "  ${GREEN}%-35s${NC} %s\n" "ping 8.8.8.8"            "Test internet (Ctrl+C to stop)"
    printf "  ${GREEN}%-35s${NC} %s\n" "ping google.com"          "Test DNS + internet"
    printf "  ${GREEN}%-35s${NC} %s\n" "curl ifconfig.me"         "Show your public IP"
    printf "  ${GREEN}%-35s${NC} %s\n" "ss -tulnp"                "Show open ports"
    echo ""

    echo -e "  Connect to WiFi from terminal:${NC}"
    printf "  ${CYAN}%-45s${NC} %s\n" "nmcli device wifi list"               "Scan for WiFi networks"
    printf "  ${CYAN}%-45s${NC} %s\n" "nmcli device wifi connect 'MyWiFi' password 'mypass'" ""
    echo ""

    echo -e "  Firewall (firewalld — Fedora's default):${NC}"
    printf "  ${CYAN}%-45s${NC} %s\n" "sudo firewall-cmd --state"                    "Check if firewall is running"
    printf "  ${CYAN}%-45s${NC} %s\n" "sudo firewall-cmd --list-all"                 "Show all rules"
    printf "  ${CYAN}%-45s${NC} %s\n" "sudo firewall-cmd --add-service=http --perm"  "Allow HTTP permanently"
    printf "  ${CYAN}%-45s${NC} %s\n" "sudo firewall-cmd --add-port=8080/tcp --perm" "Allow port 8080"
    echo ""

    _nb_tip "KDE's network icon in the taskbar handles WiFi and VPN visually."
    _nb_pause || return
}

_nb_guide_troubleshoot() {
    _nb_header "Troubleshooting Common Problems 🔧"

    echo -e "  System won't boot:${NC}"
    _nb_explain "At the GRUB boot menu (hold Shift during boot), select a previous kernel."
    _nb_explain "Then: sudo dnf remove <bad-package> or sudo dnf distro-sync"
    echo ""

    echo -e "  Package manager is broken:${NC}"
    printf "  ${CYAN}%-40s${NC} %s\n" "sudo dnf clean all"          "Clear package cache"
    printf "  ${CYAN}%-40s${NC} %s\n" "sudo dnf distro-sync"        "Resync with repos"
    printf "  ${CYAN}%-40s${NC} %s\n" "sudo rpm --rebuilddb"        "Rebuild RPM database"
    echo ""

    echo -e "  Permission denied errors:${NC}"
    _nb_explain "You're trying to access something without proper permissions."
    _nb_explain "Check ownership: ls -la <file>"
    _nb_explain "Fix: sudo chown -R \$USER:\$USER /path/to/folder"
    echo ""
    echo -e "  WiFi not working:${NC}"
    printf "  ${CYAN}%-40s${NC}\n" "sudo systemctl restart NetworkManager"
    printf "  ${CYAN}%-40s${NC}\n" "nmcli radio wifi on"
    _nb_explain "If WiFi is missing: check 'lspci' for your chipset, then install drivers"
    echo ""

    echo -e "  Check logs for errors:${NC}"
    printf "  ${CYAN}%-40s${NC} %s\n" "journalctl -xe"              "Show recent system errors"
    printf "  ${CYAN}%-40s${NC} %s\n" "journalctl -u NetworkManager" "Logs for a specific service"
    printf "  ${CYAN}%-40s${NC} %s\n" "dmesg | tail -30"           "Kernel messages"
    printf "  ${CYAN}%-40s${NC} %s\n" "sudo cat /var/log/dnf.log"  "DNF package manager log"
    echo ""

    echo -e "  App crashes or freezes:${NC}"
    _nb_explain "Open Konsole → type the app name to run it there — you'll see error output."
    _nb_explain "Or: journalctl -f (watch live logs while you reproduce the crash)"
    echo ""

    _nb_tip "The Fedora Ask community (ask.fedoraproject.org) solves 99% of problems!"
    _nb_pause || return
}

_nb_guide_recommended_apps() {
    _nb_header "Recommended Apps for Beginners 🚀"

    echo -e "  Web browsers:${NC}"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Firefox"         "(pre-installed)" "Best privacy, Fedora default"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Brave Browser"   "(Flatpak)"       "Privacy-focused, blocks ads"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Zen Browser"     "(Flatpak)"       "Fast, modern Firefox fork"
    echo ""
    echo -e "  Office & Productivity:${NC}"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "LibreOffice"     "(DNF)"           "Full MS Office alternative"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "OnlyOffice"      "(Flatpak)"       "Best .docx/.xlsx compatibility"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Obsidian"        "(Flatpak)"       "Markdown notes / knowledge base"
    echo ""
    echo -e "  Media:${NC}"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "VLC"             "(Flatpak)"       "Plays everything"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Mixxx"           "(Flatpak)"       "DJ / music mixing"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Kdenlive"        "(DNF/Flatpak)"   "Video editor"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "GIMP"            "(DNF)"           "Image editor (like Photoshop)"
    echo ""
    echo -e "  Communication:${NC}"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Thunderbird"     "(DNF)"           "Email client"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Discord"         "(Flatpak)"       "Voice + text chat"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Signal"          "(Flatpak)"       "Encrypted messaging"
    echo ""
    echo -e "  Development:${NC}"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "VS Code"         "(Flatpak)"       "Best code editor"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Podman Desktop"  "(Flatpak)"       "Containers (like Docker)"
    echo ""
    echo -e "  System tools:${NC}"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "KDE System Monitor" "(built-in)"   "Task Manager equivalent"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "Baobab"          "(DNF)"           "Disk usage analyser"
    printf "  ${GREEN}%-25s${NC} %-15s %s\n" "LACT"            "(Flatpak)"       "GPU overclocking (AMD/NVIDIA)"
    echo ""

    _nb_tip "This script's options 3 and 4 install many of these automatically!"
    _nb_pause || return
}

_nb_guide_this_script() {
    _nb_header "How to Use This Setup Script 📋"

    echo -e "  Recommended order for a fresh Fedora install:${NC}"
    echo ""
    _nb_step "1" "Option 2  — Setup Repositories (RPM Fusion + Flathub)"
    _nb_explain "  Adds extra software sources. Do this FIRST before installing anything."
    echo ""
    _nb_step "2" "Option 3  — Install DNF Packages"
    _nb_explain "  Installs essential CLI tools, dev tools, games support, and fonts."
    echo ""
    _nb_step "3" "Option 4  — Install Flatpak Apps"
    _nb_explain "  Installs VS Code, VLC, browser, gaming tools, and more."
    echo ""
    _nb_step "4" "Option 9  — Install Nerd Fonts"
    _nb_explain "  Required for Oh My Posh and Fastfetch to look correct."
    echo ""
    _nb_step "5" "Option 7  — Install Oh My Posh"
    _nb_explain "  Gives your terminal a beautiful, information-rich prompt."
    echo ""
    _nb_step "6" "Option 8  — Configure Fastfetch"
    _nb_explain "  Shows a cool system info display when you open a terminal."
    echo ""
    _nb_step "7" "Option 18 — Auto Mount Drives"
    _nb_explain "  Mount all your NTFS/ext4/exFAT drives and set up USB auto-mount."
    echo ""
    _nb_step "8" "Option 14 — ClamAV Antivirus"
    _nb_explain "  Optional but recommended. Scans for malware."
    echo ""
    _nb_step "9" "Option 15 — Linux Security Hardening"
    _nb_explain "  Sets up firewall, fail2ban, SELinux. Recommended for internet-facing use."
    echo ""
    _nb_step "10" "Option 17 — Privacy & Network"
    _nb_explain "  Set up Tor, WireGuard VPN, Yggdrasil mesh, DNS-over-TLS."
    echo ""

    _nb_warn "Option 16 (JShielder) is for advanced users — read what it does first!"
    echo ""
    _nb_tip "Option 1 (Install EVERYTHING) runs all of the above in one go."
    _nb_pause || return
}

# ── Noobs menu ─────────────────────────────────────────────────────────────────
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
        # The official non-interactive install
        NONINTERACTIVE=1 /bin/bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
            2>&1 | tee -a "$LOG_FILE"
    fi

    # Detect install path (Intel vs ARM / Linuxbrew default)
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

    print_section "Configuring shell environment"
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

    # Activate in current session
    eval "$brew_shellenv"

    print_section "Running brew update & doctor"
    brew update 2>&1 | tee -a "$LOG_FILE"
    brew doctor 2>&1 | tee -a "$LOG_FILE" || true   # doctor exits non-zero on warnings

    print_success "Homebrew installed and configured!"
    print_warning "Restart your terminal (or run: eval \"\$(brew shellenv)\") to activate brew."
    log "Homebrew setup complete"
}

#===========================================
# WINBOAT
#===========================================

install_winboat() {
    print_header "Install Winboat"

    # Winboat is distributed via the Terra (fyralabs) repository.
    # Make sure Terra is available before trying to install.
    if ! dnf repolist 2>/dev/null | grep -q "terra"; then
        print_warning "Terra repository not found — adding it now (required for Winboat)."
        setup_repositories
    fi

    if rpm -q winboat &>/dev/null; then
        print_warning "Winboat is already installed."
        if ! confirm_action "Reinstall / upgrade Winboat?"; then
            return
        fi
    fi

    print_section "Installing Winboat via DNF (Terra repo)"
    if sudo dnf install -y winboat 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Winboat installed successfully!"
        log "Winboat installed"
    else
        print_error "DNF install failed — trying Flatpak fallback..."
        # Flatpak fallback in case the Terra package is unavailable for this Fedora version
        if flatpak install -y flathub net.davidotek.pupgui2 2>&1 | tee -a "$LOG_FILE"; then
            print_success "ProtonUp-Qt (Flatpak) installed as Winboat alternative."
            log "ProtonUp-Qt installed as Winboat fallback"
        else
            print_error "Both install methods failed — check $LOG_FILE"
            log "Winboat install failed"
            return 1
        fi
    fi
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
    echo -e "  ${WHITE}1) JaKooLit${NC}  — Cyberpunk/Neon aesthetic. Fedora-native installer,"
    echo    "             full whiptail wizard, NVIDIA support, Waybar + Rofi + SDDM."
    echo    "             ★ Best pick for Fedora. Actively maintained."
    echo    "             https://github.com/JaKooLit/Fedora-Hyprland"
    echo ""
    echo -e "  ${WHITE}2) ML4W${NC}      — Professional glass/material theme. Adaptive colors"
    echo    "             based on your wallpaper. GUI settings app included."
    echo    "             Officially supports Fedora + Arch + openSUSE."
    echo    "             https://github.com/mylinuxforwork/dotfiles"
    echo ""
    echo -e "  ${WHITE}3) end-4${NC}     — Most starred on GitHub (~14k ⭐). GNOME-like UX,"
    echo    "             AI sidebar (ChatGPT/Gemini), live color generation,"
    echo    "             fancy notifications and music controls."
    echo    "             https://github.com/end-4/dots-hyprland"
    echo ""
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

# ── Preset 1: JaKooLit ─────────────────────────────────────────────────────
_hyprland_jakoolit() {
    print_section "JaKooLit — Fedora Hyprland Installer"

    echo ""
    echo -e "${CYAN}  About JaKooLit:${NC}"
    echo "  • Cyberpunk / Neon Circuit Waybar aesthetic"
    echo "  • Interactive whiptail wizard — choose exactly what to install"
    echo "  • Built-in NVIDIA driver support"
    echo "  • SDDM login manager + GTK/icon themes"
    echo "  • Quickshell overview (SUPER+A), searchable keybinds (SUPER+H)"
    echo "  • Pulls dotfiles from: https://github.com/JaKooLit/Hyprland-Dots"
    echo ""
    echo -e "${YELLOW}  Requirements:${NC}"
    echo "  • Run a full 'sudo dnf update' and reboot BEFORE this installer"
    echo "  • Do NOT run as root"
    echo "  • NVIDIA users: uninstall nouveau first if using proprietary drivers"
    echo ""

    if ! confirm_action "Clone and launch JaKooLit Fedora-Hyprland installer?"; then
        print_warning "Cancelled."
        return
    fi

    local INSTALL_DIR="$HOME/Fedora-Hyprland"

    if [[ -d "$INSTALL_DIR" ]]; then
        print_warning "Directory $INSTALL_DIR already exists — pulling latest..."
        git -C "$INSTALL_DIR" pull 2>&1 | tee -a "$LOG_FILE"
    else
        print_section "Cloning JaKooLit Fedora-Hyprland..."
        git clone --depth=1 https://github.com/JaKooLit/Fedora-Hyprland.git "$INSTALL_DIR" \
            2>&1 | tee -a "$LOG_FILE"
    fi

    chmod +x "$INSTALL_DIR/install.sh"

    print_section "Launching JaKooLit installer (interactive whiptail wizard)..."
    echo -e "${YELLOW}  The installer will now take over. Follow the on-screen prompts.${NC}"
    echo ""
    sleep 2

    cd "$INSTALL_DIR" && bash install.sh
    log "JaKooLit Fedora-Hyprland installer launched"
}

# ── Preset 2: ML4W ─────────────────────────────────────────────────────────
_hyprland_ml4w() {
    print_section "ML4W — Professional Hyprland Dotfiles"

    echo ""
    echo -e "${CYAN}  About ML4W:${NC}"
    echo "  • Glass / material color theme — adapts to your wallpaper"
    echo "  • GUI settings app (toggle borders, blur, animations without editing code)"
    echo "  • Global Glass Waybar with center workspace selector"
    echo "  • Officially supports Fedora, Arch, openSUSE Tumbleweed"
    echo "  • Dotfiles installer app with full setup scripts"
    echo "  • Repo: https://github.com/mylinuxforwork/dotfiles"
    echo ""
    echo -e "${YELLOW}  Requirements:${NC}"
    echo "  • Wayland session required (no X11)"
    echo "  • Recommended: fresh/minimal Fedora install"
    echo ""

    if ! confirm_action "Launch ML4W stable installer?"; then
        print_warning "Cancelled."
        return
    fi

    print_section "Launching ML4W installer..."
    echo -e "${YELLOW}  Fetching and running the ML4W stable install script...${NC}"
    echo ""
    sleep 1

    bash <(curl -s https://ml4w.com/os/stable) 2>&1 | tee -a "$LOG_FILE"
    log "ML4W Hyprland installer launched"
}

# ── Preset 3: end-4 (illogical-impulse) ────────────────────────────────────
_hyprland_end4() {
    print_section "end-4 — illogical-impulse Hyprland Dotfiles"

    echo ""
    echo -e "${CYAN}  About end-4:${NC}"
    echo "  • Most starred Hyprland dotfiles on GitHub (~14k ⭐)"
    echo "  • GNOME-like UX — familiar keybinds for Windows/GNOME users"
    echo "  • AI sidebar: ChatGPT & Gemini integrated on your desktop"
    echo "  • Live adaptive color generation from wallpaper"
    echo "  • Fancy notification center, music controls, calendar widget"
    echo "  • Quickshell-based status bar and sidebars"
    echo "  • Hit Super+/ for a full keybind cheat-sheet"
    echo "  • Repo: https://github.com/end-4/dots-hyprland"
    echo ""
    echo -e "${YELLOW}  Requirements:${NC}"
    echo "  • Arch-based distro recommended; Fedora support is community-maintained"
    echo "  • curl must be installed (already in your DNF packages)"
    echo ""
    echo -e "${RED}  Note: end-4 targets Arch primarily. On Fedora some packages may need${NC}"
    echo -e "${RED}  manual adjustment. Proceed with that in mind.${NC}"
    echo ""

    if ! confirm_action "Launch end-4 installer?"; then
        print_warning "Cancelled."
        return
    fi

    print_section "Launching end-4 installer..."
    echo -e "${YELLOW}  Fetching and running the end-4 install script...${NC}"
    echo ""
    sleep 1

    bash <(curl -s https://ii.clsty.link/get) 2>&1 | tee -a "$LOG_FILE"
    log "end-4 illogical-impulse Hyprland installer launched"
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
    echo "================================================="
    echo ""
    echo "  1)  Install EVERYTHING"
    echo ""
    echo "  -- Package Installation --"
    echo "  2)  Setup Repositories (RPM Fusion, Flathub, Terra (fyralabs) Repo)"
    echo "  3)  Install DNF Packages"
    echo "  4)  Install Flatpak Applications"
    echo "  5)  Clone & Build GitHub Repos"
    echo "  6)  Install GitHub Releases"
    echo ""
    echo "  -- Shell & Terminal --"
    echo "  7)  Install Oh My Posh"
    echo "  8)  Configure Fastfetch"
    echo "  9)  Install Nerd Fonts"
    echo ""
    echo "  -- Development Tools --"
    echo "  10) Install Rust"
    echo "  11) Install NVM (Node Version Manager)"
    echo "  12) Install & Setup Homebrew (Linuxbrew)"
    echo "  13) Install Winboat"
    echo ""
    echo "  -- Drivers & Apps --"
    echo "  14) Install NVIDIA Drivers"
    echo "  15) Install AppImages (Helium, Capacities, Affinity Installer)"
    echo ""
    echo "  -- Security --"
    echo "  16) Install & Configure ClamAV Antivirus"
    echo "  17) Linux Security Hardening (Chris Titus)"
    echo "  18) JShielder -- Full System Hardening (KDE Edition)"
    echo ""
    echo "  -- Privacy & Network --"
    echo "  19) Privacy & Network Tools (Tor, MAC spoof, WireGuard, DNS-DoT)"
    echo ""
    echo "  -- Storage --"
    echo "  20) Auto Mount All Drives"
    echo ""
    echo "  -- Help & Learning --"
    echo "  21) NOOBS GUIDE -- Learn Fedora Linux"
    echo ""
    echo "  -- Extra Security: !!Use at your own Risk!! --"
    echo "  22) GRUB Hardening + Kernel Lockdown"
    echo "  23) Lynis -- Full Security Audit & Score"
    echo "  24) Disk Encryption Check + Encrypted Swap"
    echo "  25) Systemd Hardening + Immutable Files + Logwatch"
    echo ""
    echo "  -- Privacy Extras --"
    echo "  26) Harden Browser Privacy (Firefox / LibreWolf / Zen Browser)"
    echo ""
    echo "  -- Hacking Tools --"
    echo "  27) Hacking Tools -- Kali Linux Toolkit"
    echo ""
    echo "  -- Hyprland --"
    echo "  28) Install Hyprland + Dotfiles (JaKooLit / ML4W / end-4)"
    echo ""
    echo "  0)  Exit"
    echo ""
    read -rp "  Select an option [0-28]: " choice
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
    install_nerd_fonts
    install_oh_my_posh
    configure_fastfetch
    install_rust
    install_nvm
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
    echo -e "    3. Run 'nvm install --lts' to install Node.js"
    echo -e "    4. Open menu option 17 for Privacy & Network setup"
    echo -e "    5. Open menu option 18 to mount all your drives"
    echo -e "    6. Run option 22 — GRUB Hardening + Kernel Lockdown"
    echo -e "    7. Run option 23 — Lynis audit to check your hardening score"
    echo -e "    8. Run option 24 — verify/setup disk encryption"
    echo -e "    9. Run option 25 — systemd sandboxing + immutable files"
    echo -e "   10. Run option 26 — harden Firefox/LibreWolf browser"
    echo -e "   11. New to Linux? Visit menu option 19 — Noobs Guide!"
    echo ""
    echo -e "  ${CYAN}Enjoy your new Fedora setup!${NC}"
}

#===========================================
# MAIN
#===========================================

# Must not run as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Don't run this script as root!${NC}"
    echo -e "${YELLOW}Run as regular user. Script will ask for sudo when needed.${NC}"
    exit 1
fi

# Prime sudo once up front (single password prompt), then keep it alive
sudo -v
_sudo_keepalive

# Create directories
create_directories

echo "==> Fedora Complete Setup Script v2.6 — starting up"

# Main loop
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
        9)  install_nerd_fonts ;;
        10) install_rust ;;
        11) install_nvm ;;
        12) install_homebrew ;;
        13) install_winboat ;;
        14) install_nvidia_drivers ;;
        15) install_appimages ;;
        16) install_clamav ;;
        17) install_linux_hardening ;;
        18) install_jshielder_hardening ;;
        19) privacy_network_menu ;;
        20) automount_drives ;;
        21) noobs_guide_menu ;;
        22) install_grub_hardening ;;
        23) run_lynis_audit ;;
        24) check_and_setup_encryption ;;
        25) install_systemd_hardening ;;
        26) harden_browser_privacy ;;
        27) hacking_tools_menu ;;
        28) install_hyprland ;;
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
