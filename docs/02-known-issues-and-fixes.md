# 2 — Known issues and fixes

Tags: `[confirmed]` measured on a unit · `[reported]` community/reviews · `[theory]` plausible, unverified.

Ordered roughly by "worth doing first".

---

## Software / firmware — fixable without opening the device

### 2.1 Fast Startup causes stale state `[confirmed]`

**Symptoms:** internal USB hub / USB-A ports not enumerating after a "restart";
device won't wake; battery drains while "off"; `LastBootUpTime` stuck months in the
past.

**Cause:** Windows Fast Startup (hybrid shutdown) never does a real cold boot. The
Eve V's platform init for some devices only runs on a true power cycle. A machine
that hasn't had a cold boot in months accumulates this.

**Fix (admin PowerShell):**
```powershell
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0 -Type DWord
```
Then **shut down fully once** (Start > Shut down, wait 10 s, power on — or hold power
~20 s). `powercfg /a` should then say Fast Startup is disabled. Persists across
reboots; a Windows feature update can re-enable it.

---

### 2.2 Goodix fingerprint reader — driver crash loop `[confirmed]`

**Symptoms:** Device Manager shows `Goodix Fingerprint SPI Device` with a yellow
`!` (`CM_PROB_FAILED_START`). Event log: repeated `Microsoft-Windows-
DriverFrameworks-UserMode` 10110/10111 "user-mode driver crash" on every boot and
resume — this restarts the WUDF host and can briefly disturb other user-mode
drivers.

**Cause:** the 2017 Goodix driver (v1.0.20.600) does not start on current Windows
10; on many units the **sensor hardware itself is dead** (failing since ~2021 on
the reference unit). Two duplicate driver packages (`oem59.inf` + `oem61.inf`) can
also fight.

**Fix that stops the crashing (admin):**
```powershell
Disable-PnpDevice -InstanceId "ACPI\GXFP3200\<your-instance>" -Confirm:$false
```
Get `<your-instance>` from `Get-PnpDevice | ? FriendlyName -match Goodix`.

**To actually try to recover it:** remove the device + rescan, restart the
biometric service, then try a newer Goodix driver from a community mirror. Low
success rate if the sensor is physically dead (same `FAILED_START` returns).

---

### 2.3 NTFS corruption after an SSD I/O event `[confirmed on one unit]`

**Symptoms:** `chkdsk C: /scan` says "Windows has found problems that must be fixed
offline"; NTFS event 98 escalating from "online scan" to "run CHKDSK /F"; a burst
of `disk` event ID 7 ("bad block") in the System log.

**Context on the reference unit:** ~177 `disk` ID-7 errors in one 7-minute window
during a large write (app install), SSD temp ~60 C at idle. `chkdsk /scan` reported
**0 KB in bad sectors** — the SSD media was fine, but metadata got corrupted. The
Intel 600p is a mediocre drive that runs hot in this chassis and is prone to write
stalls.

**Fix:**
1. Back up first.
2. `chkdsk C: /f` → answer `Y` → reboot. It runs offline before Windows, ~5-20 min.
3. If ID-7 bursts recur: move the working OS/data to an **external USB-C NVMe**
   (see [05](05-upgrades-and-hardware.md)) rather than trusting the internal drive.

---

### 2.4 Intel Wireless-AC 8265 — old driver, drops, power-transition errors `[confirmed]`

**Symptoms:** Wi-Fi drops / slow reconnect; event log `Netwtw06` 6000 "BSS missed
beacons"; NDIS 10317 "Wi-Fi Direct Virtual Adapter ... failed a power transition";
`ZeroConfigService.exe` crashes in the Application log.

**Fix:**
1. Install the **latest Intel Wireless driver for the 8265** (22.x line; the 2021
   in-box driver is 20.70.x).
2. Device Manager > the 8265 > Power Management > uncheck "Allow the computer to
   turn off this device to save power".
3. Optional: in the adapter's advanced properties, disable "U-APSD support" /
   set "Roaming Aggressiveness" lower if roaming between APs.

---

### 2.5 Speakers sound thin / quiet `[reported + confirmed drivers old]`

**Cause:** Realtek codec driver from 2018 and **no smart-amp (TI) driver / APO**
installed. Eve shipped driver updates that improved this.

