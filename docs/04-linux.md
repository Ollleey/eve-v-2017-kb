# 4 — Linux on the Eve V (2017)

## Summary

The ArchWiki `Laptop/Other` table has a row for **Eve V (2017), i7 version**
(tested 2022-08):

| Video | Sound | Wi-Fi | Bluetooth | Power management | Camera | Notes |
|---|---|---|---|---|---|---|
| Yes | Yes | Yes | Yes | Yes | **No** | Accelerometer needs an extra module |

So under a modern distro almost everything works. The **cameras are the one real
gap**.

## What works well

- **Intel HD Graphics 615** (`i915`) — full acceleration, Vulkan, KMS.
- **Wi-Fi + Bluetooth** (Intel 8265, `iwlwifi`) — solid, and generally more reliable
  than the aging Windows driver.
- **NVMe SSD**, **eMMC**, **microSD reader**.
- **USB-A**, **USB-C data**, **Thunderbolt 3** (`bolt` / `thunderbolt`; same
  "enable in BIOS / set security level" caveat as Windows).
- **Touchscreen** (ELAN I2C-HID) and **pen** — basic pen works; pressure fine,
  tilt is not present in the hardware anyway.
- **Detachable keyboard** — generic USB HID, works without any special driver
  (does not fix a broken ribbon cable — that's hardware).
- **Suspend (s2idle)**, battery, brightness, keyboard backlight.

## Needs a workaround

- **Auto-rotation / ambient light** — Intel Sensor Hub via IIO. Usually works with
  `iio-sensor-proxy`; may need a specific `industrialio` / accelerometer module
  loaded. ArchWiki notes an extra module is required.
- **Speakers** — output works via `snd_hda_intel`, but the **TI smart amplifier**
  needs manual setup (SOF firmware / an ALSA UCM profile) or the speakers are very
  quiet. Headphone jack works out of the box.
- **Pen pressure curve** — may need per-app tuning.

## The real gap

- **Front + rear cameras** — Intel IPU3 + OmniVision OV2680 / OV5648. Historically
  very painful on Linux. `libcamera` + the IPU3 stack improved a lot from ~2023 but
  "just works" is not guaranteed. If you need the webcam, test this specifically
  before committing.
- **Fingerprint** (Goodix) — `libfprint` support for this exact sensor is spotty,
  and the sensor is often dead on these units anyway.

## Recommended approach

1. Distro with kernel **6.6+**: Fedora 40+, Ubuntu 24.04+, or Arch.
2. Boot a **live USB** first (USB-A works). Check in this order: Wi-Fi, audio
   (speakers + headphones), touch, pen, rotation, and **camera**.
3. Only if the camera result is acceptable to you: install — ideally onto an
   **external USB-C NVMe** so the internal drive and its Windows install stay
   untouched, and Win10 end-of-life stops mattering.

## Why Linux is a reasonable choice for this device now

- Windows 10 22H2 is past end-of-life (Oct 2025).
- Dead fingerprint + (often) dead keyboard mean you're not losing Windows-only
  features you were using.
- The FPV / maker / drawing toolchain (Betaflight Configurator, ExpressLRS, Blackbox
  Explorer, Krita) all have Linux builds, and USB-serial devices work without the
  Windows driver dance.
