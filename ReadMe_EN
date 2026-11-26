<a id="readme-top"></a>

<div align="center">

# 🌈 OMEGA LED Monitor

**Visualize network, storage, and container activity directly on the RGB LEDs of a Turris Omnia router.**

[![Status](https://img.shields.io/badge/status-ready-brightgreen)](#project-status)
[![Platform](https://img.shields.io/badge/platform-Turris%20Omnia-00AEEF)](#requirements)
[![Turris OS](https://img.shields.io/badge/Turris%20OS-9.x-00AEEF)](#requirements)
[![Language](https://img.shields.io/badge/language-POSIX%20Shell-4EAA25?logo=gnu-bash&logoColor=white)](#language-and-technologies)
[![Service](https://img.shields.io/badge/service-procd-6A5ACD)](#architecture)
[![Configuration](https://img.shields.io/badge/configuration-UCI-FF8800)](#configuration)
[![License](https://img.shields.io/badge/license-not%20specified-lightgrey)](#license)

OMEGA LED Monitor replaces the default dynamic LED handling of a Turris Omnia with a configurable monitor for physical link states, network traffic, Wi-Fi activity, storage I/O, and a Nextcloud LXC container.

[Quick start](#quick-start) •
[LED mapping](#led-mapping) •
[Configuration](#configuration) •
[Troubleshooting](#troubleshooting) •
[Uninstall](#uninstall)

</div>

---

## ✨ Project highlights

- 🌐 Visualizes WAN, LAN, and Wi-Fi activity directly on the router
- 💾 Displays I/O activity for an SSD on `/dev/sda` and the internal eMMC on `/dev/mmcblk0`
- 📦 Uses `indicator-1`, also known as `USER1`, for Nextcloud LXC network activity
- 🌬️ Shows available but idle resources with a gentle green breathing effect
- 🚦 Changes active LEDs from green through yellow and orange to red as load increases
- 🔌 Turns disconnected WAN and LAN LEDs off instead of displaying misleading activity
- ⚙️ Uses UCI for interface names, thresholds, and sampling settings
- 🛡️ Creates timestamped backups before replacing existing LED rules
- 🔄 Runs as a supervised OpenWrt `procd` service and starts automatically at boot
- 🧰 Installs the monitor, configuration, and init service from a single shell script

---

## 🚦 Project status

| Area | Status |
|---|---|
| Installer | 🟢 available |
| Runtime monitor | 🟢 generated and installed by the installer |
| UCI configuration | 🟢 included |
| `procd` service | 🟢 included |
| Automatic backup | 🟢 included |
| Turris Omnia and Turris OS 9.x target | 🟢 documented |
| Other router models | ⚪ not supported or validated |
| Automated CI tests | ⚪ not present |
| License file | ⚪ not present |

> [!IMPORTANT]
> The installer is tailored to a specific Turris Omnia configuration. Verify the expected LED, network interface, and block-device names before running it.

---

## 🧭 Table of contents

- [How it works](#how-it-works)
- [LED behavior](#led-behavior)
- [LED mapping](#led-mapping)
- [Requirements](#requirements)
- [Language and technologies](#language-and-technologies)
- [Architecture](#architecture)
- [Quick start](#quick-start)
- [Changes made by the installer](#changes-made-by-the-installer)
- [Verification](#verification)
- [Configuration](#configuration)
- [Calibration examples](#calibration-examples)
- [Troubleshooting](#troubleshooting)
- [Maintenance and updates](#maintenance-and-updates)
- [Uninstall](#uninstall)
- [Command reference](#command-reference)
- [Repository structure](#repository-structure)
- [Technical references](#technical-references)
- [Safety and operational notes](#safety-and-operational-notes)
- [Contributing](#contributing)
- [License](#license)
- [Disclaimer](#disclaimer)

---

## How it works

OMEGA LED Monitor controls the Turris Omnia RGB LEDs through the Linux multicolor LED sysfs interface under `/sys/class/leds/rgb:*`.

Color and brightness are controlled independently:

- `multi_intensity` defines the RGB color channels
- `brightness` defines the overall LED brightness
- `trigger` is set to `none` so kernel triggers do not compete with the monitor

The monitor reads network and block-device counters, calculates activity rates, and translates those rates into color and brightness animations.

<p align="right"><a href="#readme-top">Back to top</a></p>

---

## LED behavior

### Idle

A connected or available resource with activity below its configured idle threshold breathes green between approximately **8% and 25% brightness**.

### Activity

During activity, the LED starts flickering at **50% brightness**. As load increases, its color changes through:

```text
Green → Yellow → Orange → Red
```

At or above the configured maximum rate, the LED reaches red at 100% brightness.

### Unavailable resources

- A WAN or LAN LED remains off when the corresponding interface has no physical link.
- `USER1` remains off when the configured Nextcloud host interface does not exist.
- Storage LEDs remain off when the block-device statistics are unavailable.
- Wi-Fi LEDs remain off when their configured interfaces do not exist.

<p align="right"><a href="#readme-top">Back to top</a></p>

---

## LED mapping

| Omnia LED | Data source | Behavior |
|---|---|---|
| `power` | Router or process state | Constant green at 50% brightness |
| `wan` | Receive traffic from `eth2` | Off without carrier, breathing at idle, load-dependent color during activity |
| `lan-0` to `lan-4` | `lan0` to `lan4`, RX + TX | Active only when the physical link reports carrier |
| `wlan-1` | `phy0ap0`, RX + TX | Breathing at idle and load-dependent color during activity |
| `wlan-2` | `phy1ap0`, RX + TX | Breathing at idle and load-dependent color during activity |
| `wlan-3` | `/dev/sda`, intended for `/srv` | Block I/O from `/sys/class/block/sda/stat` |
| `indicator-1` / `USER1` | `nc-veth`, intended for Nextcloud LXC | Off when absent, otherwise idle or activity display |
| `indicator-2` / `USER2` | `/dev/mmcblk0`, internal eMMC | Block I/O display |

> [!NOTE]
> The WAN display currently uses only the RX counter. LAN, Wi-Fi, and Nextcloud use the sum of RX and TX.

<p align="right"><a href="#readme-top">Back to top</a></p>

---

## Requirements

The supplied installer expects:

- a **Turris Omnia** running **Turris OS 9.x**
- root access through SSH
- `uci`
- RGB LEDs exposed as `/sys/class/leds/rgb:*`
- WAN interface `eth2`
- LAN interfaces `lan0` through `lan4`
- Wi-Fi interfaces `phy0ap0` and `phy1ap0`
- `/srv` located on `/dev/sda`
- internal storage available as `/dev/mmcblk0`
- a host-side Nextcloud LXC interface named `nc-veth`
- enough free space under `/srv/backups/omega-led-monitor/`

The installer validates UCI and all expected RGB LED directories before making its main changes.

### Expected RGB LED names

```text
power
wan
lan-0
lan-1
lan-2
lan-3
lan-4
wlan-1
wlan-2
wlan-3
indicator-1
indicator-2
```

<p align="right"><a href="#readme-top">Back to top</a></p>

---

## Language and technologies

| Language or technology | Purpose |
|---|---|
| POSIX Shell (`/bin/sh`) | Installer, runtime monitor, and init service |
| UCI | Persistent configuration under `/etc/config/omega-led-monitor` |
| OpenWrt `procd` | Service supervision, respawn, and automatic startup |
| Linux sysfs | Access to RGB LEDs, network counters, and block-device counters |
| Linux Multicolor LED Class | Independent color and brightness control |
| SCP / SFTP / SSH | Transfer, installation, and administration |

The repository currently consists of a shell installer. The installer writes the runtime monitor and the `procd` init service to the router.

<p align="right"><a href="#readme-top">Back to top</a></p>

---

## Architecture

```text
install_omega_led_monitor.sh
│
├── validates root, UCI, and expected RGB LEDs
├── backs up existing LED and monitor configuration
├── removes competing OpenWrt LED sections
├── clears older Rainbow rules
├── writes /etc/config/omega-led-monitor
├── writes /usr/sbin/omega-led-monitor
├── writes /etc/init.d/omega-led-monitor
├── validates shell syntax
├── enables the service at boot
└── starts and verifies the service

/usr/sbin/omega-led-monitor
│
├── reads the UCI configuration
├── reads network byte counters
├── reads block-device sector counters
├── calculates per-second activity rates
├── translates activity into RGB and brightness
└── writes directly to multicolor LED sysfs

/etc/init.d/omega-led-monitor
│
└── runs the monitor under procd with respawn enabled
```

### Rate calculation

- Network values are based on counter deltas multiplied by `tick_factor`.
- Storage values are based on sector deltas multiplied by 512 bytes and `tick_factor`.
- When a counter moves backwards, the delta is treated as zero.
- Activity is normalized against the configured maximum rate using an internal scale from 0 to 1000.

### Color calculation

The normalized utilization is translated in two stages:

1. In the lower half, red rises from 0 to 255 while green remains at 255.
2. In the upper half, red remains at 255 while green falls to 0.
3. Blue remains at 0.

This creates the following gradient:

```text
Green → Yellow → Orange → Red
```

### Service supervision

The generated init service uses:

```text
START=99
STOP=10
USE_PROCD=1
respawn 5 10 5
term_timeout 5
```

<p align="right"><a href="#readme-top">Back to top</a></p>

---

## Quick start

> [!WARNING]
> The installer removes existing UCI sections of type `led` from `/etc/config/system` and clears `/etc/config/rainbow`. It creates backups first, but you should still review the script and confirm that the target layout matches your router.

### 1. Download the installer

Download [`install_omega_led_monitor.sh`](install_omega_led_monitor.sh) from this repository.

Alternatively, download it directly on the router:

```bash
cd /root
wget https://raw.githubusercontent.com/hansekiter/Omega-LED-Monitor/main/install_omega_led_monitor.sh
```

### 2. Copy the file from your computer

```bash
scp install_omega_led_monitor.sh root@10.0.0.1:/root/
```

Replace `10.0.0.1` if your router uses a different management address. SFTP can be used instead of SCP.

### 3. Connect and validate the syntax

```bash
ssh root@10.0.0.1
chmod 700 /root/install_omega_led_monitor.sh
sh -n /root/install_omega_led_monitor.sh
echo "Syntax=$?"
```

Expected result:

```text
Syntax=0
```

### 4. Run the installer

```bash
/root/install_omega_led_monitor.sh
```

The installer enables the service, starts it, and checks whether it is running.

### 5. Verify the service state

```bash
/etc/init.d/omega-led-monitor enabled
echo "enabled=$?"
/etc/init.d/omega-led-monitor running
echo "running=$?"
```

Expected result for both checks:

```text
0
```

<p align="right"><a href="#readme-top">Back to top</a></p>

---

## Changes made by the installer

The installer automatically:

1. Validates root access, UCI, and all expected RGB LED paths.
2. Creates a timestamped backup directory under:

   ```text
   /srv/backups/omega-led-monitor/YYYYMMDD-HHMMSS/
   ```

3. Backs up existing versions of:

   ```text
   /etc/config/system
   /etc/config/rainbow
   /etc/config/omega-led-monitor
   /usr/sbin/omega-led-monitor
   /etc/init.d/omega-led-monitor
   ```

4. Stops and disables an older installation.
5. Removes all UCI sections of type `led` from `/etc/config/system`.
6. Clears `/etc/config/rainbow` so older Rainbow rules do not compete with direct sysfs control.
7. Creates `/etc/config/omega-led-monitor`.
8. Creates `/usr/sbin/omega-led-monitor`.
9. Creates `/etc/init.d/omega-led-monitor`.
10. Validates the generated shell files with `sh -n`.
11. Tests whether `sleep 0.25` is supported.
12. Falls back to a 0.5-second interval and `tick_factor=2` when 0.25-second sleep is unavailable.
13. Enables and starts the service.
14. Verifies that the service is running.

> [!CAUTION]
> Removal of UCI LED sections is not limited to rules created by this project. Review `/etc/config/system` before installation if you rely on additional custom OpenWrt LED rules.

### Generated files

| Path | Purpose |
|---|---|
| `/etc/config/omega-led-monitor` | UCI configuration |
| `/usr/sbin/omega-led-monitor` | Runtime monitor |
| `/etc/init.d/omega-led-monitor` | `procd` init service |
| `/srv/backups/omega-led-monitor/<timestamp>/` | Backups of previous files and configurations |

<p align="right"><a href="#readme-top">Back to top</a></p>

---

## Verification

### Service and process

```bash
/etc/init.d/omega-led-monitor enabled
echo "enabled=$?"
/etc/init.d/omega-led-monitor running
echo "running=$?"
ps w | grep '[o]mega-led-monitor'
```

Exactly one monitor process should be running.

### Logs

```bash
logread | grep -iE 'omega-led-monitor|crash|syntax|not found' | tail -40
```

A successful installation should not produce new syntax, `not found`, or crash-loop messages.

### LAN carrier state

```bash
for DEV in lan0 lan1 lan2 lan3 lan4; do
    printf '%s=' "$DEV"
    cat "/sys/class/net/$DEV/carrier" 2>/dev/null || echo '?'
done
```

Expected behavior:

- `carrier=1`: the corresponding LED is active
- `carrier=0`: the corresponding LED remains off

### Nextcloud LXC

```bash
lxc-info -n nextcloud
ip link show nc-veth
```

When `nc-veth` exists, `USER1` displays idle or network activity. When the interface disappears, `USER1` turns off.

Example stop and start test:

```bash
lxc-stop -n nextcloud
sleep 2
lxc-start -n nextcloud -d
```

### SSD activity

```bash
dd if=/dev/zero of=/srv/led-test.bin bs=1M count=256 conv=fsync
rm -f /srv/led-test.bin
```

### Internal eMMC activity

Use a read-only test to avoid unnecessary write load:

```bash
dd if=/dev/mmcblk0 of=/dev/null bs=1M count=32
```

<p align="right"><a href="#readme-top">Back to top</a></p>

---

## Configuration

The configuration is stored in:

```text
/etc/config/omega-led-monitor
```

Display the current configuration:

```bash
uciMbit/s |
| `wlan1_max_bps` | `37500000` | First Wi-Fi red threshold, 300 Mbit/s |
| `wlan2_max_bps` | `37500000` | Second Wi-Fi red threshold, 300 Mbit/s |
| `sda_max_bps` | `104857600` | `/dev/sda` red threshold, 100 MiB/s |
| `emmc_max_bps` | `20971520` | eMMC red threshold, 20 MiB/s |
| `nextcloud_max_bps` | `12500000` | Nextcloud red threshold, 100 Mbit/s |
| `net_idle_threshold` | `2048` | Network is idle below 2 KiB/s |
| `disk_idle_threshold` | `4096` | Storage is idle below 4 KiB/s |

> [!IMPORTANT]
> The installer rewrites `/etc/config/omega-led-monitor` with its default values every time it runs. The previous configuration is backed up, but it is not automatically merged into the new configuration.

<p align="right">#readme-topBack to top</a></p>

---

## Calibration examples

### Make LAN LEDs reach red at 100 Mbit/s

```bash
uci set omega-led-monitor.main.lan_max_bps='12500000'
uci commit omega-led-monitor
/etc/init.d/omega-led-monitor restart
```

### Reduce flicker during low activity

Increase the idle threshold:

```bash
uci set omega-led-monitor.main.net_idle_threshold='8192'
uci commit omega-led-monitor
/etc/init.d/omega-led-monitor restart
```

### Change the WAN interface

```bash
uci set omega-led-monitor.main.wan_interface='YOUR_WAN_INTERFACE'
uci commit omega-led-monitor
/etc/init.d/omega-led-monitor restart
```

### Change the Nextcloud interface

```bash
uci set omega-led-monitor.main.nextcloud_interface='YOUR_INTERFACE'
uci commit omega-led-monitor
/etc/init.d/omega-led-monitor restart
```

### Calibration guidance

- If the LEDs flicker too often, increase the relevant idle threshold.
- If the color remains mostly green under real load, reduce the corresponding maximum rate.
- If the LED reaches red too quickly, increase the maximum rate.
- Keep `interval` and `tick_factor` consistent.
- For a 0.25-second interval, use `tick_factor=4`.
- For a 0.5-second interval, use `tick_factor=2`.

<p align="right">#readme-topBack to top</a></p>

---

## Troubleshooting

### LEDs remain white or old triggers still apply

```bash
uci show system | grep '=led$'
cat /etc/config/rainbow
```

After a complete installation, the first command should not list remaining UCI LED sections. Rainbow should not contain competing rules.

```bash
/etc/init.d/omega-led-monitor restart
```

### The service is not running

```bash
sh -n /usr/sbin/omega-led-monitor
sh -n /etc/init.d/omega-led-monitor
/etc/init.d/omega-led-monitor restart
sleep 3
/etc/init.d/omega-led-monitor running
echo $?
logread | grep -iE 'omega-led-monitor|crash|syntax|not found' | tail -60
```

If `procd` reports a crash loop, stop the service and run the monitor in the foreground:

```bash
/etc/init.d/omega-led-monitor stop
/usr/sbin/omega-led-monitor
```

The first visible foreground error is often more useful than later respawn messages.

### A specific LED remains dark

Inspect `USER1`:

```bash
LED='/sys/class/leds/rgb:indicator-1'
cat "$LED/multi_index"
cat "$LED/max_brightness"
cat "$LED/trigger"
```

Direct green test:

```bash
echo none > /sys/class/leds/rgb:indicator-1/trigger
echo '0 255 0' > /sys/class/leds/rgb:indicator-1/multi_intensity
cat /sys/class/leds/rgb:indicator-1/max_brightness \
  > /sys/class/leds/rgb:indicator-1/brightness
```

The values written to `multi_intensity` must follow the channel order reported by `multi_index`. The example assumes `red green blue`.

### A connected LAN port remains off

```bash
for DEV in lan0 lan1 lan2 lan3 lan4; do
    printf '%s=' "$DEV"
    cat "/sys/class/net/$DEV/carrier" 2>/dev/null || echo '?'
done
```

Only `carrier=1` is treated as a physical link. If the value remains `0` despite a connected cable, investigate link negotiation and interface mapping rather than the LED color calculation.

### The Nextcloud LED remains off

```bash
ip link show nc-veth
lxc-info -n nextcloud
```

If the container uses a different host-side interface, update the UCI configuration:

```bash
uci set omega-led-monitor.main.nextcloud_interface='YOUR_INTERFACE'
uci commit omega-led-monitor
/etc/init.d/omega-led-monitor restart
```

### The SSD LED remains off

```bash
test -r /sys/class/block/sda/stat
echo $?
cat /sys/class/block/sda/stat
```

Also verify that `/srv` is actually located on `/dev/sda`:

```bash
findmnt /srv
lsblk
```

### The eMMC LED remains off

```bash
test -r /sys/class/block/mmcblk0/stat
echo $?
cat /sys/class/block/mmcblk0/stat
```

### Fractional sleep is unsupported

The installer detects this condition automatically. Manual fallback:

```bash
uci set omega-led-monitor.main.interval='0.5'
uci set omega-led-monitor.main.tick_factor='2'
uci commit omega-led-monitor
/etc/init.d/omega-led-monitor restart
```

<p align="right">#readme-topBack to top</a></p>

---

## Maintenance and updates

### After a Turris OS update

```bash
test -x /usr/sbin/omega-led-monitor && echo 'Program present'
test -x /etc/init.d/omega-led-monitor && echo 'Service present'
/etc/init.d/omega-led-monitor running
echo "running=$?"
sh -n /usr/sbin/omega-led-monitor
```

Also verify the expected LED, interface, and block-device names:

```bash
ls -1 /sys/class/leds/rgb:* 2>/dev/null
ip link show
ls -l /sys/class/block/sda /sys/class/block/mmcblk0 2>/dev/null
```

If an update changes an interface name, update `/etc/config/omega-led-monitor` and restart the service.

### Reinstall or upgrade

A newer installer version can be run again. Every run creates a new timestamped backup first.

```bash
cd /root
wget -O install_omega_led_monitor.sh \
  https://raw.githubusercontent.com/hansekiter/Omega-LED-Monitor/main/install_omega_led_monitor.sh

chmod 700 install_omega_led_monitor.sh
sh -n install_omega_led_monitor.sh
./install_omega_led_monitor.sh
```

> [!CAUTION]
> Reinstalling restores the default configuration values from the installer. Compare the new configuration with the backup if you previously changed thresholds or interface names.

### List backups

```bash
ls -lah /srv/backups/omega-led-monitor/
```

<p align="right">#readme-topBack to top</a></p>

---

## Uninstall

Stop and disable the service:

```bash
/etc/init.d/omega-led-monitor stop
/etc/init.d/omega-led-monitor disable
```

Remove the installed files:

```bash
rm -f /etc/init.d/omega-led-monitor
rm -f /usr/sbin/omega-led-monitor
rm -f /etc/config/omega-led-monitor
```

Restore the required files from a timestamped backup under:

```text
/srv/backups/omega-led-monitor/
```

Example:

```bash
BACKUP='/srv/backups/omega-led-monitor/YOUR-TIMESTAMP'

cp -a "$BACKUP/system" /etc/config/system
cp -a "$BACKUP/rainbow" /etc/config/rainbow
```

Depending on the files you restored, restart the relevant OpenWrt LED or Rainbow services, or reboot the router:

```bash
reboot
```

> [!WARNING]
> Removing OMEGA LED Monitor does not automatically reconstruct the previously deleted UCI LED sections. Restore `/etc/config/system` and `/etc/config/rainbow` from the correct backup if you want the previous LED behavior back.

<p align="right">#readme-topBack to top</a></p>

---

## Command reference

| Purpose | Command |
|---|---|
| Running state | `/etc/init.d/omega-led-monitor running; echo $?` |
| Autostart state | `/etc/init.d/omega-led-monitor enabled; echo $?` |
| Start | `/etc/init.d/omega-led-monitor start` |
| Stop | `/etc/init.d/omega-led-monitor stop` |
| Restart | `/etc/init.d/omega-led-monitor restart` |
| Monitor log | `logread \| grep -i omega-led-monitor \| tail -40` |
| Runtime syntax | `sh -n /usr/sbin/omega-led-monitor` |
| Init syntax | `sh -n /etc/init.d/omega-led-monitor` |
| Configuration | `uci show omega-led-monitor` |
| Example LAN link | `cat /sys/class/net/lan2/carrier` |
| Nextcloud interface | `ip link show nc-veth` |
| USER1 brightness | `cat /sys/class/leds/rgb:indicator-1/brightness` |
| Monitor process | `ps w \| grep '[o]mega-led-monitor'` |
| Backups | `ls -lah /srv/backups/omega-led-monitor/` |

---

## Repository structure

```text
Omega-LED-Monitor/
├── install_omega_led_monitor.sh  # Installer containing the runtime monitor and init service
└── README.md                     # Project and installation documentation
```

Installed layout on the router:

```text
/etc/config/omega-led-monitor     # UCI configuration
/etc/init.d/omega-led-monitor     # procd init service
/usr/sbin/omega-led-monitor       # Runtime monitor
/srv/backups/omega-led-monitor/   # Timestamped backups
```

<p align="right">#readme-topBack to top</a></p>

---

## Technical references

- [Linux Multicolor LED Class documentation](https://www.kernel.org/doc/html/latest/leds/leds-class-multicolor.html)
- [OpenWrt procd init script documentation](https://openwrt.org/docs/guide-developer/procd-init-scripts)
- [OMEGA LED Monitor repository](https://github.com/hansekiter/Omega-LED-Monitor)
- [Installation script](https://github.com/hansekiter/Omega-LED-Monitor)

---

## Safety and operational notes

- Review the installer before executing it as root.
- Keep the timestamped backups until the new LED behavior has been fully validated.
- Do not assume that interface and block-device names are identical on another router.
- Avoid unnecessary write-heavy tests on the internal eMMC storage.
- The LED colors provide a visual load trend, not an exact bandwidth or storage benchmark.
- The configured maximum rates are visualization thresholds, not automatically detected hardware limits.
- Direct sysfs writes intentionally override other LED triggers while the monitor is active.
- The installer must run as root and changes central LED configuration files.
- A backup does not replace verifying that the correct backup set is restored.

---

## Contributing

Contributions are especially welcome for:

- configurable LAN interface lists
- improved validation and diagnostics
- automated shell linting
- tests for rate and color calculations
- safer preservation of custom configuration values during upgrades
- support for additional Turris Omnia configurations
- documentation improvements

When submitting changes:

1. Preserve compatibility with `/bin/sh` on Turris OS.
2. Validate scripts with `sh -n`.
3. Document new UCI options.
4. Do not claim support for hardware that has not been tested.
5. Preserve the installer’s backup and fail-safe behavior.
6. Explicitly document changed interface and device assumptions.

---

## License

This repository currently does not contain a license file. Until a license is added, standard copyright rules apply. Rights to reuse, modify, or redistribute the project are not explicitly granted.

A future release should add a `LICENSE` file and document the selected license here.

---

## Disclaimer

OMEGA LED Monitor is a router customization project. The installer changes system configuration and controls hardware LEDs directly through sysfs.

The software is provided without warranty. Review the script, verify the expected device layout, and keep usable backups before starting the installation.

---

<div align="center">

**Built for OMEGA, powered by Turris Omnia and one very visible load gradient.**

#readme-top

</div>
