<a id="readme-top"></a>

<div align="center">

# 🌈 OMEGA LED Monitor

**Netzwerk-, Speicher- und Containeraktivität direkt auf den RGB-LEDs eines Turris-Omnia-Routers sichtbar machen.**

[![Status](https://img.shields.io/badge/Status-einsatzbereit-brightgreen)](#projektstatus)
[![Plattform](https://img.shields.io/badge/Plattform-Turris%20Omnia-00AEEF)](#voraussetzungen)
[![Turris OS](https://img.shields.io/badge/Turris%20OS-9.x-00AEEF)](#voraussetzungen)
[![Sprache](https://img.shields.io/badge/Sprache-POSIX%20Shell-4EAA25?logo=gnu-bash&logoColor=white)](#programmiersprache-und-technologien)
[![Dienst](https://img.shields.io/badge/Dienst-procd-6A5ACD)](#architektur)
[![Konfiguration](https://img.shields.io/badge/Konfiguration-UCI-FF8800)](#konfiguration)
[![Lizenz](https://img.shields.io/badge/Lizenz-nicht%20festgelegt-lightgrey)](#lizenz)

OMEGA LED Monitor ersetzt die dynamische Standard-LED-Steuerung eines Turris Omnia durch einen konfigurierbaren Monitor für Linkzustände, Netzwerkverkehr, WLAN-Aktivität, Speicher-I/O und einen Nextcloud-LXC-Container.

[Schnellstart](#schnellstart) •
[LED-Zuordnung](#led-zuordnung) •
[Konfiguration](#konfiguration) •
[Fehlerbehebung](#fehlerbehebung) •
[Deinstallation](#deinstallation)

</div>

---

## ✨ Projekt-Highlights

- 🌐 Visualisiert WAN-, LAN- und WLAN-Aktivität direkt am Router
- 💾 Zeigt I/O-Aktivität einer SSD auf `/dev/sda` und des internen eMMC-Speichers auf `/dev/mmcblk0`
- 📦 Nutzt `indicator-1` beziehungsweise `USER1` für die Netzwerkaktivität eines Nextcloud-LXC-Containers
- 🌬️ Stellt verfügbare, aber inaktive Ressourcen durch sanftes grünes Atmen dar
- 🚦 Wechselt bei steigender Last von Grün über Gelb und Orange nach Rot
- 🔌 Schaltet LEDs nicht verbundener WAN- und LAN-Ports vollständig aus
- ⚙️ Verwendet UCI für Schnittstellennamen, Schwellenwerte und Messintervall
- 🛡️ Erstellt vor Änderungen zeitgestempelte Sicherungen bestehender LED-Regeln
- 🔄 Läuft als überwachter OpenWrt-`procd`-Dienst und startet automatisch beim Booten
- 🧰 Installiert Monitor, Konfiguration und Init-Dienst über ein einzelnes Shell-Skript

---

## 🚦 Projektstatus

| Bereich | Status |
|---|---|
| Installer | 🟢 vorhanden |
| Laufzeitmonitor | 🟢 wird vom Installer erzeugt und installiert |
| UCI-Konfiguration | 🟢 enthalten |
| `procd`-Dienst | 🟢 enthalten |
| automatische Sicherung | 🟢 enthalten |
| Zielplattform Turris Omnia / Turris OS 9.x | 🟢 dokumentiert |
| andere Routermodelle | ⚪ nicht unterstützt oder validiert |
| automatisierte CI-Tests | ⚪ nicht vorhanden |
| Lizenzdatei | ⚪ nicht vorhanden |

> [!IMPORTANT]
> Der Installer ist auf eine konkrete Turris-Omnia-Konfiguration zugeschnitten. Prüfe vor dem Start die erwarteten LED-, Netzwerk- und Blockgerätenamen.

---

## 🧭 Inhaltsverzeichnis

- [Funktionsweise](#funktionsweise)
- [LED-Verhalten](#led-verhalten)
- [LED-Zuordnung](#led-zuordnung)
- [Voraussetzungen](#voraussetzungen)
- [Programmiersprache und Technologien](#programmiersprache-und-technologien)
- [Architektur](#architektur)
- [Schnellstart](#schnellstart)
- [Änderungen durch den Installer](#änderungen-durch-den-installer)
- [Funktionsprüfung](#funktionsprüfung)
- [Konfiguration](#konfiguration)
- [Kalibrierungsbeispiele](#kalibrierungsbeispiele)
- [Fehlerbehebung](#fehlerbehebung)
- [Wartung und Updates](#wartung-und-updates)
- [Deinstallation](#deinstallation)
- [Befehlsübersicht](#befehlsübersicht)
- [Repositorystruktur](#repositorystruktur)
- [Technische Referenzen](#technische-referenzen)
- [Sicherheits- und Betriebshinweise](#sicherheits--und-betriebshinweise)
- [Mitwirken](#mitwirken)
- [Lizenz](#lizenz)
- [Haftungsausschluss](#haftungsausschluss)

---

## Funktionsweise

OMEGA LED Monitor steuert die RGB-LEDs des Turris Omnia über die Linux-Multicolor-LED-Schnittstelle unter `/sys/class/leds/rgb:*`.

Farbe und Helligkeit werden getrennt geregelt:

- `multi_intensity` bestimmt die RGB-Farbkanäle
- `brightness` bestimmt die Gesamthelligkeit
- `trigger` wird auf `none` gesetzt, damit keine Kernel-Trigger mit dem Monitor konkurrieren

Der Monitor liest Netzwerk- und Blockgeräte-Zähler, berechnet daraus Aktivitätsraten und übersetzt diese in Farb- und Helligkeitsanimationen.

<p align="right"><a href="#readme-top">Nach oben</a></p>

---

## LED-Verhalten

### Leerlauf

Eine verbundene oder verfügbare Ressource mit Aktivität unterhalb der eingestellten Idle-Schwelle atmet grün zwischen ungefähr **8 % und 25 % Helligkeit**.

### Aktivität

Bei Aktivität beginnt die LED ab **50 % Helligkeit** zu flackern. Mit steigender Last ändert sich die Farbe:

```text
Grün → Gelb → Orange → Rot
```

Ab der konfigurierten Maximalrate leuchtet die LED rot mit 100 % Helligkeit.

### Nicht verfügbare Ressourcen

- Eine WAN- oder LAN-LED bleibt aus, wenn die zugehörige Schnittstelle keinen physischen Link meldet.
- `USER1` bleibt aus, wenn das konfigurierte Nextcloud-Hostinterface nicht existiert.
- Speicher-LEDs bleiben aus, wenn die Statistik des Blockgeräts nicht verfügbar ist.
- WLAN-LEDs bleiben aus, wenn die konfigurierte WLAN-Schnittstelle nicht existiert.

<p align="right"><a href="#readme-top">Nach oben</a></p>

---

## LED-Zuordnung

| Omnia-LED | Datenquelle | Verhalten |
|---|---|---|
| `power` | Router- beziehungsweise Prozesszustand | konstant grün bei 50 % Helligkeit |
| `wan` | Empfangsverkehr von `eth2` | ohne Link aus, im Leerlauf atmend, bei Last farbig |
| `lan-0` bis `lan-4` | `lan0` bis `lan4`, RX + TX | nur bei physischem Link aktiv |
| `wlan-1` | `phy0ap0`, RX + TX | Leerlaufatmen und lastabhängige Farbe |
| `wlan-2` | `phy1ap0`, RX + TX | Leerlaufatmen und lastabhängige Farbe |
| `wlan-3` | `/dev/sda`, vorgesehen für `/srv` | Block-I/O aus `/sys/class/block/sda/stat` |
| `indicator-1` / `USER1` | `nc-veth`, vorgesehen für Nextcloud-LXC | bei fehlendem Interface aus, sonst Leerlauf- oder Lastanzeige |
| `indicator-2` / `USER2` | `/dev/mmcblk0`, interner eMMC | Block-I/O-Anzeige |

> [!NOTE]
> Die WAN-Anzeige verwendet derzeit nur den RX-Zähler. LAN, WLAN und Nextcloud verwenden jeweils die Summe aus RX und TX.

<p align="right"><a href="#readme-top">Nach oben</a></p>

---

## Voraussetzungen

Der mitgelieferte Installer erwartet:

- einen **Turris Omnia** mit **Turris OS 9.x**
- Root-Zugriff über SSH
- `uci`
- RGB-LEDs unter `/sys/class/leds/rgb:*`
- WAN-Schnittstelle `eth2`
- LAN-Schnittstellen `lan0` bis `lan4`
- WLAN-Schnittstellen `phy0ap0` und `phy1ap0`
- `/srv` auf `/dev/sda`
- internen Speicher auf `/dev/mmcblk0`
- ein hostseitiges Nextcloud-LXC-Interface mit dem Namen `nc-veth`
- ausreichend freien Speicher unter `/srv/backups/omega-led-monitor/`

Der Installer prüft UCI und alle erwarteten RGB-LED-Verzeichnisse, bevor er die eigentlichen Änderungen durchführt.

### Erwartete RGB-LED-Namen

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

<p align="right"><a href="#readme-top">Nach oben</a></p>

---

## Programmiersprache und Technologien

| Sprache oder Technologie | Einsatz |
|---|---|
| POSIX Shell (`/bin/sh`) | Installer, Laufzeitmonitor und Init-Dienst |
| UCI | persistente Konfiguration unter `/etc/config/omega-led-monitor` |
| OpenWrt `procd` | Dienstüberwachung, Respawn und Autostart |
| Linux sysfs | Zugriff auf RGB-LEDs, Netzwerkzähler und Blockgeräte-Zähler |
| Linux Multicolor LED Class | getrennte Farb- und Helligkeitssteuerung |
| SCP / SFTP / SSH | Übertragung, Installation und Administration |

Das Repository besteht aktuell aus einem Shell-Installer. Dieser schreibt den Laufzeitmonitor und den `procd`-Init-Dienst auf den Router.

<p align="right"><a href="#readme-top">Nach oben</a></p>

---

## Architektur

```text
install_omega_led_monitor.sh
│
├── prüft Root, UCI und erwartete RGB-LEDs
├── sichert vorhandene LED- und Monitorkonfiguration
├── entfernt konkurrierende OpenWrt-LED-Sektionen
├── leert ältere Rainbow-Regeln
├── schreibt /etc/config/omega-led-monitor
├── schreibt /usr/sbin/omega-led-monitor
├── schreibt /etc/init.d/omega-led-monitor
├── prüft die Shell-Syntax
├── aktiviert den Dienst beim Booten
└── startet und prüft den Dienst

/usr/sbin/omega-led-monitor
│
├── liest die UCI-Konfiguration
├── liest Netzwerk-Bytezähler
├── liest Blockgeräte-Sektorzähler
├── berechnet Aktivitätsraten pro Sekunde
├── übersetzt Aktivität in RGB und Helligkeit
└── schreibt direkt in Multicolor-LED-sysfs

/etc/init.d/omega-led-monitor
│
└── führt den Monitor unter procd mit Respawn aus
```

### Ratenberechnung

- Netzwerkwerte basieren auf Zählerdifferenzen multipliziert mit `tick_factor`.
- Speicherwerte basieren auf Sektordifferenzen multipliziert mit 512 Byte und `tick_factor`.
- Bei einem Zählerrücksprung wird die Differenz auf null gesetzt.
- Die Aktivität wird relativ zur eingestellten Maximalrate auf eine interne Skala von 0 bis 1000 normiert.

### Farbberechnung

Die normierte Auslastung wird in zwei Abschnitten umgesetzt:

1. In der unteren Hälfte steigt Rot von 0 auf 255, während Grün bei 255 bleibt.
2. In der oberen Hälfte bleibt Rot bei 255, während Grün auf 0 fällt.
3. Blau bleibt bei 0.

Dadurch entsteht der Verlauf:

```text
Grün → Gelb → Orange → Rot
```

### Dienstüberwachung

Der erzeugte Init-Dienst verwendet:

```text
START=99
STOP=10
USE_PROCD=1
respawn 5 10 5
term_timeout 5
```

<p align="right"><a href="#readme-top">Nach oben</a></p>

---

## Schnellstart

> [!WARNING]
> Der Installer entfernt bestehende UCI-Sektionen vom Typ `led` aus `/etc/config/system` und leert `/etc/config/rainbow`. Zuvor werden Sicherungen erstellt. Prüfe trotzdem das Skript und die Zielkonfiguration deines Routers.

### 1. Installer herunterladen

Lade [`install_omega_led_monitor.sh`](install_omega_led_monitor.sh) aus diesem Repository herunter.

Alternativ kann die Datei direkt auf dem Router heruntergeladen werden:

```bash
cd /root
wget https://raw.githubusercontent.com/hansekiter/Omega-LED-Monitor/main/install_omega_led_monitor.sh
```

### 2. Datei vom eigenen Rechner übertragen

```bash
scp install_omega_led_monitor.sh root@10.0.0.1:/root/
```

Passe `10.0.0.1` an, wenn dein Router eine andere Management-Adresse verwendet. Alternativ kann SFTP verwendet werden.

### 3. Verbinden und Syntax prüfen

```bash
ssh root@10.0.0.1
chmod 700 /root/install_omega_led_monitor.sh
sh -n /root/install_omega_led_monitor.sh
echo "Syntax=$?"
```

Erwartetes Ergebnis:

```text
Syntax=0
```

### 4. Installer ausführen

```bash
/root/install_omega_led_monitor.sh
```

Der Installer aktiviert den Dienst, startet ihn und prüft anschließend, ob er läuft.

### 5. Dienststatus prüfen

```bash
/etc/init.d/omega-led-monitor enabled
echo "enabled=$?"
/etc/init.d/omega-led-monitor running
echo "running=$?"
```

Für beide Prüfungen wird erwartet:

```text
0
```

<p align="right"><a href="#readme-top">Nach oben</a></p>

---

## Änderungen durch den Installer

Der Installer erledigt automatisch:

1. Prüfung von Root-Zugriff, UCI und allen erwarteten RGB-LED-Pfaden.
2. Anlegen eines zeitgestempelten Sicherungsordners unter:

   ```text
   /srv/backups/omega-led-monitor/YYYYMMDD-HHMMSS/
   ```

3. Sicherung vorhandener Versionen von:

   ```text
   /etc/config/system
   /etc/config/rainbow
   /etc/config/omega-led-monitor
   /usr/sbin/omega-led-monitor
   /etc/init.d/omega-led-monitor
   ```

4. Stoppen und Deaktivieren einer älteren Installation.
5. Entfernen aller UCI-Sektionen vom Typ `led` aus `/etc/config/system`.
6. Leeren von `/etc/config/rainbow`, damit ältere Rainbow-Regeln nicht mit der direkten sysfs-Steuerung konkurrieren.
7. Erstellen von `/etc/config/omega-led-monitor`.
8. Erstellen von `/usr/sbin/omega-led-monitor`.
9. Erstellen von `/etc/init.d/omega-led-monitor`.
10. Syntaxprüfung der erzeugten Shell-Dateien mit `sh -n`.
11. Prüfung, ob `sleep 0.25` unterstützt wird.
12. Automatischer Wechsel auf 0,5 Sekunden und `tick_factor=2`, falls 0,25 Sekunden nicht unterstützt werden.
13. Aktivieren und Starten des Dienstes.
14. Prüfung, ob der Dienst tatsächlich läuft.

> [!CAUTION]
> Das Entfernen der UCI-LED-Sektionen ist nicht auf Regeln dieses Projekts begrenzt. Prüfe `/etc/config/system` vor der Installation, wenn du weitere eigene OpenWrt-LED-Regeln verwendest.

### Erzeugte Dateien

| Pfad | Zweck |
|---|---|
| `/etc/config/omega-led-monitor` | UCI-Konfiguration |
| `/usr/sbin/omega-led-monitor` | eigentlicher Laufzeitmonitor |
| `/etc/init.d/omega-led-monitor` | `procd`-Init-Dienst |
| `/srv/backups/omega-led-monitor/<Zeitstempel>/` | Sicherungen vorheriger Dateien und Konfigurationen |

<p align="right"><a href="#readme-top">Nach oben</a></p>

---

## Funktionsprüfung

### Dienst und Prozess

```bash
/etc/init.d/omega-led-monitor enabled
echo "enabled=$?"
/etc/init.d/omega-led-monitor running
echo "running=$?"
ps w | grep '[o]mega-led-monitor'
```

Es sollte genau ein Monitorprozess laufen.

### Protokoll

```bash
logread | grep -iE 'omega-led-monitor|crash|syntax|not found' | tail -40
```

Nach erfolgreicher Installation sollten keine neuen Syntax-, `not found`- oder Crash-Loop-Meldungen erscheinen.

### LAN-Linkzustand

```bash
for DEV in lan0 lan1 lan2 lan3 lan4; do
    printf '%s=' "$DEV"
    cat "/sys/class/net/$DEV/carrier" 2>/dev/null || echo '?'
done
```

Erwartetes Verhalten:

- `carrier=1`: zugehörige LED ist aktiv
- `carrier=0`: zugehörige LED bleibt aus

### Nextcloud-LXC

```bash
lxc-info -n nextcloud
ip link show nc-veth
```

Wenn `nc-veth` existiert, zeigt `USER1` Leerlauf oder Netzwerkaktivität. Verschwindet das Interface, geht `USER1` aus.

Beispiel für einen Stop-/Start-Test:

```bash
lxc-stop -n nextcloud
sleep 2
lxc-start -n nextcloud -d
```

### SSD-Aktivität

```bash
dd if=/dev/zero of=/srv/led-test.bin bs=1M count=256 conv=fsync
rm -f /srv/led-test.bin
```

### Interner eMMC-Speicher

Verwende einen reinen Lesetest, um unnötige Schreiblast zu vermeiden:

```bash
dd if=/dev/mmcblk0 of=/dev/null bs=1M count=32
```

<p align="right"><a href="#readme-top">Nach oben</a></p>

---

## Konfiguration

Die Konfiguration liegt unter:

```text
/etc/config/omega-led-monitor
```

Aktuelle Werte anzeigen:

```bash
uci show omega-led-monitor
```

Änderungen übernehmen:

```bash
uci commit omega-led-monitor
/etc/init.d/omega-led-monitor restart
```

### Standardwerte

| UCI-Option | Standard | Bedeutung |
|---|---:|---|
| `enabled` | `1` | aktiviert den Laufzeitmonitor |
| `interval` | `0.25` | Messintervall in Sekunden |
| `tick_factor` | `4` | rechnet Intervallwerte auf eine Sekunde hoch |
| `wan_interface` | `eth2` | WAN-Schnittstelle |
| `wlan1_interface` | `phy0ap0` | erste WLAN-Schnittstelle |
| `wlan2_interface` | `phy1ap0` | zweite WLAN-Schnittstelle |
| `nextcloud_interface` | `nc-veth` | hostseitiges Nextcloud-Interface |
| `wan_max_bps` | `37500000` | WAN-Rotschwelle, 300 Mbit/s |
| `lan_maxKonfiguration übernommen.

<p align="right">#readme-topNach oben</a></p>

---

## Kalibrierungsbeispiele

### LAN-Ports bereits bei 100 Mbit/s rot darstellen

```bash
uci set omega-led-monitor.main.lan_max_bps='12500000'
uci commit omega-led-monitor
/etc/init.d/omega-led-monitor restart
```

### Flackern bei geringer Aktivität reduzieren

Erhöhe die Idle-Schwelle:

```bash
uci set omega-led-monitor.main.net_idle_threshold='8192'
uci commit omega-led-monitor
/etc/init.d/omega-led-monitor restart
```

### WAN-Schnittstelle ändern

```bash
uci set omega-led-monitor.main.wan_interface='DEIN_WAN_INTERFACE'
uci commit omega-led-monitor
/etc/init.d/omega-led-monitor restart
```

### Nextcloud-Interface ändern

```bash
uci set omega-led-monitor.main.nextcloud_interface='DEIN_INTERFACE'
uci commit omega-led-monitor
/etc/init.d/omega-led-monitor restart
```

### Abstimmung

- Flackern die LEDs zu häufig, erhöhe die jeweilige Idle-Schwelle.
- Bleibt die Farbe bei realer Last fast immer grün, senke die jeweilige Maximalrate.
- Wird die LED zu schnell rot, erhöhe die Maximalrate.
- Halte `interval` und `tick_factor` konsistent.
- Für 0,25 Sekunden wird `tick_factor=4` verwendet.
- Für 0,5 Sekunden wird `tick_factor=2` verwendet.

<p align="right">#readme-topNach oben</a></p>

---

## Fehlerbehebung

### LEDs bleiben weiß oder alte Trigger greifen weiter

```bash
uci show system | grep '=led$'
cat /etc/config/rainbow
```

Nach vollständiger Installation sollte die erste Abfrage keine weiteren UCI-LED-Sektionen auflisten. In Rainbow sollten keine konkurrierenden Regeln verbleiben.

```bash
/etc/init.d/omega-led-monitor restart
```

### Dienst läuft nicht

```bash
sh -n /usr/sbin/omega-led-monitor
sh -n /etc/init.d/omega-led-monitor
/etc/init.d/omega-led-monitor restart
sleep 3
/etc/init.d/omega-led-monitor running
echo $?
logread | grep -iE 'omega-led-monitor|crash|syntax|not found' | tail -60
```

Meldet `procd` eine Crash-Schleife, stoppe den Dienst und starte das Programm im Vordergrund:

```bash
/etc/init.d/omega-led-monitor stop
/usr/sbin/omega-led-monitor
```

Die erste sichtbare Fehlermeldung im Vordergrund ist häufig aussagekräftiger als spätere Respawn-Meldungen.

### Eine bestimmte LED bleibt dunkel

`USER1` prüfen:

```bash
LED='/sys/class/leds/rgb:indicator-1'
cat "$LED/multi_index"
cat "$LED/max_brightness"
cat "$LED/trigger"
```

Direkter grüner Test:

```bash
echo none > /sys/class/leds/rgb:indicator-1/trigger
echo '0 255 0' > /sys/class/leds/rgb:indicator-1/multi_intensity
cat /sys/class/leds/rgb:indicator-1/max_brightness \
  > /sys/class/leds/rgb:indicator-1/brightness
```

Die Werte in `multi_intensity` müssen der Reihenfolge aus `multi_index` entsprechen. Das Beispiel nimmt `red green blue` an.

### Angeschlossener LAN-Port bleibt aus

```bash
for DEV in lan0 lan1 lan2 lan3 lan4; do
    printf '%s=' "$DEV"
    cat "/sys/class/net/$DEV/carrier" 2>/dev/null || echo '?'
done
```

Nur `carrier=1` gilt als physischer Link. Bleibt der Wert trotz verbundenem Kabel bei `0`, prüfe Linkaufbau und Interfacezuordnung statt der Farbberechnung.

### Nextcloud-LED bleibt aus

```bash
ip link show nc-veth
lxc-info -n nextcloud
```

Verwendet der Container ein anderes hostseitiges Interface, ändere die UCI-Konfiguration:

```bash
uci set omega-led-monitor.main.nextcloud_interface='DEIN_INTERFACE'
uci commit omega-led-monitor
/etc/init.d/omega-led-monitor restart
```

### SSD-LED bleibt aus

```bash
test -r /sys/class/block/sda/stat
echo $?
cat /sys/class/block/sda/stat
```

Prüfe außerdem, ob `/srv` tatsächlich auf `/dev/sda` liegt:

```bash
findmnt /srv
lsblk
```

### eMMC-LED bleibt aus

```bash
test -r /sys/class/block/mmcblk0/stat
echo $?
cat /sys/class/block/mmcblk0/stat
```

### Fractional Sleep wird nicht unterstützt

Der Installer erkennt diesen Fall automatisch. Manuelle Umstellung:

```bash
uci set omega-led-monitor.main.interval='0.5'
uci set omega-led-monitor.main.tick_factor='2'
uci commit omega-led-monitor
/etc/init.d/omega-led-monitor restart
```

<p align="right">#readme-topNach oben</a></p>

---

## Wartung und Updates

### Nach einem Turris-OS-Update

```bash
test -x /usr/sbin/omega-led-monitor && echo 'Programm vorhanden'
test -x /etc/init.d/omega-led-monitor && echo 'Dienst vorhanden'
/etc/init.d/omega-led-monitor running
echo "running=$?"
sh -n /usr/sbin/omega-led-monitor
```

Prüfe außerdem die erwarteten LED-, Interface- und Blockgerätenamen:

```bash
ls -1 /sys/class/leds/rgb:* 2>/dev/null
ip link show
ls -l /sys/class/block/sda /sys/class/block/mmcblk0 2>/dev/null
```

Ändert ein Update einen Schnittstellennamen, passe `/etc/config/omega-led-monitor` an und starte den Dienst neu.

### Neuinstallation oder Upgrade

Eine neuere Installer-Version kann erneut ausgeführt werden. Jeder Lauf erstellt zuvor eine neue zeitgestempelte Sicherung.

```bash
cd /root
wget -O install_omega_led_monitor.sh \
  https://raw.githubusercontent.com/hansekiter/Omega-LED-Monitor/main/install_omega_led_monitor.sh

chmod 700 install_omega_led_monitor.sh
sh -n install_omega_led_monitor.sh
./install_omega_led_monitor.sh
```

> [!CAUTION]
> Eine erneute Installation stellt die Standardwerte des Installers wieder her. Vergleiche die neue Konfiguration anschließend mit der Sicherung, wenn du vorher Schwellenwerte oder Interface-Namen angepasst hattest.

### Sicherungen anzeigen

```bash
ls -lah /srv/backups/omega-led-monitor/
```

<p align="right">#readme-topNach oben</a></p>

---

## Deinstallation

Dienst stoppen und deaktivieren:

```bash
/etc/init.d/omega-led-monitor stop
/etc/init.d/omega-led-monitor disable
```

Installierte Dateien entfernen:

```bash
rm -f /etc/init.d/omega-led-monitor
rm -f /usr/sbin/omega-led-monitor
rm -f /etc/config/omega-led-monitor
```

Benötigte Dateien aus einer zeitgestempelten Sicherung unter folgendem Pfad wiederherstellen:

```text
/srv/backups/omega-led-monitor/
```

Beispiel:

```bash
BACKUP='/srv/backups/omega-led-monitor/DEIN-ZEITSTEMPEL'

cp -a "$BACKUP/system" /etc/config/system
cp -a "$BACKUP/rainbow" /etc/config/rainbow
```

Starte abhängig von den wiederhergestellten Dateien die entsprechenden OpenWrt-LED- oder Rainbow-Dienste neu oder boote den Router:

```bash
reboot
```

> [!WARNING]
> Das Entfernen von OMEGA LED Monitor rekonstruiert die zuvor gelöschten UCI-LED-Sektionen nicht automatisch. Stelle `/etc/config/system` und `/etc/config/rainbow` aus der korrekten Sicherung wieder her, wenn du das vorherige LED-Verhalten zurückhaben möchtest.

<p align="right">#readme-topNach oben</a></p>

---

## Befehlsübersicht

| Zweck | Befehl |
|---|---|
| Laufstatus | `/etc/init.d/omega-led-monitor running; echo $?` |
| Autostartstatus | `/etc/init.d/omega-led-monitor enabled; echo $?` |
| Start | `/etc/init.d/omega-led-monitor start` |
| Stopp | `/etc/init.d/omega-led-monitor stop` |
| Neustart | `/etc/init.d/omega-led-monitor restart` |
| Monitorprotokoll | `logread \| grep -i omega-led-monitor \| tail -40` |
| Syntax des Monitors | `sh -n /usr/sbin/omega-led-monitor` |
| Syntax des Init-Skripts | `sh -n /etc/init.d/omega-led-monitor` |
| Konfiguration | `uci show omega-led-monitor` |
| LAN-Linkbeispiel | `cat /sys/class/net/lan2/carrier` |
| Nextcloud-Interface | `ip link show nc-veth` |
| USER1-Helligkeit | `cat /sys/class/leds/rgb:indicator-1/brightness` |
| Monitorprozess | `ps w \| grep '[o]mega-led-monitor'` |
| Sicherungen | `ls -lah /srv/backups/omega-led-monitor/` |

---

## Repositorystruktur

```text
Omega-LED-Monitor/
├── install_omega_led_monitor.sh  # Installer mit eingebettetem Monitor und Init-Dienst
└── README.md                     # Projekt- und Installationsdokumentation
```

Installierte Struktur auf dem Router:

```text
/etc/config/omega-led-monitor     # UCI-Konfiguration
/etc/init.d/omega-led-monitor     # procd-Init-Dienst
/usr/sbin/omega-led-monitor       # Laufzeitmonitor
/srv/backups/omega-led-monitor/   # zeitgestempelte Sicherungen
```

<p align="right">#readme-topNach oben</a></p>

---

## Technische Referenzen

- [Linux-Dokumentation zur Multicolor LED Class](https://www.kernel.org/doc/html/latest/leds/leds-class-multicolor.html)
- [OpenWrt-Dokumentation zu procd Init Scripts](https://openwrt.org/docs/guide-developer/procd-init-scripts)
- [OMEGA-LED-Monitor-Repository](https://github.com/hansekiter/Omega-LED-Monitor)
- [Installationsskript im Repository](https://github.com/hansekiter/Omega-LED-Monitor)

---

## Sicherheits- und Betriebshinweise

- Prüfe den Installer, bevor du ihn als Root ausführst.
- Behalte die zeitgestempelten Sicherungen, bis das neue LED-Verhalten vollständig geprüft ist.
- Gehe nicht davon aus, dass Interface- und Blockgerätenamen auf einem anderen Router identisch sind.
- Vermeide unnötige schreibintensive Tests auf dem internen eMMC-Speicher.
- Die LED-Farben zeigen einen visuellen Lasttrend und keinen exakten Bandbreiten- oder Speicherbenchmark.
- Die konfigurierten Maximalraten sind Darstellungsschwellen und keine automatisch erkannten Hardwaregrenzen.
- Direkte sysfs-Schreibzugriffe überschreiben absichtlich andere LED-Trigger, solange der Monitor aktiv ist.
- Der Installer muss als Root ausgeführt werden und verändert zentrale LED-Konfigurationsdateien.
- Eine Sicherung ersetzt nicht die Prüfung, ob der richtige Sicherungsstand wiederhergestellt wird.

---

## Mitwirken

Beiträge sind insbesondere willkommen für:

- konfigurierbare LAN-Interfacelisten
- bessere Validierung und Diagnose
- automatisiertes Shell-Linting
- Tests für Raten- und Farbberechnung
- sichereren Erhalt eigener Konfigurationswerte bei Upgrades
- Unterstützung weiterer Turris-Omnia-Konfigurationen
- Dokumentationsverbesserungen

Bei Änderungen:

1. Kompatibilität mit `/bin/sh` unter Turris OS erhalten.
2. Skripte mit `sh -n` prüfen.
3. Neue UCI-Optionen dokumentieren.
4. Keine nicht getestete Hardwareunterstützung behaupten.
5. Sicherungs- und Fail-safe-Verhalten des Installers erhalten.
6. Geänderte Interface- und Geräteannahmen ausdrücklich dokumentieren.

---

## Lizenz

Das Repository enthält derzeit keine Lizenzdatei. Bis eine Lizenz ergänzt wird, gelten die normalen urheberrechtlichen Regelungen. Rechte zur Weiterverwendung oder Weiterverteilung sind nicht ausdrücklich eingeräumt.

Für eine spätere Freigabe sollte eine `LICENSE`-Datei ergänzt und die gewählte Lizenz hier dokumentiert werden.

---

## Haftungsausschluss

OMEGA LED Monitor ist ein Router-Customizing-Projekt. Der Installer verändert Systemkonfigurationen und steuert Hardware-LEDs direkt über sysfs.

Die Software wird ohne Gewähr bereitgestellt. Prüfe das Skript, kontrolliere die erwartete Gerätebelegung und halte nutzbare Sicherungen vor, bevor du die Installation startest.

---

<div align="center">

**Gebaut für OMEGA, angetrieben vom Turris Omnia und einem sehr sichtbaren Lastverlauf.**

#readme-top

</div>
