<div align="center">

# Fedora Setup Script

**A one-stop interactive setup script for Fedora Linux** — packages, security hardening, dev tools, privacy, Hyprland and more, all from a single terminal menu.

![Fedora](https://img.shields.io/badge/Fedora-41%2B-blue?logo=fedora&logoColor=white)
![Shell](https://img.shields.io/badge/Shell-Bash-green?logo=gnubash&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Maintained](https://img.shields.io/badge/Maintained-Yes-brightgreen)

</div>

---

## Features at a Glance

| Category | What's included |
|---|---|
| Package Installation | RPM Fusion, Flathub / Terra repos, DNF and Flatpak batch installs, GitHub clone and release installs |
| Shell and Terminal | Oh My Posh, Fastfetch, Nerd Fonts |
| Development Tools | Rust, NVM, Homebrew (Linuxbrew), Winboat |
| Drivers and Apps | NVIDIA drivers, AppImages (Helium, Capacities, Affinity) |
| Security | ClamAV, Chris Titus Linux Hardening, JShielder full system hardening |
| Privacy and Network | Tor, MAC address spoofing, WireGuard VPN, DNS-over-TLS |
| Storage | Auto-mount all drives |
| Help and Learning | Interactive NOOBS GUIDE to Fedora |
| Extra Security | GRUB lockdown, Lynis audit, disk encryption, systemd hardening |
| Privacy Extras | Browser hardening (Firefox / LibreWolf / Zen) |
| Hacking Tools | Kali Linux Toolkit on Fedora |
| Hyprland | Full Hyprland install + dotfiles (3 presets to choose from) |

---

## Quick Start

```bash
git clone https://github.com/ineednotitle/fedora-setup.git
cd fedora-setup
chmod +x setup.sh
./setup.sh
```

> **Do NOT run as root.** The script calls `sudo` internally when needed.

---

## Requirements

- Fedora **41 or newer** (tested on KDE Spin)
- Active internet connection
- `git` and `curl` installed: `sudo dnf install -y git curl`
- A non-root user account with sudo privileges

---

## Menu Overview

```
  1)  Install EVERYTHING

  -- Package Installation --
  2)  Setup Repositories (RPM Fusion, Flathub, Terra)
  3)  Install DNF Packages
  4)  Install Flatpak Applications
  5)  Clone & Build GitHub Repos
  6)  Install GitHub Releases

  -- Shell & Terminal --
  7)  Install Oh My Posh
  8)  Configure Fastfetch
  9)  Install Nerd Fonts

  -- Development Tools --
  10) Install Rust
  11) Install NVM (Node Version Manager)
  12) Install & Setup Homebrew (Linuxbrew)
  13) Install Winboat

  -- Drivers & Apps --
  14) Install NVIDIA Drivers
  15) Install AppImages (Helium, Capacities, Affinity Installer)

  -- Security --
  16) Install & Configure ClamAV Antivirus
  17) Linux Security Hardening (Chris Titus)
  18) JShielder -- Full System Hardening (KDE Edition)

  -- Privacy & Network --
  19) Privacy & Network Tools (Tor, MAC spoof, WireGuard, DNS-DoT)

  -- Storage --
  20) Auto Mount All Drives

  -- Help & Learning --
  21) NOOBS GUIDE -- Learn Fedora Linux

  -- Extra Security: Use at your own Risk --
  22) GRUB Hardening + Kernel Lockdown
  23) Lynis -- Full Security Audit & Score
  24) Disk Encryption Check + Encrypted Swap
  25) Systemd Hardening + Immutable Files + Logwatch

  -- Privacy Extras --
  26) Harden Browser Privacy (Firefox / LibreWolf / Zen Browser)

  -- Hacking Tools --
  27) Hacking Tools -- Kali Linux Toolkit

  -- Hyprland --
  28) Install Hyprland + Dotfiles (JaKooLit / ML4W / end-4)

  0)  Exit
```

---

## Feature Details

### 1 - Install Everything

Runs every feature in sequence (except Hyprland, which requires an interactive wizard session). Great for setting up a fresh Fedora install in one go.

---

### 2 - Setup Repositories

Enables the following repos before any package installs:

- **RPM Fusion** (free and non-free) - codecs, drivers, extra packages
- **Flathub** - the universal Linux app store
- **Terra (fyralabs)** - modern packages not yet in Fedora's official repos; also required for Winboat

---

### 3 to 6 - Package Installation

Batch installs your curated list of DNF packages and Flatpak apps, clones and builds GitHub repos, and downloads the latest GitHub release binaries. All lists are defined inside the script so you can customize them freely.

---

### 7 - Oh My Posh

Installs [Oh My Posh](https://ohmyposh.dev/) and configures a prompt theme for Bash and Zsh.

### 8 - Configure Fastfetch

Sets up [Fastfetch](https://github.com/fastfetch-cli/fastfetch) with a custom config to display system info on terminal launch.

### 9 - Nerd Fonts

Downloads and installs a selection of [Nerd Fonts](https://www.nerdfonts.com/) - required for Oh My Posh icons to render correctly.

---

### 10 - Rust

Installs the Rust toolchain via `rustup` and configures the PATH for Cargo.

### 11 - NVM (Node Version Manager)

Installs [NVM](https://github.com/nvm-sh/nvm) for switching between Node.js versions. Also installs the latest LTS Node by default.

### 12 - Homebrew (Linuxbrew)

Installs [Homebrew](https://brew.sh/) for Linux, adds it to your shell environment (`.bashrc` and `.zshrc`), and runs `brew update` and `brew doctor` to confirm everything is healthy.

### 13 - Winboat

Installs [Winboat](https://terra.fyralabs.com/) from the Terra repository for running Windows applications on Linux. Falls back to ProtonUp-Qt (Flatpak) if the Terra package is unavailable for your Fedora version.

---

### 14 - NVIDIA Drivers

Installs proprietary NVIDIA drivers from RPM Fusion with CUDA and Vulkan support.

### 15 - AppImages

Downloads and installs:

- **Helium** - lightweight browser
- **Capacities** - personal knowledge base
- **Affinity Installer** - runs Affinity Suite (Photo, Designer, Publisher) via Wine/Bottles

---

### 16 - ClamAV

Installs and configures [ClamAV](https://www.clamav.net/) antivirus with `freshclam` auto-updates and a daily scan timer.

### 17 - Linux Security Hardening (Chris Titus)

Runs the [Chris Titus Tech](https://github.com/ChrisTitusTech/linux-titus) hardening script - sysctl tweaks, SSH hardening, and firewall rules.

### 18 - JShielder (KDE Edition)

Full system hardening via [JShielder](https://github.com/Jsitech/JShielder) - PAM rules, audit daemon, kernel hardening, service disabling, and more. Tailored for KDE Plasma.

---

### 19 - Privacy and Network Tools

Interactive submenu for:

- **Tor** - anonymous browsing via the Tor network
- **MAC address spoofing** - randomize your network identity on every boot
- **WireGuard VPN** - fast, modern VPN setup
- **DNS-over-TLS** - encrypted DNS via systemd-resolved

### 20 - Auto Mount All Drives

Detects all unmounted drives and adds them to `/etc/fstab` for automatic mounting on boot.

---

### 21 - NOOBS GUIDE

An interactive in-script guide covering 11 topics for new Fedora users: terminal basics, package management, sudo, KDE tips, networking, troubleshooting, and recommended apps.

---

### 22 to 25 - Extra Security

> These options make deep system changes. Always create a **Timeshift snapshot** before proceeding.

| Option | Feature | What it does |
|---|---|---|
| 22 | GRUB Hardening | Password-protects GRUB and enables kernel lockdown mode |
| 23 | Lynis Audit | Full [Lynis](https://cisofy.com/lynis/) security audit with hardening score |
| 24 | Disk Encryption | Checks LUKS status and sets up an encrypted swap partition |
| 25 | Systemd Hardening | Restricts service permissions, sets immutable flags on key files, installs Logwatch |

---

### 26 - Browser Privacy Hardening

Applies privacy settings to your browser profile:

- **Firefox** - disables telemetry, strict tracking protection, DNS-over-HTTPS
- **LibreWolf** - verifies hardened defaults are active
- **Zen Browser** - applies a curated user.js privacy configuration

### 27 - Hacking Tools (Kali Toolkit)

Installs a curated set of penetration testing tools from the Kali Linux toolset, available for Fedora via DNF and Flatpak.

---

### 28 - Hyprland + Dotfiles

Installs [Hyprland](https://hyprland.org/) (a dynamic tiling Wayland compositor) with a choice of three community dotfile presets. Each preset shows a full description and confirmation prompt before changing anything.

> Hyprland is excluded from "Install Everything" (option 1) because all three presets launch interactive wizards. Run option 28 separately after a fresh reboot.

#### Option 1 - JaKooLit (Best for Fedora)

> https://github.com/JaKooLit/Fedora-Hyprland

- Cyberpunk / Neon Circuit Waybar aesthetic
- Interactive whiptail wizard - choose exactly what to install
- Built-in NVIDIA driver support
- SDDM login manager + GTK/icon themes pre-configured
- Quickshell overview (SUPER+A), searchable keybinds (SUPER+H)
- Dotfiles from: https://github.com/JaKooLit/Hyprland-Dots

#### Option 2 - ML4W (mylinuxforwork)

> https://github.com/mylinuxforwork/dotfiles

- Glass / material color theme that adapts automatically to your wallpaper
- GUI settings app - toggle blur, borders, animations without touching config files
- Global Glass Waybar with center workspace selector
- Officially supports Fedora, Arch, and openSUSE Tumbleweed

#### Option 3 - end-4 (illogical-impulse)

> https://github.com/end-4/dots-hyprland

- Most starred Hyprland dotfiles on GitHub (~14k stars)
- GNOME-like UX - familiar for Windows and GNOME users
- AI sidebar with ChatGPT and Gemini built into your desktop
- Live adaptive color generation from wallpaper
- Fancy notification center, music controls, and calendar widget
- SUPER+/ for a full keybind cheat-sheet

---

## Disclaimer

This script makes significant changes to your system. It is provided as-is for personal use. Always create a **Timeshift snapshot** before running any hardening or system-level options. The author takes no responsibility for data loss or system instability.

---

## Contributing

Pull requests and suggestions are welcome. If you have a dotfile preset, tool, or feature you would like added, open an issue or PR.

---

## License

MIT - do whatever you want with it, just don't blame me if something breaks.
