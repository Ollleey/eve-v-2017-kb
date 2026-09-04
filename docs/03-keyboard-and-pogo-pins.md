# 3 — Keyboard and pogo pins

> ⚠️ **Read [00-read-first](00-read-first.md) before opening anything.** This is
> community guesswork from one unit, not an official manual. Pin counts, the pinout,
> and the failure mode described here are **not verified** — measure your own
> hardware. The keyboard has a LiPo cell: a swollen one must not be charged,
> pressed, or punctured. iFixit disassembly guide:
> <https://www.ifixit.com/Guide/EVE+V+Keyboard+Disassembly/126817>. You do this at
> your own risk.

## How the keyboard connects

The Eve V detachable keyboard is a **standard USB HID composite device**
(keyboard + touchpad + consumer controls) built around a **Novatek** controller:

```
USB\VID_0603&PID_00F1
```

- **Transport:** plain **USB 2.0** over the pogo pins (5V / D+ / D- / GND, plus a
  detect line and possibly a charge line — exact count/pinout not publicly
  documented; see below).
- **On the tablet side it connects directly to the Intel PCH xHCI root hub.**
  There is **no internal USB hub**. (A `VID_05E3` Genesys Logic hub showing up is an
  *external* hub someone plugged into a USB-A port — its presence/absence is
  irrelevant to the keyboard.) The keyboard's last-known location path is
  `PCIROOT(0)#PCI(1400)#USBROOT(0)#USB(2)` — root-hub port 2 on the PCH controller.
- Windows binds generic `HidUsb` / `kbdhid` / `mouhid` — **no Eve-specific driver**.
- The keyboard also has its own **battery + Bluetooth 4.2** (multi-device, up to 3).
  Bluetooth does **not** go through the pogo ribbon cable.

## The common failure: ribbon cable at the hinge

iFixit's own note: *"The ribbon cable is probably the biggest flaw of the keyboard
because it easily breaks when flipping the cover."* The flex fatigues and fractures
at the fold between the pogo-pin block and the main keyboard PCB.

## Diagnose WITHOUT opening anything

### Step 1 — is the keyboard seen at all?

Use `tools/PogoWatch/` (this repo) or watch Device Manager while attaching the
keyboard. Interpretation:

| What you observe on attach | Meaning |
|---|---|
| A `Win32_DeviceChangeEvent` (device arrival) fires but **no USB device** appears | The port sees the pins electrically (D+ pull-up / VBUS) but the keyboard fails to enumerate → **flex cable or Novatek controller**, not the port. |
| **Nothing at all** — no device-change event, no device | Dead connection: pins not making contact, or the ribbon is fully open, or no power reaches the keyboard. |
| The device appears cleanly, then works | Not a hardware fault — check drivers / try `pnputil /scan-devices`. |

`Win32_DeviceChangeEvent` fires at the physical layer, *before* any driver binds, so
"zero events on attach" = the USB host silicon never detected a device. That rules
out software/driver/hub/port-disabled causes.

### Step 2 — rule out the tablet-side USB path

```powershell
# controller + root hub healthy?
Get-PnpDevice | ? FriendlyName -match 'xHCI|USB Root Hub' | Select Status,Problem,FriendlyName
# any disabled USB ports?
Get-PnpDevice -Class USB | ? Status -ne OK
# over-current / power-limit events, ever?
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-USB-USBHUB3'} |
  ? { $_.Id -in 34,35 -or $_.Message -match 'over.?current|power limit|exceeded' }
```

If the controller/root hub are OK, no ports are disabled, other devices enumerate on
the USB-A ports, and there are no historical over-current events, the tablet-side
USB stack is healthy and the fault is at the connector / keyboard.

### Step 3 — multimeter on the tablet's pogo pads (no teardown)

Keyboard detached.

| Mode | Measure | Expected |
|---|---|---|
| Continuity, tablet **off** | each pad -> chassis / USB-A shell / headphone sleeve | 1-2 pads beep = **GND** |
| Resistance, off | every pad pair | nothing near 0 ohm except GND-GND. A hard short between two other pads = a blown protection part (e.g. from a past short) |
| Resistance, off | suspected D+ or D- -> GND | a few kOhm (host pull-down) — not 0, not open |
| DC volts, tablet **on** | GND -> each other pad | one pad ~5 V = **VBUS present**, tablet-side power OK. **No pad at 5 V** = either VBUS is gated by the detect pin, or the load switch / trace is dead |

