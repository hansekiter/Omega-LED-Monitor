#!/bin/sh
# Installer for omega-led-monitor on Turris Omnia / Turris OS 9.x
# Replaces dynamic LED handling with a sysfs multicolor LED monitor.
# Run as root on the router.

set -eu

PROGRAM=/usr/sbin/omega-led-monitor
INIT=/etc/init.d/omega-led-monitor
UCI_CONFIG=/etc/config/omega-led-monitor
BACKUP_DIR=/srv/backups/omega-led-monitor
STAMP="$(date +%Y%m%d-%H%M%S)"

log() { printf '%s\n' "[omega-led-install] $*"; }
die() { printf '%s\n' "[omega-led-install] ERROR: $*" >&2; exit 1; }

[ "$(id -u)" = "0" ] || die "Bitte als root ausfuehren."
command -v uci >/dev/null 2>&1 || die "uci wurde nicht gefunden."
[ -d /sys/class/leds ] || die "/sys/class/leds fehlt."

for LED in power wan lan-0 lan-1 lan-2 lan-3 lan-4 wlan-1 wlan-2 wlan-3 indicator-1 indicator-2; do
    [ -d "/sys/class/leds/rgb:$LED" ] || die "LED rgb:$LED fehlt. Abbruch ohne Aenderung."
done

mkdir -p "$BACKUP_DIR/$STAMP"
if [ -f /etc/config/rainbow ]; then cp -a /etc/config/rainbow "$BACKUP_DIR/$STAMP/rainbow"; fi
if [ -f /etc/config/system ]; then cp -a /etc/config/system "$BACKUP_DIR/$STAMP/system"; fi
if [ -f "$PROGRAM" ]; then cp -a "$PROGRAM" "$BACKUP_DIR/$STAMP/omega-led-monitor"; fi
if [ -f "$INIT" ]; then cp -a "$INIT" "$BACKUP_DIR/$STAMP/omega-led-monitor.init"; fi
if [ -f "$UCI_CONFIG" ]; then cp -a "$UCI_CONFIG" "$BACKUP_DIR/$STAMP/omega-led-monitor.config"; fi
log "Sicherung erstellt: $BACKUP_DIR/$STAMP"

if [ -x "$INIT" ]; then
    "$INIT" stop >/dev/null 2>&1 || true
    "$INIT" disable >/dev/null 2>&1 || true
fi

# Remove legacy OpenWrt LED sections to avoid competing kernel triggers.
# Other sections in /etc/config/system are preserved.
while :; do
    SECTION="$(uci -q show system | sed -n 's/^system\.\([^=]*\)=led$/\1/p' | head -n 1)"
    [ -n "$SECTION" ] || break
    log "Entferne konkurrierende LED-Sektion system.$SECTION"
    uci -q delete "system.$SECTION"
done
uci commit system

# Clear old rainbow defaults. The program writes directly to multicolor sysfs.
: > /etc/config/rainbow

cat > "$UCI_CONFIG" <<'EOF_CONFIG'
config monitor 'main'
    option enabled '1'
    option interval '0.25'
    option tick_factor '4'

    option wan_interface 'eth2'
    option wlan1_interface 'phy0ap0'
    option wlan2_interface 'phy1ap0'
    option nextcloud_interface 'nc-veth'

    # 100 percent thresholds, bytes per second
    option wan_max_bps '37500000'
    option lan_max_bps '37500000'
    option wlan1_max_bps '37500000'
    option wlan2_max_bps '37500000'
    option sda_max_bps '104857600'
    option emmc_max_bps '20971520'
    option nextcloud_max_bps '12500000'

    # Below these rates a connected/available resource is treated as idle
    option net_idle_threshold '2048'
    option disk_idle_threshold '4096'
EOF_CONFIG

cat > "$PROGRAM" <<'EOF_PROGRAM'
#!/bin/sh

CONFIG="omega-led-monitor.main"

get_cfg() {
    local key="$1" default="$2" value
    value="$(uci -q get "${CONFIG}.${key}")"
    [ -n "$value" ] || value="$default"
    printf '%s\n' "$value"
}

read_counter() {
    [ -r "$1" ] && cat "$1" || echo 0
}

read_net_total() {
    local dev="$1" rx tx
    rx="$(read_counter "/sys/class/net/$dev/statistics/rx_bytes")"
    tx="$(read_counter "/sys/class/net/$dev/statistics/tx_bytes")"
    echo $((rx + tx))
}

