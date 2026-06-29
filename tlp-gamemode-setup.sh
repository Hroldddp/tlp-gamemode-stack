#!/usr/bin/env bash
set -euo pipefail

# ┌─────────────────────────────────────────────┐
# │  TLP + GameMode Power Stack Installer       │
# │  for CachyOS / Arch Linux (AMD + NVIDIA)    │
# └─────────────────────────────────────────────┘

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' B='\033[0;34m' N='\033[0m'
ROLLBACK_FILE=/tmp/tlp-gamemode.rolled

banner()  { echo -e "\n${B}━━━ $1 ━━━${N}"; }
ok()      { echo -e " ${G}✔${N} $1"; }
warn()    { echo -e " ${Y}⚠${N} $1"; }
fail()    { echo -e " ${R}✘${N} $1"; exit 1; }

rollback() {
  banner "ROLLING BACK"
  sudo pacman -R --noconfirm tlp tlp-pd gamemode 2>/dev/null && ok "Packages removed" || warn "Nothing to remove"
  sudo pacman -S --noconfirm power-profiles-daemon 2>/dev/null && ok "power-profiles-daemon reinstalled" || warn "Could not reinstall power-profiles-daemon"
  sudo systemctl enable --now power-profiles-daemon.service 2>/dev/null || true
  sudo rm -f /etc/gamemode.ini
  rm -f ~/.config/gamemode.ini
  rm -f "$ROLLBACK_FILE"
  ok "Rollback complete. Reboot recommended."
}

if [[ "${1:-}" == "--rollback" ]]; then rollback; exit 0; fi
if [[ -f "$ROLLBACK_FILE" ]]; then
  warn "Already installed. Run with --rollback first to reset."
  exit 1
fi

# ── Remove conflicting PPD ──────────────────────
banner "REMOVING POWER-PROFILES-DAEMON"
sudo pacman -R --noconfirm power-profiles-daemon 2>/dev/null && ok "power-profiles-daemon removed" || warn "power-profiles-daemon not installed"
sudo systemctl mask power-profiles-daemon.service 2>/dev/null || true

# ── Install ────────────────────────────────────
banner "INSTALLING PACKAGES"
sudo pacman -S --noconfirm tlp tlp-pd gamemode
ok "tlp, tlp-pd, gamemode installed"

# ── Configure TLP ──────────────────────────────
banner "CONFIGURING TLP"
sudo tee /etc/tlp.conf > /dev/null <<'TLPCONF'
# ── AMD Platform Profile (replaces PPD) ──
PLATFORM_PROFILE_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=balanced
PLATFORM_PROFILE_ON_SAV=low-power

CPU_ENERGY_PERF_POLICY_ON_AC=""
CPU_ENERGY_PERF_POLICY_ON_BAT=""
CPU_ENERGY_PERF_POLICY_ON_SAV=""

# ── Peripherals ──
USB_AUTOSUSPEND_ON_AC=0
USB_AUTOSUSPEND_ON_BAT=1

RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto
RUNTIME_PM_DRIVER_DENYLIST="nvidia nvidia_drm nvidia_modeset"

SATA_LINKPWR_ON_AC=max_performance
SATA_LINKPWR_ON_BAT=min_power

WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on
TLPCONF
ok "/etc/tlp.conf written"

sudo systemctl enable --now tlp.service
ok "tlp.service enabled + started"

# ── GameMode ────────────────────────────────────
banner "CONFIGURING GAMEMODE"
mkdir -p ~/.config
cat > ~/.config/gamemode.ini <<'GAMECONF'
[general]
renice=10
softrealtime=auto
reaper_freq=5
defaultgov=performance

[custom]
start=powerprofilesctl set performance
end=powerprofilesctl set balanced
GAMECONF
ok "~/.config/gamemode.ini written"

# Detect AMD GPU card number for GameMode GPU optimisations
AMD_CARD=$(for card in /sys/class/drm/card*/device/vendor; do
  if [[ "$(cat "$card" 2>/dev/null)" == "0x1002" ]]; then
    echo "${card#/sys/class/drm/card}" | cut -d/ -f1
    break
  fi
done)
if [[ -n "$AMD_CARD" ]]; then
  sudo tee /etc/gamemode.ini > /dev/null <<'GAMECONF'
[gpu]
apply_gpu_optimisations=accept-responsibility
amd_performance_level=high
GAMECONF
  ok "/etc/gamemode.ini written (AMD GPU on card${AMD_CARD})"
fi

# ── Done ────────────────────────────────────────
touch "$ROLLBACK_FILE"
echo
echo -e "${G}  ╔═══════════════════════════════════════╗${N}"
echo -e "${G}  ║  All set — reboot for good measure    ║${N}"
echo -e "${G}  ╚═══════════════════════════════════════╝${N}"
echo
echo -e "  ${B}Profiles${N}   powerprofilesctl set {performance|balanced|power-saver}"
echo -e "  ${B}Gaming${N}     gamemoderun %command%"
echo -e "  ${B}Rollback${N}   $0 --rollback"
echo