Caveat: many designs only power the pogo VBUS **when a keyboard is detected**. A
reading of 0 V with no keyboard attached is not automatically a fault.

### Step 4 — the definitive split (still no teardown of the tablet)

Wire a **Raspberry Pi Pico** (or any native-USB MCU) flashed as a USB HID keyboard
that types a string every few seconds:

1. Test it on a **USB-A port** first — confirms your firmware/wiring.
2. Then wire its VBUS / D+ / D- / GND to the tablet's pogo pads.
   - Text appears → the pogo data path **and** power are alive → the fault is your
     original keyboard, and a Pico-based replacement will work.
   - Nothing → the pogo path is dead (tablet-side) → use USB-A or Bluetooth instead.

A EUR 4 Pico answers "keyboard or tablet?" without opening the tablet.

## If you do open the keyboard (iFixit guide 126817)

Tools: opening picks, spudger, hair dryer / heat gun (low), tweezers. The connector
block's top is plastic, bottom aluminium, pinned + glued. Heat to release, peel the
Alcantara over the cable, push back a small black clamp, pull the cable.

Then:

- **Continuity-test each pogo pad -> its landing point on the keyboard PCB**, across
  the hinge. Any of VBUS / D+ / D- / GND / detect open = the flex is the fault.
  - Fix A: bridge the broken traces with 0.1 mm enamelled wire.
  - Fix B (higher success): solder a 4-wire USB cable (VBUS/D-/D+/GND) from the PCB
    pads to a USB-A plug, bypassing the hinge entirely. Keyboard runs as a normal
    USB keyboard.
- **Check the battery** (see below).
- **Check the Novatek controller / PCB** for visible damage, corrosion, burnt pads.

## Bluetooth — and the charging chicken-and-egg

Pairing: detach the keyboard, press **Fn + the Bluetooth key** together to wake it,
hold the Bluetooth key while the tablet scans for Bluetooth devices.

But: the keyboard battery **charges only through the pogo pins**. If the ribbon is
broken, the battery cannot charge, so a dead battery makes Bluetooth look dead even
if the electronics are fine. To test the electronics you have to open it, find
VBUS/GND on the PCB **after** the break, feed 5 V there for ~30 min, then try
Bluetooth.

## The battery

- **1S LiPo** (3.7 V nominal, 4.2 V full), small flat pouch cell.
- Exact capacity is **not publicly documented**. Class estimate: 300-600 mAh.
- When open: read the **cell's own label** — it usually has a model number like
  `LP402030` (= 4.0 x 20 x 30 mm) which is the spec; buy an exact match by that
  number. Or measure the cavity and fit any 1S pouch **with a protection circuit
  (PCM)** of similar capacity.
- Swollen / puffed cell → **do not charge**, dispose safely.

## The pogo pinout — NOT publicly known

As of writing, **nobody has published a reverse-engineered pinout** for the Eve V
keyboard connector (checked: Google, r/evev, GitHub, Hackaday, the dead Eve forum).
A 2021 r/evev thread asking exactly this got 2 comments and no answer.

**How to derive it from the dead keyboard:**

1. Count pins, photograph both sides. Typical 5-7 pin tablet layouts:
   `GND | VBUS | D- | D+ | DET | (GND) | (CHG)`. GND often duplicated on the ends,
   D+/D- always adjacent.
2. Find the Novatek chip; read its part number → datasheet → its USB pins.
3. Continuity-trace each pad:
   - large ground pour / many vias / chip GND pins → **GND**
   - LDO/regulator input, bulk cap + → **VBUS**
   - chip USB pins, usually via 22-33 ohm series resistors or ESD diodes near the
     connector, tightly-routed pair → **D+ / D-**
   - pull-up/pull-down resistor or a lone GPIO → **detect / ID**
   - separate path to a charge IC (TP4056-class) → **battery charge**
4. D+ vs D-: D+ carries the 1.5 kOhm pull-up to 3.3 V for full-speed → sits higher
   at idle. Or from the datasheet. Or just swap them at bring-up if it doesn't
   enumerate.
5. Detect behaviour: measure it on the tablet side (voltage, tablet on) and on the
   keyboard side (what it connects to); replicate on any DIY keyboard.

**If you work this out, please open a PR.** It would be the first public record.