net_exists() {
    [ -d "/sys/class/net/$1" ]
}

net_has_carrier() {
    local carrier="/sys/class/net/$1/carrier"
    [ -d "/sys/class/net/$1" ] || return 1
    [ -r "$carrier" ] || return 1
    [ "$(cat "$carrier" 2>/dev/null)" = "1" ]
}

read_block_sectors() {
    local file="/sys/class/block/$1/stat"
    local read_ios read_merges read_sectors read_ticks
    local write_ios write_merges write_sectors rest
    [ -r "$file" ] || { echo 0; return; }
    read -r read_ios read_merges read_sectors read_ticks \
        write_ios write_merges write_sectors rest < "$file"
    echo $((read_sectors + write_sectors))
}

safe_delta() {
    if [ "$1" -ge "$2" ] 2>/dev/null; then
        echo $(($1 - $2))
    else
        echo 0
    fi
}

utilization_level() {
    local rate="$1" maximum="$2"
    [ "$maximum" -gt 0 ] 2>/dev/null || maximum=1
    [ "$rate" -ge 0 ] 2>/dev/null || rate=0
    if [ "$rate" -ge "$maximum" ]; then echo 1000; else echo $((rate * 1000 / maximum)); fi
}

rate_rgb() {
    local level red green
    level="$(utilization_level "$1" "$2")"
    if [ "$level" -le 500 ]; then
        red=$((255 * level / 500)); green=255
    else
        red=255; green=$((255 * (1000 - level) / 500))
    fi
    [ "$green" -ge 0 ] || green=0
    printf '%s %s 0\n' "$red" "$green"
}

set_led_rgb() {
    local led="$1" red="$2" green="$3" blue="$4"
    local dir="/sys/class/leds/rgb:$1" index values="" value channel
    [ -d "$dir" ] || return 0
    [ -w "$dir/multi_intensity" ] || return 0
    [ -w "$dir/trigger" ] && echo none > "$dir/trigger" 2>/dev/null || true
    index="$(cat "$dir/multi_index" 2>/dev/null)"
    for channel in $index; do
        case "$channel" in red) value="$red";; green) value="$green";; blue) value="$blue";; *) value=0;; esac
        [ -z "$values" ] && values="$value" || values="$values $value"
    done
    [ -n "$values" ] && echo "$values" > "$dir/multi_intensity"
}

set_led_brightness_percent() {
    local dir="/sys/class/leds/rgb:$1" percent="$2" maximum brightness
    [ -d "$dir" ] || return 0
    [ -w "$dir/brightness" ] || return 0
    [ "$percent" -ge 0 ] 2>/dev/null || percent=0
    [ "$percent" -le 100 ] 2>/dev/null || percent=100
    maximum="$(cat "$dir/max_brightness" 2>/dev/null)"; [ -n "$maximum" ] || maximum=255
    brightness=$((maximum * percent / 100))
    [ "$percent" -gt 0 ] && [ "$brightness" -lt 1 ] && brightness=1
    echo "$brightness" > "$dir/brightness"
}

led_off() {
    local dir="/sys/class/leds/rgb:$1"
    [ -d "$dir" ] || return 0
    [ -w "$dir/trigger" ] && echo none > "$dir/trigger" 2>/dev/null || true
    [ -w "$dir/brightness" ] && echo 0 > "$dir/brightness"
}

idle_brightness() {
    case "$1" in
        0) echo 8;; 1) echo 9;; 2) echo 11;; 3) echo 13;;
        4) echo 16;; 5) echo 19;; 6) echo 22;; 7|8) echo 25;;
        9) echo 22;; 10) echo 19;; 11) echo 16;; 12) echo 13;;
        13) echo 11;; 14) echo 9;; *) echo 8;;
    esac
}

set_animated_led() {
    local led="$1" rate="$2" maximum="$3" idle_threshold="$4" phase="$5"
    local rgb level red green blue high low brightness
    if [ "$rate" -le "$idle_threshold" ] 2>/dev/null; then
        set_led_rgb "$led" 0 255 0
        set_led_brightness_percent "$led" "$(idle_brightness "$phase")"
        return
    fi
    level="$(utilization_level "$rate" "$maximum")"
    rgb="$(rate_rgb "$rate" "$maximum")"; set -- $rgb
    red="$1"; green="$2"; blue="$3"
    set_led_rgb "$led" "$red" "$green" "$blue"
    high=$((50 + level * 50 / 1000))
    low=$((25 + level * 75 / 1000))
    if [ "$level" -ge 950 ]; then brightness=100
    elif [ $((phase % 2)) -eq 0 ]; then brightness="$high"
    else brightness="$low"
    fi
    set_led_brightness_percent "$led" "$brightness"
}

