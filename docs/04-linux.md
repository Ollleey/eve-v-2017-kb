# 4 — Linux on the Eve V (2017), in detail

Hardware here is from a real **i7-7Y75 / ELAN-digitizer** unit. Chip IDs are exact;
match them against `lspci -nn`, `lsusb`, and `ls /sys/bus/acpi/devices` on your unit.

## TL;DR verdict

**Daily-driver viable on a modern distro.** GPU, Wi-Fi, Bluetooth, storage, USB-A,
touchscreen, pen, sensors, audio output, suspend all work — most with zero config
on kernel 6.6+. Two real gaps:

1. **Cameras** — front + rear need manual work (Intel IPU3, same as Surface Pro 5).
2. **USB-C data / Thunderbolt** — on this unit the Alpine Ridge controller is **not
   on the PCI bus at all** (see [4.8](#48-usb-c--thunderbolt--the-alpine-ridge-problem)).
   That is a firmware/hardware issue Linux cannot fix, and it is the same on Windows.

Speaker volume needs a tweak. Auto-rotation needs a quirk. Everything else is fine.

---

## 4.1 Full hardware → Linux map

| Component | ID | Linux driver | Status | Action needed |
|---|---|---|---|---|
| iGPU HD 615 (KBL GT2) | `8086:591E` | `i915` | ✅ perfect | none |
| Wi-Fi Intel 8265 | `8086:24FD` | `iwlwifi` + `iwlmvm` | ✅ | `linux-firmware` (has `iwlwifi-8265-*`) |
| Bluetooth (on 8265) | USB `8087:0a2b` | `btusb` | ✅ | `linux-firmware` |
| NVMe SSD (Intel 600p) | `8086:F1A5` | `nvme` | ✅ | none |
| eMMC controller | `8086:9D2B` | `sdhci-pci` | ✅ | none |
| microSD reader | `8086:9D2D` | `sdhci-pci` | ✅ | none |
| USB 3.0 xHCI (PCH) | `8086:9D2F` | `xhci_pci` | ✅ (USB-A + pogo + BT) | none |
| Audio codec Realtek **ALC283** | HDA `10EC:0283` | `snd_hda_intel` + `snd-hda-codec-realtek` | ⚠️ works, speakers quiet | see [4.5](#45-audio) |
| HDMI/DP audio | `8086:280B` | `snd-hda-codec-hdmi` | ✅ | none |
| Digitizer **ELAN 04F3:200A** | ACPI `ELAN200A`, `PNP0C50` | `i2c-hid-acpi` + `hid-multitouch` | ✅ touch + pen | see [4.6](#46-pen--touchscreen) |
| I2C controllers (Serial IO) | `8086:9D60/61/62` | `i2c-designware-platform` (`intel-lpss`) | ✅ | none (mainlined) |
| SPI controller (Serial IO) | `8086:9D2A` | `spi-pxa2xx` / `intel-lpss` | ✅ | none |
| GPIO (Serial IO) | `INT344B` | `pinctrl-sunrisepoint` | ✅ | none (needed for touch IRQ) |
| Tablet buttons / mode switch | `INT33D6`, `INT33D3/D4` | `intel-hid`, `intel-vbtn` | ✅ vol/power keys, tablet-mode | none |
| Accelerometer **Kionix KXCJ9** | `KIOX000A` | `kxcjk-1013` | ⚠️ | rotation quirk, see [4.7](#47-sensors--auto-rotation) |
| Gyroscope **Bosch BMG160** | `BOSC1160` | `bmg160_i2c` | ✅ | none |
| Ambient light **Capella CM3218** | `CPLM3218` | `cm3232` (partial) | ⚠️ hit or miss | see [4.7](#47-sensors--auto-rotation) |
| TPM 2.0 | `MSFT0101` | `tpm_tis` / `tpm_crb` | ✅ | none |
| Thermal / DPTF | `8086:1903`, `INT3400/3403` | `int340x_thermal`, `processor_thermal_device` | ✅ (Linux governs it itself) | none |
| Fingerprint **Goodix GXFP3200** | SPI, `GXFP3200` | none (`libfprint` spotty) | ❌ | usually dead hardware anyway |
| Front cam **OV2680** | `OVTI2680` | `ov2680` | ❌ oob | see [4.4](#44-cameras--the-hard-part) |
| Rear cam **OV5648** | `OVTI5648` | `ov5648` | ❌ oob | see [4.4](#44-cameras--the-hard-part) |
| Camera PMIC / clocks | `INT3472` | `intel_skl_int3472` | needed for cams | kernel 5.16+ |
| Image processor **IPU3** | `8086:1919` + CIO2 `8086:9D32` | `ipu3-imgu` + `ipu3-cio2` + libcamera | ❌ oob | see [4.4](#44-cameras--the-hard-part) |
| Alpine Ridge TB3 / USB-C | (absent on this unit) | `thunderbolt`, `xhci` | ❌ | see [4.8](#48-usb-c--thunderbolt--the-alpine-ridge-problem) |
| Detachable keyboard (Novatek) | USB `0603:00F1` | `usbhid` / `hid-generic` | ✅ if hardware alive | see [4.9](#49-keyboard--pogo-pins) |

---

## 4.2 Works out of the box (kernel 6.6+)

GPU + Vulkan, brightness keys, Wi-Fi, Bluetooth, both USB-A ports, the microSD
reader, NVMe, the touchscreen (finger), the pen (pressure, hover), the gyroscope,
tablet-mode switch, volume/power buttons, TPM, suspend-to-idle (s2idle), battery
reporting, headphone jack.

Use a distro that ships a recent kernel and Mesa: **Fedora 40+**, **Ubuntu 24.04+**,
**Arch / EndeavourOS**, or **openSUSE Tumbleweed**. Avoid anything on kernel < 6.1.

---

## 4.3 Post-install package checklist

```bash
# firmware (usually already there)
#   Debian/Ubuntu: firmware-linux / linux-firmware
#   Fedora:        linux-firmware  (+ rpmfusion for some)
#   Arch:          linux-firmware

# sensors / auto-rotation
sudo apt install iio-sensor-proxy         # or dnf/pacman equivalent

# pen + tablet UX (Wayland GNOME/KDE handle most of this already)
sudo apt install libwacom-common xournalpp krita

# audio tooling (to fix speaker routing)
sudo apt install alsa-ucm-conf pipewire pipewire-pulse wireplumber
alsa-info.sh        # for reporting

# on-screen keyboard for tablet mode
#   GNOME: built in.  KDE: 'maliit-keyboard'.  Other: 'onboard' / 'squeekboard'

# cameras (only if you need them - see 4.4)
sudo apt install libcamera-tools libcamera-v4l2 v4l-utils
```

---

## 4.4 Cameras — the hard part

**Chips:** Intel **IPU3** image processor (`8086:1919`), CIO2 CSI-2 receiver
(`8086:9D32`), sensors **OV2680** (front, 2 MP) + **OV5648** (rear, 5 MP), power via
**INT3472** control logic. This is the **same camera subsystem as the Microsoft
Surface Pro 5 (2017)**, so the `linux-surface` project's camera work applies almost
directly.

**Why it's hard:** IPU3 cameras don't present a normal `/dev/video0` you can just
open. You need:
1. Kernel with `ipu3-cio2`, `ipu3-imgu`, `intel_skl_int3472`, `ov2680`, `ov5648`
   (all mainline now, but distros sometimes leave modules unbuilt).
2. The **IPU3 firmware** (`ipu3-fw.bin`) from `linux-firmware`.
3. **libcamera** with the IPU3 pipeline handler, plus a compat shim
   (`libcamerify` / `libcamera-v4l2` / the pipewire-libcamera bridge) so ordinary
   apps see a V4L2 device.
4. Correct ACPI sensor↔PMIC wiring — on some units the DSDT needs an override or a
   `int3472` GPIO mapping patch.

**Practical status (2024+):** doable, still fiddly, and app-dependent. Firefox and
GNOME Camera via pipewire-libcamera can work; many apps still can't. If the webcam
is important to you, **test this on the live USB before committing**, or plan to use
an external USB webcam.

Reference: [linux-surface IPU3 camera discussion #1352](https://github.com/linux-surface/linux-surface/discussions/1352).

---

## 4.5 Audio

- **Codec:** Realtek **ALC283** over legacy HDA (`snd_hda_intel`). The codec, the
  headphone jack, and the internal digital-mic array all come up.
- **Speakers are quiet / thin.** The Eve V drives its speakers harder than the bare
  codec default. Fixes, in order:
  1. Make sure **PipeWire + WirePlumber + `alsa-ucm-conf`** are installed and used
     (not bare ALSA). Modern UCM profiles fix routing on many 2017 tablets.
  2. `alsamixer` → F6 → the HDA card → unmute/raise **Speaker**, **Bass Speaker**,
     **Auto-Mute Mode = Disabled** if headphones steal the output.
  3. If still wrong, try an HDA model quirk:
     `options snd-hda-intel model=dell-headset-multi` (or `alc283-dac-wcaps`,
     `auto`) in `/etc/modprobe.d/alc283.conf`, then reboot. Collect
     `alsa-info.sh` output and check the linux-surface / ALSA bug trackers for the
     exact quirk others landed on.
- **Microphone array:** usually works via HDA DMIC; if silent, same model-quirk
  route. Test in `pavucontrol` / `wireplumber`.

---

## 4.6 Pen / touchscreen

- **Digitizer:** ELAN `ELAN200A` (`ACPI\VEN_04F3&DEV_200A`), compatible ID
  `PNP0C50` = **HID-over-I2C**. Linux binds `i2c-hid-acpi`; the touchscreen and pen
  enumerate as generic HID digitizers. No vendor driver needed.
- **Measured capability (from Windows HID descriptor):** **2048 pressure levels, NO
  tilt**, reports pen battery. So under Linux you get position + 2048-step pressure
  + hover + one or two barrel buttons. Tilt is simply not in the hardware.
- **Pen apps:** Krita, Xournal++, GIMP, Inkscape all read pressure through
  libinput / the Wayland tablet protocol (or XInput2 on X11). Genuinely usable for
  notes and casual drawing.
- **Likely tweaks:**
  - **Orientation / calibration:** if touch/pen is rotated or offset, add a
    `libinput` calibration matrix via a udev `hwdb` entry
    (`/etc/udev/hwdb.d/61-evev-pen.hwdb`) or `xinput set-prop` on X11. GNOME's
    Wacom settings panel can calibrate on Wayland.
  - **Palm rejection:** works on GNOME/KDE via libinput; on minimal WMs you may
    need to disable touch while the pen is in proximity yourself.
  - If the pen is seen as a mouse instead of a tablet tool, add the device to
    `libwacom` (a small local `.tablet` file) so apps treat it as a stylus.
- **MPP pen choice** is unchanged from Windows: this is an MPP digitizer, buy an
  MPP pen (Surface Pen 1776, Metapen M1). See [01](01-identify-your-unit.md).

---

## 4.7 Sensors / auto-rotation

- Drivers: `kxcjk-1013` (Kionix KXCJ9 accel), `bmg160_i2c` (Bosch gyro),
  `cm3232` (Capella CM3218 ALS — **partial**; the CM3218 needs an ACPI/i2c quirk on
  some units and may not bind).
- Install **`iio-sensor-proxy`**; GNOME/KDE then auto-rotate.
- **Rotation is often 90°/180° off** because the accelerometer mount matrix isn't
  known for this board. Fix with a udev/hwdb entry:
  ```
  # /etc/udev/hwdb.d/61-sensor-evev.hwdb
  sensor:modalias:acpi:KIOX000A*:dmi:*svnEVE:pnEveV:*
   ACCEL_MOUNT_MATRIX=0, 1, 0; -1, 0, 0; 0, 0, 1
  ```
  then `sudo systemd-hwdb update && sudo udevadm trigger`. Try the four rotations of
  the matrix until it tracks.
- ALS-based auto-brightness may not work if `cm3232` doesn't bind — not critical.

---

## 4.8 USB-C / Thunderbolt — the Alpine Ridge problem

On this unit the **Intel Alpine Ridge (JHL6240) Thunderbolt 3 controller is absent
from the PCI bus** — PCIe root port #1 has no child device, and there is only one
xHCI controller. Both USB-C ports and Thunderbolt route through that chip.

Consequences, **identical on Windows and Linux**:
- USB-C **data** (both ports): dead
- **Thunderbolt** devices / eGPU / TB docks: dead
- USB-C **DisplayPort-out**: dead
- USB-C **charging (PD)**: still works — handled by a separate PD controller

**Before blaming Linux for "USB-C doesn't work", fix this on the firmware side:**
enter UEFI setup (Volume-Down at power-on, or Esc repeatedly), `Advanced →
Thunderbolt Configuration`, make sure Thunderbolt support is **Enabled** and the
security level is "No Security" / "User Authorization". Save, full power cycle. If
the controller comes back it will work on both OSes; `thunderbolt` + `bolt` handle
it on Linux. If it stays absent after a confirmed-enabled BIOS setting and a cold
boot, the Alpine Ridge chip is likely dead — a mainboard fault, not an OS issue.

---

## 4.9 Keyboard / pogo pins

- The detachable keyboard is a **generic USB HID composite device** (`0603:00F1`).
  On Linux it needs **zero configuration** — `usbhid` / `hid-generic` bind it, keys
  + touchpad work. Precision-touchpad gestures are more limited than on Windows but
  two-finger scroll / tap work via libinput.
- Linux does **not** fix a dead keyboard. If the ribbon cable at the hinge is
  broken (the common Eve V failure), it's dead on every OS. Repair options:
  [03](03-keyboard-and-pogo-pins.md) and [07](07-diy-keyboard-replacement.md).
- The **pogo-pin path itself** is just USB 2.0 on the PCH xHCI. Linux enumerates
  whatever is electrically present — so a Pico-based DIY replacement keyboard
  ([07 Tier 4](07-diy-keyboard-replacement.md#tier-4--wired-diy-keyboard-on-the-pogo-pins))
  works on Linux exactly as on Windows. No driver question, only a hardware one.
- Keyboard **backlight** and the Fn media keys are handled by the keyboard's own
  MCU (HID), so they keep working on Linux.

---

## 4.10 Suspend / battery / thermals

- **s2idle** (modern standby) is the only sleep state — same as Windows. It works,
  but idle-in-sleep power draw is mediocre (a platform limitation, not a Linux
  one). For long unplugged storage, use **hibernate** (`systemctl hibernate`, needs
  a swap area >= RAM or a swapfile with a resume offset).
- Battery reports fine via `PNP0C0A` / `upower`. The gauge inaccuracy from
  [issue 2.7](02-known-issues-and-fixes.md#27-battery-percentage-is-inaccurate) is
  in the EC, so it carries over.
- Fanless throttling is governed by Linux's own thermal code (`int340x_thermal` +
  the intel RAPL constraints), not the Windows DPTF tables. Real-world sustained
  performance is similar. `thermald` helps; an undervolt via
  `intel-undervolt` (config in `/etc/intel-undervolt.conf`) works on the 7Y75
  (pre-Plundervolt) and buys back some sustained clock — same idea as
  [8.8](08-community-findings.md#88-undervolting).

---

## 4.11 Test plan (live USB, before installing)

1. Boot the live image (USB-A works).
2. Check, in order: **Wi-Fi → Bluetooth → speaker + headphone audio →
   touchscreen → pen pressure (open Krita) → screen rotation → suspend/resume →
   the microSD reader**.
3. Then the two question marks for your use: **cameras** and, if you need it,
   **USB-C data** (plug a USB-C stick — expect nothing until the Alpine Ridge issue
   in [4.8](#48-usb-c--thunderbolt--the-alpine-ridge-problem) is resolved).
4. If audio is quiet, that's expected — [4.5](#45-audio) fixes it post-install; it's
   not a reason to abandon the install.

Only commit once the must-haves pass. Install onto an **external USB-C NVMe** if you
want to keep the Windows install intact — but note USB-C data being dead means you'd
be booting from a USB-**A** enclosure instead.
