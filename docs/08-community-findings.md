# 8 — Community findings (from the old Eve forum + r/evev)

Fixes and information the Eve V community worked out, mostly on the now-dead
`eve.community` / `community.eve.tech` forum. Links go to the Internet Archive.

> The original forum is gone (HTTP 410). Every link below is a
> `web.archive.org` snapshot. If a snapshot 404s, try a different year:
> `https://web.archive.org/web/2020/<original-url>`.
>
> ⚠️ These are **forum posts from 2018-2022**, some from Eve staff, many from
> users. Advice may be outdated, wrong, or for a different batch. **Firmware
> flashing here can brick your device** (see 8.1). Treat as leads to verify, not
> instructions. See [00-read-first](00-read-first.md).

---

## 8.1 The V has FIVE separately-updatable firmware components

Source: [FAQ - How to install firmware updates on the V](https://web.archive.org/web/2021/https://eve.community/t/faq-how-to-install-firmware-updates-on-the-v/16917)

The AMI SMBIOS string (`5.12`) is **not** the whole story. Eve shipped separate
firmware packages, each with its own version and `instructions.pdf`:

| Component | What the update does | Update when |
|---|---|---|
| **BIOS** | Spectre/Meltdown mitigation (min version `0.41`), boot fixes | recommended for everyone |
| **Battery EC** | faster internal-battery charging | optional |
| **Thunderbolt 3 (NVM)** | external TB3 device compatibility | only if a TB3 device misbehaves |
| **Keyboard & Touchpad** | touchpad sensitivity tweaks (reversible - try an older version if a new one feels worse) | only if the keyboard/touchpad misbehaves |
| **Touch Panel** | touchscreen sensitivity / ghost-touch tweaks (also reversible) | only if the touchscreen misbehaves |

**Cautions from the FAQ:**
- Temporarily disable Windows Defender / security software before a BIOS update.
- Have your **BitLocker recovery key** ready — firmware changes can look like "new
  hardware" and trigger a BitLocker prompt.
- Full battery **and** on AC power.
- An interrupted firmware write can brick the component — reinstalling Windows will
  not fix it.
- "Install only if you have a problem with that component."

### :warning: Do NOT blindly flash "firmware 1.04" / "1.06"

Multiple reports of a **bricked display** (red stripes -> permanent black screen)
after updating to "firmware 1.04":
[[1]](https://web.archive.org/web/2021/https://eve.community/t/after-updating-firmware-to-104-monitor-worked-for-5x-mins-followed-by-red-stripes-and-now-a-permanent-black-screen-can-no-longer-use/32903)
[[2]](https://web.archive.org/web/2021/https://eve.community/t/blank-screen-and-not-handshaking-with-graphics-card-even-at-post-firmware-updated-to-104-no-change-in-behaviour/31870)
Firmware 1.06 had "can't detect device" problems
[[3]](https://web.archive.org/web/2022/https://eve.community/t/cant-get-firmware-106-update-program-to-detect-device/34882).
Only flash a component you have a concrete problem with, from a source you trust.

---

## 8.2 Random wake from sleep (accidental keyboard input)

Source: [Beta BIOS to avoid the device waking up by accidental keyboard/mouse input](https://web.archive.org/web/2020/https://eve.community/t/beta-bios-to-avoid-the-device-waking-up-by-accidental-keyboard-mouse-input/17804)

Eve investigated "the V randomly wakes during sleep" and concluded it is mostly the
**keyboard cover, folded over the screen, still registering keypresses** and waking
the tablet.

Three fixes, safest first:

1. **Software (recommended, no BIOS risk)** - Device Manager -> the **HID touch
   panel** and the **keyboard** device -> Power Management tab -> uncheck
   "Allow this device to wake the computer". (Forum user "Kantholz" confirmed this
   works.) Do the same via:
   ```powershell
   powercfg /devicequery wake_armed
   powercfg /devicedisablewake "<exact device name from the list>"
   ```
2. **Task Scheduler trick** (forum user "anon9328532") - two tasks: on workstation
   **lock** (power button / Win+L), disable the touchscreen and trackpad; on
   **unlock**, re-enable them. Stops the closed-cover hand from triggering the
   touchpad/touchscreen and closing your windows / losing work. Unlock with the
   fingerprint reader.
3. **Beta BIOS** - disables **all** USB devices (keyboard, mouse) from waking the V;
   lifting the keyboard off the tablet still wakes it. Roll back with BIOS `0.41`.
   Side effect: the boot logo changes to a third-party one.

Related: removing/inserting the USB-C charger can also wake the V.

Also see [issue 2.6](02-known-issues-and-fixes.md#26-modern-standby-s0ix-drains-the-battery--gets-warm-in-a-bag)
and the lid-close action fix in [issue 2.x / power].

---

## 8.3 Touchscreen + pen dead after a Windows 10 -> 11 upgrade or reinstall

Sources: [Eve V (2021) Driver Downloads](https://web.archive.org/web/2023/https://eve.community/t/eve-v-2021-driver-downloads/35628)
(Wacom-batch units), confirmed by Eve staff.

Symptom: pen and touch stop working; System Information says
"No pen or touch input is available for this display".

**Fix (Eve-staff-confirmed temporary solution):**
1. Device Manager -> Human Interface Devices
2. Find the **Wacom** device - its status shows "failed to start"
3. Right-click -> **Uninstall device**
4. Action -> **Scan for hardware changes**
5. Windows reinstalls a generic **HID-compliant pen** + **HID-compliant touch
   screen** (Microsoft driver) - and it works.

This is the same pattern that works for the fingerprint reader and for ELAN-batch
digitizers: remove the broken OEM driver, let Windows bind the in-box HID driver.

---

## 8.4 Ghost touches

Recurring complaint (windows closing on their own, the V "rebooting", work lost),
often worse right after reopening the folded cover. Contributors:

- The lid-close magnet is weak; a thin protective cloth adds a gap so Windows
  thinks the lid is open, and the holding hand triggers the touchscreen/touchpad.
- Try a **Touch Panel firmware** update (or an older version) - see 8.1.
- The 8.3 uninstall-Wacom / generic-HID fix helps some cases.
- Disable the touchscreen while the session is locked (8.2 method 2).

---

## 8.5 Keyboard: duplicate or dropped characters

Reported alongside the wake bug - the keyboard emits **redundant characters** or
**drops characters**, most often right after a **Bluetooth (re)connect**. A
Keyboard/Touchpad firmware update is the intended fix (8.1); otherwise re-pair the
Bluetooth connection, or use it wired.

Also: [USB keyboard keystrokes hang when connected via a USB hub + TB3 dock](https://web.archive.org/web/2021/https://eve.community/t/b-usb-keyboard-keystrokes-are-hanging-when-connected-via-usb-hub-and-tb3-dock/12254)
- avoid chaining the keyboard through a hub behind the dock.

---

## 8.6 EFI Shell on boot / "cannot find required map name" / SSD not seen at POST

Source: [FAQ - built-in EFI Shell on power-on](https://web.archive.org/web/2021/https://eve.community/t/faq-when-power-on-device-i-see-built-in-efi-shell-interface-what-should-i-do-to-fix-it/13245)

The boot entry got changed to the built-in EFI Shell.

1. Reboot: type `exit` + Enter in the shell, or long-press power.
2. At the "made by us" logo, press **Esc** repeatedly to enter BIOS/UEFI setup.
3. Either:
   - **Fn+F3** = load setup defaults, then **Fn+F4** = save & exit, **or**
   - **Boot Options** -> set **Boot Option #1** = "Hard Disk: Windows Boot Manager"
     -> save & exit.

Useful Eve V BIOS keys: **Esc** (repeatedly at logo) to enter setup, **Fn+F3**
load defaults, **Fn+F4** save & exit. (Volume-Down at power-on also enters setup.)

---

## 8.7 Calibration backup / restore tool (before a Windows reinstall)

[github.com/Iamscottm8/Eve-V-Calibration-Backup](https://github.com/Iamscottm8/Eve-V-Calibration-Backup)
- community tool that backs up, restores, and "fixes" the V's calibration DB
(digitizer/pen calibration data that is otherwise lost on a clean Windows install).
Back up **before** you wipe Windows; restore + "Fix DB" after. Source-only - build
it yourself.

Related: [Eve V calibration backup/restore/fix DB thread](https://web.archive.org/web/2021/https://eve.community/t/eve-v-calibration-backup-restore-fix-db-tool/15406).

---

## 8.8 Undervolting

Community thread: [Undervolting in BIOS/UEFI](https://web.archive.org/web/2021/https://eve.community/t/f-undervolting-in-bios-uefi/12635).

The i7-7Y75 (Kaby Lake, pre-Plundervolt) still exposes the FIVR, so **Intel XTU**
or **ThrottleStop** undervolting works - but on modern Windows you must first turn
off **Core Isolation / Memory Integrity** (and VBS) or XTU refuses to apply
voltage offsets. A modest core/cache offset (start around -50 mV, test for
stability) lowers temps and reduces the throttling in
[issue 2.9](02-known-issues-and-fixes.md#29-thermal-throttling-under-sustained-load-confirmed).
Do **not** raise the power limits.

---

## 8.9 Driver sources the community used

- **r/evev** - safest community route; members mirror the original Eve download
  bundle.
- **X-Station** (`x-station.cn`) - a Chinese community that also sold the "V2" and
  hosts a full V2 driver set **and** a BIOS. Forum consensus: "the machines are
  identical" but Eve staff **explicitly warned against** installing drivers/BIOS
  from third-party sites (brick risk, possibly-wrong device). Treat as last resort,
  drivers only, never the BIOS.
- [Eve driver threads](https://web.archive.org/web/2021/https://eve.community/t/drivers-for-fresh-windows-reload/14422),
  [FAQ - installing driver updates](https://web.archive.org/web/2021/https://eve.community/t/faq-how-to-install-driver-updates-on-the-v/16916).

---

## 8.10 Other archived threads worth a look

| Topic | Archived thread |
|---|---|
| Community startup guide (7 pages of tips) | [community-designed-startup-guide](https://web.archive.org/web/2021/https://eve.community/t/community-designed-startup-guide-useful-tips-thinking/4607) |
| A quick guide to the V, by Eve | [a-quick-guide-to-the-v-by-eve](https://web.archive.org/web/2021/https://eve.community/t/a-quick-guide-to-the-v-by-eve/5840) |
| Additional V keyboard instructions (FAQ) | [faq-additional-v-keyboard-instructions](https://web.archive.org/web/2021/https://eve.community/t/faq-additional-v-keyboard-instructions/11736) |
| Fn-lock affecting arrow keys / "oops" key - fix | [closed-fix-fn-lock-affecting-arrow-keys](https://web.archive.org/web/2020/https://eve.community/t/closed-fix-fn-lock-affecting-arrow-keys-and-oops-key/12078) |
| Battery health / durability utility | [f-battery-health-durability-utility](https://web.archive.org/web/2021/https://eve.community/t/f-battery-health-durability-utility/13835) |
| Keyboard indicator LED lit when awake in BT mode | [f-have-keyboard-indicator-led-lit-when-awake-in-bt-mode](https://web.archive.org/web/2021/https://eve.community/t/f-have-keyboard-indicator-led-lit-when-awake-in-bt-mode/12596) |
| External microphones not detected by the drivers | [b-external-microphones-will-not-detected-by-the-drivers](https://web.archive.org/web/2021/https://eve.community/t/b-external-microphones-will-not-detected-by-the-drivers/13088) |
| Eve V dead keyboard - repair / parts / components | [eve-v-dead-keyboard...components](https://web.archive.org/web/2022/https://eve.community/t/eve-v-dead-keyboard-can-i-send-for-repair-order-parts-or-know-the-components/34678) |
| 4G LTE module in the detachable keyboard | [4g-lte-for-eve-v-in-detachable-keyboard](https://web.archive.org/web/2019/https://eve.community/t/4g-lte-for-eve-v-in-detachable-keyboard/5589) |

### Mining the archive yourself

The full list of archived forum threads:
```
https://web.archive.org/cdx/search/cdx?url=eve.community/t/*&output=text&fl=original&collapse=urlkey&limit=5000
```
Open any result as `https://web.archive.org/web/2021/<original-url>`.
