<div align="center">

 <pre>
███████╗███████╗██████╗  ██████╗ ██████╗  █████╗
██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔══██╗██╔══██╗
█████╗  █████╗  ██║  ██║██║   ██║██████╔╝███████║
██╔══╝  ██╔══╝  ██║  ██║██║   ██║██╔══██╗██╔══██║
██║     ███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║
╚═╝     ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
</pre>

**A modular, interactive post-install setup script for Fedora Linux.**  
Packages · Security · Privacy · Dev Tools · Hyprland — all from one terminal menu.


![Fedora](https://img.shields.io/badge/Fedora-41%2B-blue?logo=fedora&logoColor=white)
![Shell](https://img.shields.io/badge/Shell-Bash-green?logo=gnubash&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Maintained](https://img.shields.io/badge/Maintained-Yes-brightgreen)

</div>

---

## What It Does

`setup.sh` is a single interactive Bash script that turns a fresh Fedora install into a fully configured workstation. Run it, pick options from the menu, and it handles the rest — repos, packages, drivers, hardening, privacy, and even a full Hyprland desktop.

---

## Quick Start

```bash
git clone https://github.com/ineednotitle/fedora-setup.git
cd fedora-setup
chmod +x setup.sh
./setup.sh
```

> **Do NOT run as root.** The script calls `sudo` internally only when needed and keeps the session alive automatically.

---

## Requirements

- Fedora **41 or newer** (tested on the KDE Spin)
- An active internet connection
- `git` and `curl`: `sudo dnf install -y git curl`
- A non-root user with `sudo` privileges

---

## Menu

<img width="1067" height="906" alt="image" src="https://github.com/user-attachments/assets/e68fc614-2aa1-4251-b421-037b76ebbc7c" />

---

## Feature Overview

### 1 — Install Everything

Runs options 2–17 in sequence for a full unattended setup. Hyprland (option 21) is excluded because its dotfile presets launch interactive wizards — run that separately after rebooting.

---

### 2 — Setup Repositories

Enables three extra repos before any packages are installed:

| Repo | Purpose |
|------|---------|
| **RPM Fusion** (free + non-free) | Codecs, proprietary drivers, extra packages |
| **Flathub** | Universal Flatpak app store |
| **Terra (fyralabs)** | Modern packages not yet in Fedora's official repos |

---

### 3–6 — Package Installation

All package lists live at the top of the script so they're easy to edit before running.

- **DNF packages** — development tools, fonts, games, utilities, and system packages — installed in a single transaction for speed
- **Flatpak apps** — communication, productivity, creativity, multimedia, browsers, and utilities — installed in one batch
- **GitHub repos** — clones and optionally builds repos you configure in `GITHUB_REPOS`
- **GitHub releases** — downloads the latest binary releases for tools like `lazygit`, `bat`, `ripgrep`, and `fzf` in parallel

---

### 7 — Oh My Posh

Installs [Oh My Posh](https://ohmyposh.dev/) and writes a prompt init line to `.bashrc` and `.zshrc`. Downloads the full theme library to `~/.config/oh-my-posh/themes/` — switch themes by editing your shell config.

### 8 — Configure Fastfetch

Writes a custom `~/.config/fastfetch/config.jsonc` with Kitty image protocol support for a photo logo, detailed system modules, and a clean colour block. Optionally adds `fastfetch` to `.bashrc` so it runs on every terminal launch.

---

### 9 — Homebrew (Linuxbrew)

Installs [Homebrew](https://brew.sh/) for Linux, adds it to your PATH in `.bashrc` and `.zshrc`, and runs `brew update` + `brew doctor` to confirm everything is healthy.

### 10 — Winboat

Installs [Winboat](https://github.com/bottlesdevs/Bottles) from the Terra repository for running Windows apps on Linux. Falls back to ProtonUp-Qt via Flatpak if the Terra package isn't available for your Fedora version.

---

### 11 — NVIDIA Drivers

Installs proprietary NVIDIA drivers from RPM Fusion with three modes to choose from:

| Mode | Package | Best for |
|------|---------|----------|
| Standard | `akmod-nvidia` | Most users — auto-rebuilds on kernel update |
| CUDA | `akmod-nvidia` + cuda libs | GPU compute / ML workloads |
| Open | `akmod-nvidia-open` | Turing (RTX 20xx) and newer |

Also optionally blacklists Nouveau and rebuilds initramfs with `dracut`.

### 12 — AppImages

Downloads and installs to `~/Applications/`:

| App | Description |
|-----|-------------|
| **Helium** | Lightweight Chromium-based browser |
| **Capacities** | Personal knowledge base / note-taking |
| **Linux Affinity Installer** | Runs Affinity Photo/Designer/Publisher via Wine |

---

### 13 — ClamAV

Installs and fully configures [ClamAV](https://www.clamav.net/):

- `clamd@scan` daemon + `freshclam` auto-updater enabled as systemd services
- Optional daily scan cron job at 1 AM with quarantine directory
- Optional desktop threat-notification script (checks every 5 min)
- Optional ClamTk graphical frontend

### 14 — Linux Security Hardening (Chris Titus)

Runs the [Chris Titus Tech](https://github.com/ChrisTitusTech/linux-titus) hardening script — sysctl kernel/network tweaks, SSH hardening, firewall rules, and a repository/GPG key audit. Each step can be toggled individually.

### 15 — JShielder (KDE Edition)

Full system hardening via [JShielder](https://github.com/Jsitech/JShielder) with automatic backups before every change:

- PAM password policies and account lockout
- Auditd with CIS rules
- Kernel and sysctl hardening
- Disabling unnecessary services
- SSH lockdown
- SELinux enforcement mode
- KDE-specific hardening steps

> Creates timestamped backups in `~/jshielder_backups_<date>/` before touching anything.

---

### 16 — Privacy & Network Tools

An interactive submenu:

| Tool | What it does |
|------|-------------|
| **Tor** | Routes traffic through the Tor network for anonymity |
| **MAC spoofing** | Randomises your MAC address on every boot via `macchanger` |
| **WireGuard VPN** | Imports an existing `.conf` or generates a keypair template |
| **DNS-over-TLS** | Configures `systemd-resolved` with NextDNS + Quad9 fallback |

---

### 17 — Auto Mount All Drives

Detects all unmounted block devices, shows a confirmation prompt per drive, and writes persistent `fstab` entries so they mount automatically on boot. Supports ext4, NTFS, exFAT, and other common filesystems.

---

### 18 — NOOBS GUIDE

An interactive in-terminal guide covering 11 topics for users new to Fedora:

- Terminal basics and navigation
- DNF and Flatpak package management
- Using `sudo` safely
- KDE Plasma tips and shortcuts
- Networking and Wi-Fi
- File system layout
- Troubleshooting and logs
- Recommended apps
- ...and more

---

### 19 — Browser Privacy Hardening

Applies privacy-focused settings to your existing browser profile:

| Browser | What's applied |
|---------|---------------|
| **Firefox** | Disables telemetry, enables strict tracking protection, sets DNS-over-HTTPS |
| **LibreWolf** | Verifies hardened defaults are active |
| **Zen Browser** | Applies a curated `user.js` privacy configuration |

### 20 — Hacking Tools (Kali Toolkit)

Installs a curated selection of penetration testing tools from the Kali Linux toolset, available on Fedora via DNF and Flatpak — network analysis, password tools, web testing, and more.

---

### 21 — Hyprland + Dotfiles

Installs [Hyprland](https://hyprland.org/) (a dynamic tiling Wayland compositor) with your choice of three community dotfile presets. Each shows a full description, requirements, and a confirmation prompt before changing anything.

> Hyprland is intentionally excluded from "Install Everything" (option 1) because all three presets are interactive wizards. Run option 21 on its own after your first reboot.

#### Preset 1 — JaKooLit *(recommended for Fedora)*
> <https://github.com/JaKooLit/Fedora-Hyprland>

- Fedora-native installer with an interactive `whiptail` wizard
- Built-in NVIDIA driver support
- SDDM login manager + GTK/icon themes pre-configured
- Quickshell overview (`SUPER+A`), searchable keybinds (`SUPER+H`)

#### Preset 2 — ML4W (mylinuxforwork)
> <https://github.com/mylinuxforwork/dotfiles>

- Glass / material colour theme that adapts automatically to your wallpaper
- GUI settings app — toggle blur, borders, and animations without editing config files
- Global Glass Waybar with centre workspace selector
- Officially supports Fedora, Arch, and openSUSE Tumbleweed

#### Preset 3 — end-4 (illogical-impulse)
> <https://github.com/end-4/dots-hyprland>

- Most starred Hyprland dotfiles on GitHub (~14k ⭐)
- GNOME-like UX — familiar for Windows and GNOME users
- AI sidebar with ChatGPT & Gemini integrated on the desktop
- Live adaptive colour generation from wallpaper
- `SUPER+/` for a full keybind cheat-sheet
- Targets Arch primarily; Fedora support is community-maintained

---

## Customising Package Lists

The DNF packages, Flatpak apps, GitHub repos, and GitHub releases are all defined as arrays near the top of `setup.sh`. Edit them before running the script to add or remove anything:

```bash
DNF_PACKAGES=(
    git make cmake python3 nodejs ...
)

FLATPAK_PACKAGES=(
    "com.discordapp.Discord"
    "org.telegram.desktop"
    ...
)

GITHUB_REPOS=(
    "https://github.com/user/repo.git|main|clone|"
)

GITHUB_RELEASES=(
    "jesseduffield/lazygit|lazygit|lazygit_.*_Linux_x86_64.tar.gz"
)
```

---

## Logging

Every run writes a timestamped log to `~/setup_log_<YYYYMMDD_HHMMSS>.txt`. Check it if anything fails — all command output is captured there.

---

## ⚠️ Disclaimer

This script makes significant changes to your system configuration. It is provided as-is for personal use. **Always create a [Timeshift](https://github.com/teejee2008/timeshift) snapshot before running hardening or system-level options.** The author takes no responsibility for data loss or system instability.

---

## Contributing

Pull requests and suggestions are welcome. If you have a tool, dotfile preset, or feature you'd like added, open an issue or PR.

---

## License

[MIT](LICENSE) — do whatever you want with it.
