# TLP + GameMode Power Stack

**Unified power management for AMD and NVIDIA laptops running Arch Linux.**

This repository provides a single script that installs and configures TLP alongside GameMode to offer both sustained power efficiency and on-demand performance for gaming and other demanding workloads.

---

## About

Modern AMD processors use the `amd-pstate` driver, which enables hardware-managed P-states and a "platform profile" interface. Rather than relying on software-level frequency scaling, this approach lets the hardware adjust voltage and frequency intelligently based on workload hints.

TLP is a comprehensive power management daemon that makes use of this interface while also managing peripheral power consumption through USB autosuspend, PCI Express runtime power management, SATA link power negotiation, and wireless device power saving.

GameMode complements TLP by providing process-level optimizations that are activated only when a game is launched, including CPU scheduler tuning, I/O priority adjustment, and GPU performance mode selection.

Together, these tools form a layered power management strategy: TLP handles system-wide policy, and GameMode handles per-process performance requests.

---

## Features

- **Three configurable power profiles** — `performance`, `balanced`, and `power-saver` — switchable at runtime through the desktop environment or command line
- **Peripheral power management** — automatic USB, PCIe, SATA, and wireless power saving on battery power
- **Automatic profile switching** — TLP changes the active profile in response to AC power connection and disconnection
- **On-demand game performance** — GameMode applies CPU, I/O, and GPU optimisations only while a game is running, then restores the previous state on exit
- **Desktop environment integration** — the `tlp-pd` package implements the same D-Bus API used by GNOME, KDE, and Cinnamon for power profile selection
- **NVIDIA GPU compatibility** — the configuration excludes NVIDIA devices from PCIe runtime power management to avoid conflicts with `nvidia-powerd`
- **Full rollback support** — running the script with `--rollback` removes TLP and GameMode and reinstates `power-profiles-daemon`

---

## Requirements

- An Arch Linux-based distribution (Arch, CachyOS, EndeavourOS, Manjaro, and similar)
- An AMD CPU supported by the `amd-pstate` driver
- A systemd-based init system
- Optional: an NVIDIA GPU with `nvidia-powerd` for dedicated GPU power management

---

## Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/Hroldddp/tlp-gamemode-stack.git
cd tlp-gamemode-stack
chmod +x tlp-gamemode-setup.sh
./tlp-gamemode-setup.sh
```

Alternatively, download the script directly:

```bash
curl -O https://raw.githubusercontent.com/Hroldddp/tlp-gamemode-stack/main/tlp-gamemode-setup.sh
chmod +x tlp-gamemode-setup.sh
./tlp-gamemode-setup.sh
```

The script will install the required packages, disable the default `power-profiles-daemon`, write a pre-configured TLP settings file, and create a GameMode configuration.

---

## Usage

### Switching power profiles

```
powerprofilesctl set performance
powerprofilesctl set balanced
powerprofilesctl set power-saver
```

These commands work identically to the interface provided by `power-profiles-daemon` and are also accessible through the power applet in GNOME, KDE, and Cinnamon.

### Launching a game with optimisations

```
gamemoderun %command%
```

Add this as a launch option in Steam, or prefix any executable to apply GameMode's optimisations for its duration.

### Reverting the installation

```
./tlp-gamemode-setup.sh --rollback
```

This removes TLP and GameMode, unmaskes and re-enables `power-profiles-daemon`, and deletes the GameMode configuration file.

---

## Configuration

### TLP

The script writes a configuration file to `/etc/tlp.conf`. The settings are organised into the following groups:

**Platform profile**

| Condition | Profile |
|---|---|
| AC power | performance |
| Battery | balanced |
| Power-saver request | low-power |

The `CPU_ENERGY_PERF_POLICY` variables are deliberately left empty, as the platform profile alone is sufficient for `amd-pstate` hardware and setting both simultaneously can produce unpredictable results.

**Peripheral power**

| Setting | AC | Battery |
|---|---|---|
| USB autosuspend | disabled | enabled |
| PCIe runtime PM | auto | auto |
| SATA link power | max_performance | min_power |
| WiFi power saving | off | on |

NVIDIA GPU devices are excluded from PCIe runtime PM through `RUNTIME_PM_DRIVER_DENYLIST`.

### GameMode

The configuration file is written to `~/.config/gamemode.ini`. Key settings include:

- `defaultgov=performance` — CPU governor set during gameplay
- `renice=10` — I/O priority adjustment
- `softrealtime=auto` — automatic SCHED_ISO scheduling
- Custom start and end commands synchronise GameMode activations with the TLP `performance` profile

---

## How it works

When the system is idle or under light load on battery power, TLP applies the `balanced` or `power-saver` platform profile and enables peripheral power saving. When AC power is connected, TLP switches to the `performance` profile automatically.

When a game is launched through `gamemoderun`, GameMode:
1. Sets the CPU governor to `performance`
2. Raises the I/O priority of the game process
3. Enables GPU performance mode for NVIDIA and AMD hardware
4. Inhibits the screensaver
5. Runs a custom start command that also sets the platform profile to `performance`

When the game exits, GameMode runs its end command, restoring the platform profile to `balanced`, and the original TLP state resumes.

---

## License

This project is distributed under the MIT License. See the `LICENSE` file for details.