**Fix:** install the Eve V audio package (Realtek HDA + the TI amplifier driver)
from a community mirror. Without the amp component the speakers stay tinny.

---

### 2.6 Modern Standby (S0ix) drains the battery / gets warm in a bag `[confirmed]`

**Symptoms:** Kernel-Power events 506/507 many times per night; battery noticeably
lower after "sleep"; warm when taken out of a bag.

**Fixes (any/all):**
- Prefer **Hibernate** over Sleep. With Fast Startup already off:
  `powercfg /h on` (keep hibernate available), then set the power button and lid to
  Hibernate in Power Options.
- `powercfg /requests` and `powercfg /systemsleepdiagnostics` /
  `powercfg /sleepstudy` to find what's holding it awake (usually the Wi-Fi
  adapter's armed wake).
- `powercfg /devicequery wake_armed` → `powercfg /devicedisablewake "<name>"` for
  anything that shouldn't wake it.

---

### 2.7 Battery percentage is inaccurate `[confirmed]`

**Symptom:** `powercfg /batteryreport` shows Full Charge Capacity == Design
Capacity and no cycle count; sudden shutdowns at a non-zero %.

**Cause:** the EC reports placeholder battery static data on this platform; the fuel
gauge is poorly calibrated.

**Fix:** recalibrate — charge to 100%, use until it auto-shuts-off, repeat 2-3
times. Does not repair a genuinely worn cell, only the gauge.

---

## Hardware / design issues

### 2.8 USB-C ports sit slightly loose `[reported]`

**Symptom:** cable "clicks" in one port but not the other; contact lost during
charging or data transfer; charging only works at a certain cable angle.

**Cause:** the slanted chassis edges leave the Type-C ports a touch loose; Eve's own
remedy on later units was a charger with a **longer connector head** and slightly
tighter ports.

**Mitigation:** blow lint out of the port; use a cable with a longer/slimmer
connector barrel; don't leave a heavy cable hanging with side load; try the other
Type-C port.

---

### 2.9 Thermal throttling under sustained load `[confirmed]`

Fanless. Under a real sustained load the SoC hits ~100 C and clocks drop to
~2.1-2.2 GHz. Fine for web/office/drawing; not for sustained compute, sims, or
video export.

**Mitigation:** keep it elevated for airflow / add an external cooling pad; do
**not** raise PL1/PL2 in Intel XTU; a modest undervolt via XTU (if the BIOS allows
it) helps. Repasting is possible only via the full teardown and gains little on a
4.5 W passive design.

---

### 2.10 PWM backlight flicker at low brightness `[reported]`

PWM detected at **brightness <= 25%, ~985 Hz**. Can cause eye strain in the dark.

**Mitigation:** keep brightness above 25%; disable "Display Power Saving
Technology" (DPST/CABC) in the Intel Graphics Command Center; or a PWM-mitigation
utility.

---

### 2.11 Digitizer is less sensitive than a Surface `[reported]`

Pen only registers when very close to the glass (~6 mm) and palm rejection engages
late. On ELAN units, measured: 2048 pressure levels, **no tilt**. Firmware updates
existed that improved pen behaviour — worth chasing from a mirror if drawing is a
priority.

---

### 2.12 Detachable keyboard — ribbon cable snaps at the hinge `[confirmed as the common failure]`

The single most common Eve V keyboard failure. Full treatment in
[03-keyboard-and-pogo-pins.md](03-keyboard-and-pogo-pins.md).

---

### 2.13 Minor / cosmetic `[reported]`

- **Coil whine / faint electronic noise** during network data transfer — harmless.
- **Backlight bleed** on black in a dark room.
- **Slow pixel response** (~33 ms BtW) — ghosting in fast content.
- **Hinge:** at least one review unit had "a metal part slightly displaced" — check
  yours for play/creak.
- **Alcantara** keyboard surface is hard to clean between keys.

---

### 2.14 RTC / CMOS backup cell `[theory, watch for it]`

If BIOS settings or the clock reset after the tablet sits **unplugged and off for
days**, the internal RTC backup cell is flat. On Thunderbolt-capable machines this
can also revert Thunderbolt/USB-C behaviour. Replacement requires the teardown.
Test: fully power off + unplug for 2-3 days, then check the clock.
