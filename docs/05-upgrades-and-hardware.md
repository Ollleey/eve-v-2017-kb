# 5 — Upgrades and hardware

## What can and cannot be changed

| Part | Upgradeable? | Detail |
|---|---|---|
| **RAM** | ❌ No | Soldered LPDDR3. m3/i5 = 8 GB, i7 = 16 GB. That's the ceiling. |
| **SSD** | ⚠️ Yes, but hard | One **M.2 2280 PCIe NVMe** slot (Key M). PCIe **3.0**. Reachable only via full teardown. |
| **Wi-Fi card** | ⚠️ Maybe | Usually an M.2 2230 Key-E socketed module. If socketed, swappable to an Intel AX210 (Wi-Fi 6E, ~EUR 15) — would fix the flaky Wi-Fi. Same teardown, re-seat the u.FL antennas. |
| **Battery** | ⚠️ Yes, but | Pouch cell, replaceable in the same teardown. Genuine Eve V cells are essentially unobtainium; some fit generic cells. |
| **CPU / GPU / ports / display** | ❌ No | BGA / integrated / fixed. |

## SSD replacement details

- Form factor: **M.2 2280** (the factory Intel 600p is a 2280 part — this is the
  proof; ignore any "2242" claims online).
- Interface: **PCIe 3.0 x4 NVMe**. A PCIe 4.0 drive works but only at 3.0 speed and
  runs **hotter** — bad in a sealed fanless chassis.
- Recommended: an efficient **PCIe 3.0, DRAM-less or mainstream** drive — WD Blue
  SN570/SN580, Crucial P3, Kingston NV2, Samsung 970 EVO Plus. 1 TB ~EUR 55-70.
- **Avoid** PCIe 4.0 flagships (990 Pro, SN850X) — no benefit, more heat.
- Add a thin graphene / silicone thermal pad between drive and chassis. **No tall
  heatsink** — no clearance.

## Opening the tablet — difficulty

**iFixit-hard, ~2/10.** There is **no service hatch**. Access is by lifting the
**glued display** (heat + suction cups + thin picks), exactly like a Surface Pro
4/5. There is **no Eve V tablet teardown guide** — people improvise from Surface
Pro videos.

Risks: cracking the display glass, tearing the display flex, and — the serious one
— **the battery sits directly under the screen**, so a slipped metal tool can
puncture a LiPo (fire). Keep metal away from the battery, work on a powered-off
device for continuity checks, and re-seal with fresh adhesive strips.

For the value of a 2017 tablet, the risk/reward on the internal SSD swap is poor.
**Prefer external.**

## External "upgrades" (no teardown)

| Item | Why | ~Price |
|---|---|---|
| **External NVMe in a USB-C / TB3 enclosure** | fast storage, backup target, or boot Linux off it and bypass the flaky internal SSD entirely | enclosure EUR 20 + drive EUR 55 |
| **USB-C hub / Thunderbolt 3 dock** | only 2x USB-A + 1x USB-C data on the tablet. TB3 dock = one cable for displays + peripherals + charging | hub EUR 35 / TB3 dock EUR 100-130 |
| **65 W GaN USB-C charger** | the Eve V charges over USB-C PD; a modern charger is small and gives headroom over the 45 W original | EUR 30 |
| **USB-C -> HDMI/DP cable** | the USB-C port does DP Alt Mode -> external display directly | EUR 12 |
| **Stand / VESA mount** | unlocks wall-dashboard / desk-monitor / kitchen-display reuse | EUR 15-20 |
| **Cooling pad with fans** | fanless -> throttles under sustained load; helps the SoC and the hot SSD | EUR 20 |
| **BT / USB-C game controller** | for game-streaming / emulation use | EUR 40 |
| **USB-C gigabit ethernet** | for headless / dashboard use; more reliable than the Wi-Fi | EUR 15 |
| **PD power bank (>=45 W)** | runtime + a hedge against the inaccurate battery gauge | EUR 35-40 |

## Stylus

ELAN digitizer (`04F3:200A`) → **MPP** (Microsoft Pen Protocol). Measured: 2048
pressure levels, **no tilt**. So a cheap MPP pen (Surface Pen 1776, Metapen M1) is
as good as an expensive one here — don't pay for tilt / MPP 2.x. If your unit is an
early Wacom-AES batch instead, use a Wacom Bamboo Ink; a dual MPP+AES pen (Bamboo
Ink Plus) covers both.

## DIY protective case with kickstand + external cooling

Feasible as a snap-fit over-case (rigid PETG/ASA back tray + TPU bumper), with
either a cutout for the original kickstand or your own printed friction-hinge
kickstand.

**External cooling — the one rule: never insulate the aluminium hot-zone.** A
plastic case over the SoC area traps heat and makes throttling worse. Options,
best-effort-first:

1. **Passive:** window in the case back over the SoC hot spot + a low-profile
   aluminium heatsink pressed to the tablet's aluminium via a 1-2 mm thermal pad
   (spring/foam preload). ~EUR 8. Gains ~5-15 C of headroom.
2. **Active:** add a 40-50 mm 5 V fan (off a USB-A port) over the heatsink /
   exposed aluminium. Near-eliminates throttling for a 4.5 W chip. Noise + bulk.
3. **Conductive shell:** a thin aluminium plate as the case-back core, pad-coupled
   to the tablet, becomes extra radiator area. Metal-filled filament does little.

**Measure first:** run a 15 min stress test with HWiNFO logging CPU temp + the
throttle flag, and IR-map the back. If it doesn't throttle for your workload, skip
cooling and just add a ventilation window. The SSD hot spot is a separate location
— for SSD heat, an external USB-C NVMe is a better answer than any case mod.
