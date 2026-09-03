# 6 — Drivers and BIOS

Eve-Tech / Dough is defunct. `eve-tech.com` driver downloads are gone.

## Firmware — there are FIVE components, not just "the BIOS"

The AMI SMBIOS string (`5.12`) is only the system BIOS. Eve shipped five separate
firmware packages, each versioned on its own and each with an `instructions.pdf`.
Full detail + cautions:
[docs/08-community-findings.md#8.1](08-community-findings.md#81-the-v-has-five-separately-updatable-firmware-components).

| Component | Update it for | Risk |
|---|---|---|
| **BIOS** | Spectre/Meltdown mitigation (>= `0.41`), boot fixes, the accidental-wake beta | disable Defender first; have BitLocker key; AC power |
| **Battery EC** | faster internal-battery charging | low, optional |
| **Thunderbolt 3 NVM** | external TB3 device compatibility / flakiness | only if a TB3 device misbehaves |
| **Keyboard & Touchpad** | touchpad sensitivity, duplicate/dropped keys | reversible - roll back if worse |
| **Touch Panel** | ghost touches, touch sensitivity | reversible - roll back if worse |

- Check your BIOS: `Get-CimInstance Win32_BIOS | Select SMBIOSBIOSVersion`.
- **:warning: "firmware 1.04" bricked some displays** (red stripes -> permanent
  black). "1.06" had detection problems. Flash **only** the component you have a
  concrete problem with, from a trusted source.
- Thunderbolt settings: `Advanced > Thunderbolt Configuration` in UEFI setup
  (enter with **Volume-Down** at power-on, or **Esc** repeatedly at the logo).
  Ensure Thunderbolt support = Enabled, security level = "No Security" or
  "User Authorization".
- Eve V BIOS keys: **Esc** (at logo) to enter setup, **Fn+F3** load defaults,
  **Fn+F4** save & exit.

## Drivers — where to get them now

| Source | Notes |
|---|---|
| **r/evev** subreddit | Community members have archived Eve driver packs / mirrored the original download bundle. Best first stop — ask in a post or search. |
| **Windows Update** | Covers Intel chipset, graphics, and often the Wi-Fi/BT — but ships **old** versions (e.g. 8265 driver 20.70.x). |
| **Intel** directly | Latest **HD Graphics 615**, **Wireless-AC 8265** (Wi-Fi + BT), **Serial IO**, **Management Engine** drivers. Safe, current. |
| **Realtek / TI** | The audio codec + **smart-amp** component. The amp part is the one usually missing; a community Eve audio package is the practical route. |
| **Goodix** | Fingerprint. Newer than the 2017 `v1.0.20.600` may help if the sensor is alive. Community mirror. |
| **X-Station** (`x-station.cn`) | Chinese community that also sold the "V2"; hosts a full V2 driver set + a BIOS. Forum says the machines are identical; Eve staff explicitly warned against it. Last resort, **drivers only, never the BIOS**. |
| Third-party DBs (station-drivers, driveridentifier, etc.) | Last resort. Verify hashes, scan, prefer OEM/Intel originals. |
| **FCC filings** (`fccid.io/2A2CZ-E134`) | Internal/external teardown photos, user manual — documentation, not drivers. |
| **ArchWiki** `Laptop/Other` -> Eve V (2017) | For Linux. |

## Driver versions worth updating (seen stale on a 2021-imaged unit)

| Component | Stale version seen | Action |
|---|---|---|
| Intel Wireless-AC 8265 | 20.70.21.2 (2021-10) | update to latest 22.x from Intel |
| Realtek High Definition Audio | 6.0.1.8531 (2018-04) | Eve audio package (Realtek + TI amp) |
| Intel HD Graphics 615 | 31.0.101.2111 (2022-07) | 31.0.101.2115 is about the last for Gen9 — basically current |
| Goodix Fingerprint | 1.0.20.600 (2017-10) | newer Goodix if sensor alive; otherwise disable the device |
| Card reader (Intel SCC SD) | 10.1.5.1 (2018-01) | Windows Update / Intel Serial IO |

## Activation

Original units carry an **embedded OEM Windows 10 Home** key in firmware
(`OA3xOriginalProductKey`). A clean Windows 10/11 install activates automatically —
you do not need to enter a key.
