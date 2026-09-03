# 6 — Drivers and BIOS

Eve-Tech / Dough is defunct. `eve-tech.com` driver downloads are gone.

## BIOS

- **5.12** (AMI, 2017-10-31) is the **final** BIOS and is almost certainly already
  installed. Check: `Get-CimInstance Win32_BIOS | Select SMBIOSBIOSVersion`.
- There is no newer one. Do not chase BIOS updates.
- Thunderbolt settings live under `Advanced > Thunderbolt Configuration` in the
  UEFI setup (enter with **Volume-Down** held at power-on). If USB-C / Thunderbolt
  misbehaves: ensure Thunderbolt support is Enabled and the security level is
  "No Security" or "User Authorization".

## Drivers — where to get them now

| Source | Notes |
|---|---|
| **r/evev** subreddit | Community members have archived Eve driver packs / mirrored the original download bundle. Best first stop — ask in a post or search. |
| **Windows Update** | Covers Intel chipset, graphics, and often the Wi-Fi/BT — but ships **old** versions (e.g. 8265 driver 20.70.x). |
| **Intel** directly | Latest **HD Graphics 615**, **Wireless-AC 8265** (Wi-Fi + BT), **Serial IO**, **Management Engine** drivers. Safe, current. |
| **Realtek / TI** | The audio codec + **smart-amp** component. The amp part is the one usually missing; a community Eve audio package is the practical route. |
| **Goodix** | Fingerprint. Newer than the 2017 `v1.0.20.600` may help if the sensor is alive. Community mirror. |
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
