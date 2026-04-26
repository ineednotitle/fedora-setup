# fedora-setup

A modular post-install setup script for Fedora Linux (KDE edition).  
Installs packages, configures your shell, hardens your system, and gets you productive fast.

> ⚠️ **AI-assisted & Beta** — This script was heavily built and refactored with AI assistance. It works on the author's machine but has **not been tested across every Fedora version or hardware configuration**. Use it carefully, read what each option does before running it, and always have a backup. Expect rough edges. PRs and issue reports are welcome.

---

## Features

| # | Option | What it does |
|---|--------|-------------|
| 1 | **Install EVERYTHING** | Runs all steps below in sequence |
| 2 | Setup Repositories | Adds RPM Fusion (free + nonfree) and Flathub |
| 3 | Install DNF Packages | git, make, cmake, python3, nodejs, tmux, fzf, wine, steam, fonts, and more |
| 4 | Install Flatpak Apps | VS Code, VLC, OnlyOffice, Heroic, WineZGUI, Flameshot, Zen Browser, and more |
| 5 | Clone GitHub Repos | Clones and builds repos defined in the `GITHUB_REPOS` list |
| 6 | Install GitHub Releases | Downloads latest binaries: lazygit, fzf, bat, ripgrep |
| 7 | Install Oh My Posh | Prompt theme engine for bash/zsh with theme download |
| 8 | Configure Fastfetch | Sets up a custom fastfetch config with logo support |
| 9 | Install Nerd Fonts | JetBrainsMono and FiraCode Nerd Fonts (parallel download) |
| 10 | Install Rust | Official rustup installer |
| 11 | Install NVM | Node Version Manager v0.40.1 |
| 12 | Install NVIDIA Drivers | akmod-nvidia / akmod-nvidia-open / CUDA — your choice |
| 13 | Install AppImages | Helium Browser, Capacities, Linux Affinity Installer |
| 14 | ClamAV Antivirus | Installs, configures clamd, schedules scans, desktop alerts |
| 15 | Linux Security Hardening | firewalld, fail2ban, SELinux enforcing, sysctl kernel hardening |
| 16 | JShielder Hardening | Full 14-step system hardening: SSH, AIDE, auditd, GRUB, USBGuard, and more |
| 17 | Privacy & Network Tools | Tor, MAC spoofing, WireGuard, Yggdrasil, DNS-over-TLS, I2P, proxychains, MAT2 |
| 18 | Auto Mount All Drives | fstab entries for internal, external, NTFS, exFAT, and USB auto-mount |
| 19 | Noobs Guide | Interactive Fedora learning guide: terminal, packages, KDE, troubleshooting |
| 20 | Backup Configs | Backs up dotfiles, SSH config, fastfetch, oh-my-posh themes |
| 21 | Restore Configs | Restores from a previous backup directory |
| 22 | GRUB Hardening | Kernel lockdown mode, CPU mitigations, optional GRUB password |
| 23 | Lynis Audit | Full security audit with scoring via Lynis |
| 24 | Disk Encryption | Checks LUKS status and sets up encrypted swap |
| 25 | Systemd Hardening | Systemd sandboxing, immutable files, logwatch |
| 26 | Browser Privacy | Hardens Firefox/LibreWolf via user.js (no WebRTC, anti-fingerprint, DoH) |
| 27 | Hacking Tools | 15-category Kali Linux toolkit installable on Fedora via DNF |

---

## Requirements

- **Fedora** — tested primarily on Fedora 39/40 KDE Spin  
- A **regular user account** with sudo access (do not run as root)  
- Internet connection  
- `bash` 4.0+

---

## Quick Start

```bash
# 1. Download the script
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/fedora-setup/main/setuplinuxv10_clean.sh

# 2. Make it executable
chmod +x setuplinuxv10_clean.sh

# 3. Run it (do NOT use sudo)
./setuplinuxv10_clean.sh
```

You'll be prompted for your sudo password once at startup. After that, an interactive menu lets you pick exactly what to install.

---

## Recommended First-Run Order

If you're setting up a fresh Fedora install, this order works well:

1. **Option 2** — Setup Repositories first (required for most installs)
2. **Option 3** — DNF packages
3. **Option 4** — Flatpak apps
4. **Option 9** — Nerd Fonts (needed for Oh My Posh to render correctly)
5. **Option 7** — Oh My Posh
6. **Option 8** — Fastfetch
7. **Option 10 / 11** — Rust / NVM if you develop
8. **Option 14–16** — Security hardening (read each step before confirming)
9. **Option 18** — Mount your drives
10. **Option 19** — Noobs Guide if you're new to Linux

---

## Customisation

All package lists live near the top of the script and are easy to edit:

```bash
# DNF packages to install
DNF_PACKAGES=(
    git make cmake python3 nodejs
    # add or remove packages here
)

# Flatpak app IDs
FLATPAK_PACKAGES=(
    "com.visualstudio.code"
    # add or remove app IDs here
)

# GitHub repos to clone/build
# Format: "url|branch|install_type|install_command"
GITHUB_REPOS=(
    "https://github.com/dreamsofautonomy/zensh.git|main|clone|"
)
```

---

## Logs

Every run writes a timestamped log to your home directory:

```
~/setup_log_YYYYMMDD_HHMMSS.txt
```

If something fails, check there first.

---

## Security & Hacking Tools Notice

Options 14–27 make real, persistent changes to your system (firewall rules, kernel parameters, SELinux mode, GRUB config). **Read the prompt for each step before confirming.** The hacking tools category (option 27) is intended for legal use only — authorised penetration testing, CTF challenges, and security research.

---

## AI Notice

This script was heavily developed and refactored with the assistance of AI (Claude by Anthropic). That means:

- The logic has been reviewed but **not exhaustively tested** on all hardware and Fedora versions
- Some edge cases may be missing
- The script is in **beta** — use it on a machine you're comfortable experimenting on
- If something breaks, open an issue or submit a fix — contributions are very welcome

---

## Contributing

1. Fork the repo
2. Create a branch: `git checkout -b fix/your-fix-name`
3. Make your changes and test on a real Fedora install
4. Open a pull request with a description of what you changed and why

Bug reports, feature requests, and tested PRs are all appreciated.

---

## License

MIT — do whatever you want with it, just don't blame me if it breaks something.
