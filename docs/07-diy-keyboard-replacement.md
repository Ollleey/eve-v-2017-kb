# 7 — DIY keyboard replacement

> ⚠️ **Read [00-read-first](00-read-first.md) first.** This chapter is
> speculative — **nobody has published a working Eve V pogo pinout or a finished
> DIY keyboard.** The wiring, the detect-pin behaviour, and "the pogo VBUS is safe
> to power an MCU from" are **assumptions**, not tested facts. Get the pinout wrong
> and you can back-feed voltage into the tablet's USB PHY. Verify every connection
> with a multimeter against your own donor keyboard first. LiPo safety applies.
> Your risk.

For a dead detachable keyboard. Tiered by effort — do the cheap tests first.

## Decision tree

```
Keyboard dead
  |
  ├─ PogoWatch / multimeter: does ANYTHING happen on attach?
  │     ├─ WMI event but no enumeration  -> flex or Novatek chip  -> Tier 1
  │     └─ nothing at all                -> could be tablet-side  -> do Tier 0 first
  │
  ├─ Tier 0  Pico-as-pogo-tester   (EUR 4, no teardown)
  │     -> proves whether the pogo pins carry usable power + data
  │
  ├─ Tier 1  Repair the original    (best result if flex is the fault)
  ├─ Tier 2  Bluetooth keyboard + folio   (no electronics work)
  ├─ Tier 3  Bluetooth DIY keyboard in a printed folio
  └─ Tier 4  Wired DIY keyboard on the pogo pins  (needs pinout)
```

## Tier 0 — Pico as a pogo-pin tester

A native-USB microcontroller flashed as a USB HID keyboard that types a test string
on a timer.

- **Board:** Raspberry Pi Pico / Pico 2 (RP2040/RP2350) is ideal — native USB
  device, runs from 5 V on VSYS, KMK/QMK/CircuitPython. ESP32-**S2/S3** or an
  ATmega32u4 (Pro Micro) also work. Plain ESP32 does **not** (no USB device HW).
- **Procedure:**
  1. Flash it, test on a **USB-A port** — confirms firmware + wiring.
  2. Move VBUS / D+ / D- / GND to the tablet's pogo pads.
  3. Text appears -> pogo path is alive -> the original keyboard is the fault, and a
     Pico replacement will work. Nothing -> pogo path dead (tablet-side) -> stop,
     use USB-A or Bluetooth.

## Tier 1 — repair the original keyboard

iFixit guide 126817 to open it. Then:

- **Flex broken at the hinge (the common case):**
  - Bridge the broken traces with 0.1 mm enamelled wire, **or**
  - Solder a 4-wire USB cable (5V / D- / D+ / GND) from the keyboard PCB pads to a
    USB-A plug — bypasses the hinge, keyboard becomes a normal wired USB keyboard.
    You keep the original keys, layout, trackpad and the screen-protecting cover.
- **Battery flat but not swollen:** feed 5 V to VBUS/GND on the PCB (after the flex
  break) for ~30 min, retest. Replace the cell if needed (1S LiPo + PCM, match the
  cell's printed model number / cavity size, ~EUR 5).
- **Novatek chip / PCB visibly damaged:** original electronics are scrap -> Tier 2/3.

## Tier 2 — Bluetooth keyboard + protection

The Eve V's pogo connector is proprietary; **no third-party cover-keyboard fits**,
and a **Surface Type Cover does not work** (different connector + protocol, ~4 mm
size mismatch — it magnetically clings but never enumerates).

- A used **original Eve V keyboard** is the only thing that docks like the cover.
- Otherwise: any compact Bluetooth keyboard (Logitech K380 / MX Keys Mini, etc.) +
  the tablet's built-in kickstand, and a separate folio or sleeve + screen
  protector for protection. Surface Pro 4-7 screen protectors and folio cases fit
  the Eve V closely (same 12.3" panel, ~4 mm larger body).

## Tier 3 — Bluetooth DIY keyboard in a printed folio

Essentially a custom keyboard build + a 3D-printed folio with magnets.

| Part | Choice | ~Price |
|---|---|---|
| Controller | nice!nano / Seeed XIAO nRF52840, firmware **ZMK** (BT HID) | EUR 25 |
| Switches | Kailh Choc low-profile + keycaps | EUR 20-30 |
| PCB | custom (KiCad) or hand-wired | EUR 0-15 |
| Battery | 1S LiPo 300-500 mAh + TP4056 charger | EUR 5 |
| Magnets | neodymium, matched to the tablet's edge magnets (mind polarity) | EUR 5 |
| Enclosure | 3D print: key tray + magnet strip + screen-cover flap | filament |

No pogo work needed — connects over Bluetooth. Fold-up cover + magnetic attach is
pure mechanical design.

## Tier 4 — wired DIY keyboard on the pogo pins

Only worth it if the pogo pins are confirmed alive (Tier 0) **and** you want the
no-pairing, no-charging convenience of a wired dock.

- **Reverse-engineer the pinout** from the dead keyboard — see
  [03-keyboard-and-pogo-pins.md](03-keyboard-and-pogo-pins.md#the-pogo-pinout--not-publicly-known).
- **Keyboard side:** a USB HID keyboard (Pico + KMK/QMK, or a gutted slim
  keyboard). Present standard USB 2.0.
- **Connector:** spring pogo pins on a small bracket, aligned to the tablet pads,
  held by magnets. **Best source: desolder the pogo block from the dead keyboard**
  — guaranteed mechanical match. (On the Eve V the *keyboard* has the spring pins,
  the *tablet* has flat pads.)
- **Power:** if pogo VBUS is live, run the MCU straight off it — no battery, no
  charging. Budget is fine (USB 2.0 ~500 mA vs an MCU + backlight < 200 mA).
- **Detect pin:** replicate whatever the original keyboard did (from the RE step).
  Fallback if you can't: power the MCU separately and use only D+/D-/GND through the
  pogo pins — works if the tablet's USB host on that port stays active without the
  detect signal (usually only VBUS is gated).
- **Signal integrity:** HID keyboards run at USB Full-Speed (12 Mbit/s) — very
  forgiving. Keep D+/D- short; no other special routing needed.

Integrates naturally with the DIY snap-fit case + kickstand from
[05](05-upgrades-and-hardware.md).
