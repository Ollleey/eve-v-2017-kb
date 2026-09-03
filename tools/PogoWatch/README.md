# PogoWatch

Small WinForms tool (Windows PowerShell 5.1, no install) that monitors USB / HID
devices in real time and logs attach / detach events — with debug functions
specific to the **Eve V detachable keyboard** (Novatek `VID_0603` / `PID_00F1`),
which hangs directly off the PCH xHCI root hub on the pogo pins.

## Launch

| File | Purpose |
|---|---|
| `Start-PogoWatch.bat` | normal launch (enough for logging/monitoring) |
| `Start-PogoWatch-Admin.bat` | elevated (only needed if you want the "Rescan HW" button to run without a separate UAC prompt each time) |

Double-click. On launch it automatically runs a probe and starts monitoring.

## Controls

| Element | Function |
|---|---|
| **START / STOP** | monitoring on/off |
| **poll ms** | device-list sampling interval (500-10000). Lower = named faster, but each enumeration costs ~1-2 s |
| **Probe now** | immediate snapshot: all USB/HID nodes, keyboard status (present / phantom / absent), hubs, root hubs |
| **MARKER** | inserts a marker line in the log — press before/after every physical action |
| **Rescan HW** | `pnputil /scan-devices` (elevated) — forces re-detection |
| **Clear** | clears the log window (file is kept) |
| **Open log** | opens the folder with the log files |
| **pogo filter** | show only events for `VID_0603`, `VID_05E3` and root hubs |
| **sound** | play a sound on a keyboard event |
| **on top** | keep the window always on top |

Each session writes to `logs\pogowatch_YYYYMMDD_HHMMSS.log` (with ms timestamps).

## Reading the log — diagnosis

**A `WMI -> DEVICE ARRIVED` line appears but NO `+ CONNECT` line follows**
→ The root-hub port sees the pogo pins electrically (D+ pull-up / VBUS) but the
  keyboard fails to enumerate. Points to a **broken ribbon cable at the hinge** or
  a **dead Novatek controller** — not the port.

**You attach the keyboard and NOTHING happens** (no WMI line, no `+`/`-`)
→ Dead connection: pins not making contact, or the hinge ribbon is fully open.

**`+ CONNECT ... VID_0603` appears cleanly**
→ The keyboard is electrically fine. If it still doesn't type: a driver / HID
  issue, not hardware.

**`PCH xHCI root hub: MISSING`**
→ The whole USB stack is down. Do one full shutdown (Fast Startup / cold-boot bug),
  not a keyboard problem.

**Note on `VID_05E3`**
→ There is **no internal hub**. The USB-A ports **and** the pogo-pin connector hang
  directly off the PCH xHCI root hub. `VID_05E3` = an *external* hub someone plugged
  in; its "absent" means nothing for this diagnosis.

## Test workflow

1. **START**
2. **MARKER**
3. physically attach the keyboard (firmly, centered)
4. wait 5-10 s
5. detach the keyboard
6. wait 5-10 s
7. **MARKER**
8. **Open log**, read the lines between the markers

## Limits

- The WMI line has ~1 s latency (`WITHIN 1`).
- Device enumeration (`Win32_PnPEntity`) takes ~1-2 s per poll — sub-second blips
  show up on the WMI line, not necessarily on a `+/-` line.
- Pure Windows tool, no kernel / bus level. If the USB stack doesn't report it, the
  tool can't see it.