ENABLED="$(get_cfg enabled 1)"
INTERVAL="$(get_cfg interval 0.25)"
TICK_FACTOR="$(get_cfg tick_factor 4)"
WAN_IF="$(get_cfg wan_interface eth2)"
WLAN1_IF="$(get_cfg wlan1_interface phy0ap0)"
WLAN2_IF="$(get_cfg wlan2_interface phy1ap0)"
NC_IF="$(get_cfg nextcloud_interface nc-veth)"
WAN_MAX="$(get_cfg wan_max_bps 37500000)"
LAN_MAX="$(get_cfg lan_max_bps 37500000)"
WLAN1_MAX="$(get_cfg wlan1_max_bps 37500000)"
WLAN2_MAX="$(get_cfg wlan2_max_bps 37500000)"
SDA_MAX="$(get_cfg sda_max_bps 104857600)"
EMMC_MAX="$(get_cfg emmc_max_bps 20971520)"
NC_MAX="$(get_cfg nextcloud_max_bps 12500000)"
NET_IDLE="$(get_cfg net_idle_threshold 2048)"
DISK_IDLE="$(get_cfg disk_idle_threshold 4096)"
[ "$ENABLED" = "1" ] || exit 0
case "$TICK_FACTOR" in ''|*[!0-9]*) TICK_FACTOR=4;; esac
[ "$TICK_FACTOR" -ge 1 ] || TICK_FACTOR=4

cleanup() {
    local led
    for led in wan lan-0 lan-1 lan-2 lan-3 lan-4 wlan-1 wlan-2 wlan-3 indicator-1 indicator-2; do led_off "$led"; done
    set_led_rgb power 0 255 0
    set_led_brightness_percent power 50
    exit 0
}
trap cleanup INT TERM

wan_old="$(read_counter "/sys/class/net/$WAN_IF/statistics/rx_bytes")"
lan0_old="$(read_net_total lan0)"; lan1_old="$(read_net_total lan1)"; lan2_old="$(read_net_total lan2)"
lan3_old="$(read_net_total lan3)"; lan4_old="$(read_net_total lan4)"
wlan1_old="$(read_net_total "$WLAN1_IF")"; wlan2_old="$(read_net_total "$WLAN2_IF")"
nc_old="$(read_net_total "$NC_IF")"
sda_old="$(read_block_sectors sda)"; emmc_old="$(read_block_sectors mmcblk0)"
PHASE=0
set_led_rgb power 0 255 0
set_led_brightness_percent power 50
logger -t omega-led-monitor "gestartet: WAN=$WAN_IF, LAN=lan0..lan4, NC=$NC_IF"

