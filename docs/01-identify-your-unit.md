# 1 — Identify your unit

There is effectively **one Eve V**. But there are 3 CPU configs and at least 2
digitizer batches, and that changes which pen you buy and which SSD fits.

## Quick check (Windows, no admin)

```powershell
Get-CimInstance Win32_ComputerSystem      | Select Manufacturer,Model,SystemFamily,SystemSKUNumber
Get-CimInstance Win32_Processor           | Select Name
Get-CimInstance Win32_PhysicalMemory      | Select DeviceLocator,Capacity,Speed
Get-CimInstance Win32_DiskDrive           | Select Model,Size
Get-CimInstance Win32_BIOS                | Select SMBIOSBIOSVersion,ReleaseDate
Get-CimInstance -Namespace root\wmi WmiMonitorID |
  ForEach-Object { -join ($_.ManufacturerName + $_.ProductCodeID | ? {$_} | % {[char]$_}) ; $_.YearOfManufacture }
Get-PnpDevice -Class HIDClass | ? FriendlyName -match 'pen|touch' | Select FriendlyName,InstanceId
```

`tools/eve-v-healthcheck.ps1` does all of this and more.

## What the values mean

| Field | Original Eve V (2017) |
|---|---|
| `Manufacturer` / `Model` | `EVE` / `Eve V` |
| `SystemFamily` | `I60` |
| `SystemSKUNumber` | `EMWT02I60P01Cfg00EVEORD0` (EM = Emdoor, the ODM) |
| OEM model (registry `OEMInformation`) | `V00001` |
| `SMBIOSBIOSVersion` | `5.12`, release `2017-10-31` — **the final BIOS** |
| Serial numbers in SMBIOS | all `Default string` — Emdoor never burned real serials. Normal. |

## The three CPU configs

| Config | CPU | RAM | SSD | Notes |
|---|---|---|---|---|
| m3 | Core m3-7Y30 | 8 GB LPDDR3 | 128 GB | |
| i5 | Core i5-7Y54 | 8 GB LPDDR3 | 256 GB | |
| **i7** | Core **i7-7Y75** | **16 GB** LPDDR3-1866 | **512 GB** (Intel 600p) | top config |

All are Kaby Lake-Y, 2 cores / 4 threads, 4.5 W base TDP, Intel HD Graphics 615,
**fanless**. RAM is soldered on every config.

## Display

12.3", 2880 x 1920, 3:2, **Sharp IGZO**. EDID reports `SHP 149x`. Panel build dates
seen: week ~20/2017. This dates the *panel*, roughly the unit — original units
shipped late 2017 / early 2018.

## Digitizer — the important batch difference

Early original units: **Wacom AES** active pen.
Later original units (and the 2021 relaunch stock): **ELAN** digitizer, hardware ID
`HID\VID_04F3&DEV_200A`.

Check yours:

```powershell
Get-PnpDevice | ? InstanceId -match 'WACF|WCOM|04F3' | Select FriendlyName,InstanceId
```

- Hardware ID contains `04F3` / `200A` → **ELAN** → buy an **MPP** pen
  (Microsoft Pen Protocol; e.g. Surface Pen model 1776, Metapen M1).
  Measured capability on an ELAN unit: **2048 pressure levels, no tilt.**
- Hardware ID contains `WACF` / `WCOM` → **Wacom AES** → Wacom Bamboo Ink (CS-323),
  Lenovo/Dell/HP Active Pen.
- Unsure → a **dual MPP + Wacom AES** pen (Bamboo Ink Plus CS-321) covers both.

## "Is mine the 2021 / Dough version?"

Hardware-wise there is no difference to find — the relaunch resold 2017 platform
units. Signals that a unit passed through the 2021 relaunch: a fresh Windows image
dated 2020-2021, ELAN digitizer, `dough.tech` in OEM support URL (original units
say `eve-tech.com`). None of this changes drivers, BIOS, or upgrade paths.

## What never shipped

- Eve V "2020"/"2021" with **Tiger Lake** (11th gen), Thunderbolt 4, 4K panel —
  announced, taken as pre-orders, **never delivered**.