while :; do
    sleep "$INTERVAL"
    wan_new="$(read_counter "/sys/class/net/$WAN_IF/statistics/rx_bytes")"
    lan0_new="$(read_net_total lan0)"; lan1_new="$(read_net_total lan1)"; lan2_new="$(read_net_total lan2)"
    lan3_new="$(read_net_total lan3)"; lan4_new="$(read_net_total lan4)"
    wlan1_new="$(read_net_total "$WLAN1_IF")"; wlan2_new="$(read_net_total "$WLAN2_IF")"
    nc_new="$(read_net_total "$NC_IF")"
    sda_new="$(read_block_sectors sda)"; emmc_new="$(read_block_sectors mmcblk0)"

    wan_rate=$(( $(safe_delta "$wan_new" "$wan_old") * TICK_FACTOR ))
    lan0_rate=$(( $(safe_delta "$lan0_new" "$lan0_old") * TICK_FACTOR ))
    lan1_rate=$(( $(safe_delta "$lan1_new" "$lan1_old") * TICK_FACTOR ))
    lan2_rate=$(( $(safe_delta "$lan2_new" "$lan2_old") * TICK_FACTOR ))
    lan3_rate=$(( $(safe_delta "$lan3_new" "$lan3_old") * TICK_FACTOR ))
    lan4_rate=$(( $(safe_delta "$lan4_new" "$lan4_old") * TICK_FACTOR ))
    wlan1_rate=$(( $(safe_delta "$wlan1_new" "$wlan1_old") * TICK_FACTOR ))
    wlan2_rate=$(( $(safe_delta "$wlan2_new" "$wlan2_old") * TICK_FACTOR ))
    nc_rate=$(( $(safe_delta "$nc_new" "$nc_old") * TICK_FACTOR ))
    sda_rate=$(( $(safe_delta "$sda_new" "$sda_old") * 512 * TICK_FACTOR ))
    emmc_rate=$(( $(safe_delta "$emmc_new" "$emmc_old") * 512 * TICK_FACTOR ))

    net_has_carrier "$WAN_IF" && set_animated_led wan "$wan_rate" "$WAN_MAX" "$NET_IDLE" "$PHASE" || led_off wan
    net_has_carrier lan0 && set_animated_led lan-0 "$lan0_rate" "$LAN_MAX" "$NET_IDLE" "$PHASE" || led_off lan-0
    net_has_carrier lan1 && set_animated_led lan-1 "$lan1_rate" "$LAN_MAX" "$NET_IDLE" "$PHASE" || led_off lan-1
    net_has_carrier lan2 && set_animated_led lan-2 "$lan2_rate" "$LAN_MAX" "$NET_IDLE" "$PHASE" || led_off lan-2
    net_has_carrier lan3 && set_animated_led lan-3 "$lan3_rate" "$LAN_MAX" "$NET_IDLE" "$PHASE" || led_off lan-3
    net_has_carrier lan4 && set_animated_led lan-4 "$lan4_rate" "$LAN_MAX" "$NET_IDLE" "$PHASE" || led_off lan-4
    net_exists "$WLAN1_IF" && set_animated_led wlan-1 "$wlan1_rate" "$WLAN1_MAX" "$NET_IDLE" "$PHASE" || led_off wlan-1
    net_exists "$WLAN2_IF" && set_animated_led wlan-2 "$wlan2_rate" "$WLAN2_MAX" "$NET_IDLE" "$PHASE" || led_off wlan-2
    [ -r /sys/class/block/sda/stat ] && set_animated_led wlan-3 "$sda_rate" "$SDA_MAX" "$DISK_IDLE" "$PHASE" || led_off wlan-3
    net_exists "$NC_IF" && set_animated_led indicator-1 "$nc_rate" "$NC_MAX" "$NET_IDLE" "$PHASE" || led_off indicator-1
    [ -r /sys/class/block/mmcblk0/stat ] && set_animated_led indicator-2 "$emmc_rate" "$EMMC_MAX" "$DISK_IDLE" "$PHASE" || led_off indicator-2

    wan_old="$wan_new"
    lan0_old="$lan0_new"; lan1_old="$lan1_new"; lan2_old="$lan2_new"; lan3_old="$lan3_new"; lan4_old="$lan4_new"
    wlan1_old="$wlan1_new"; wlan2_old="$wlan2_new"; nc_old="$nc_new"
    sda_old="$sda_new"; emmc_old="$emmc_new"
    PHASE=$(( (PHASE + 1) % 16 ))
done
EOF_PROGRAM
chmod 755 "$PROGRAM"

cat > "$INIT" <<'EOF_INIT'
#!/bin/sh /etc/rc.common

START=99
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/sbin/omega-led-monitor
    procd_set_param respawn 5 10 5
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param term_timeout 5
    procd_close_instance
}

service_triggers() {
    procd_add_reload_trigger omega-led-monitor
}

reload_service() {
    stop
    start
}
EOF_INIT
chmod 755 "$INIT"

sh -n "$PROGRAM" || die "Syntaxfehler im Monitorprogramm."
sh -n "$INIT" || die "Syntaxfehler im Init-Skript."

# Verify fractional sleep. Fall back to 0.5 s if necessary.
if ! sleep 0.25 2>/dev/null; then
    log "sleep 0.25 wird nicht unterstuetzt; verwende 0.5 Sekunden."
    uci set omega-led-monitor.main.interval='0.5'
    uci set omega-led-monitor.main.tick_factor='2'
    uci commit omega-led-monitor
fi

"$INIT" enable
"$INIT" restart
sleep 3

if "$INIT" running; then
    log "Installation erfolgreich. Dienst laeuft."
else
    log "Dienst laeuft nicht. Letzte Meldungen:"
    logread | grep -iE 'omega-led-monitor|crash|syntax|not found' | tail -n 40 || true
    exit 1
fi

log "Konfiguration: $UCI_CONFIG"
log "Programm:      $PROGRAM"
log "Init-Dienst:   $INIT"
log "Backup:        $BACKUP_DIR/$STAMP"
log "Status:        $INIT running"
