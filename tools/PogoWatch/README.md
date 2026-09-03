# PogoWatch

Kleines WinForms-Tool (Windows PowerShell 5.1, kein Install) das USB-/HID-Geräte
in Echtzeit überwacht und An-/Abstecken protokolliert — mit Debug-Funktionen
speziell für die **Eve-V-Ansteck-Tastatur** (Novatek `VID_0603` / `PID_00F1`),
die direkt am PCH-xHCI-Root-Hub an den Pogo-Pins hängt.

## Starten

| Datei | Zweck |
|---|---|
| `Start-PogoWatch.bat` | normaler Start (reicht fürs Loggen) |
| `Start-PogoWatch-Admin.bat` | als Admin (nur nötig, wenn „Rescan HW" ohne separaten UAC-Prompt laufen soll) |

Doppelklick genügt. Beim Start läuft automatisch ein Probe + das Monitoring.

## Bedienung

| Element | Funktion |
|---|---|
| **START / STOP** | Monitoring an/aus |
| **poll ms** | Abtastintervall der Geräteliste (500–10000). Kleiner = schneller benannt, aber jede Enumeration kostet ~1–2 s |
| **Probe now** | Sofort-Momentaufnahme: alle USB/HID-Knoten, Status der Tastatur (präsent / Phantom / abwesend), Hub, Root-Hubs |
| **MARKER** | setzt eine Markierungszeile ins Log — vor/nach jeder physischen Aktion drücken |
| **Rescan HW** | `pnputil /scan-devices` (elevated) — erzwingt Neuerkennung |
| **Clear** | Log-Fenster leeren (Datei bleibt) |
| **Open log** | Ordner mit den Logdateien öffnen |
| **pogo filter** | nur Ereignisse zu `VID_0603`, `VID_05E3` und Root-Hubs zeigen |
| **sound** | Ton bei Tastatur-Ereignis |
| **on top** | Fenster immer im Vordergrund |

Jede Session schreibt nach `logs\pogowatch_JJJJMMTT_HHMMSS.log` (mit ms-Zeitstempeln).

## Log lesen — Diagnose

**`WMI -> DEVICE ARRIVED` erscheint, aber KEINE `+ CONNECT`-Zeile folgt**
→ Der Root-Hub-Port sieht die Pogo-Pins elektrisch (D+ Pull-up / VBUS), aber die Tastatur
  enumeriert nicht. Deutet auf **Flexkabel im Scharnier** oder **Novatek-Controller**,
  nicht auf den Port.

**Tastatur anstecken und es passiert GAR NICHTS** (kein WMI, kein `+`/`-`)
→ Tote Verbindung: Pins ohne Kontakt oder Scharnier-Ribbon komplett unterbrochen.

**`+ CONNECT ... VID_0603` erscheint sauber**
→ Tastatur ist elektrisch ok. Wenn sie trotzdem nicht tippt: Treiber/HID-Problem,
  nicht Hardware.

**`PCH xHCI root hub: MISSING`**
→ Der komplette USB-Stack ist unten. Einmal komplett herunterfahren
  (Fast-Startup-/Kaltstart-Bug), nicht die Tastatur.

**Hinweis zu `VID_05E3`**
→ Es gibt **keinen internen Hub**. USB-A-Ports **und** der Pogo-Pin-Anschluss
  hängen direkt am PCH-xHCI-Root-Hub. `VID_05E3` = ein *externer* Hub, den du
  eingesteckt hast — sein „absent" bedeutet nichts für die Diagnose.

## Test-Workflow

1. **START**
2. **MARKER**
3. Tastatur physisch anstecken (fest, mittig)
4. 5–10 s warten
5. Tastatur abziehen
6. 5–10 s warten
7. **MARKER**
8. **Open log**, Zeilen zwischen den Markern lesen

## Grenzen

- Die WMI-Zeile hat ~1 s Latenz (`WITHIN 1`).
- Die Geräte-Enumeration (`Win32_PnPEntity`) dauert ~1–2 s pro Poll — sub-sekündige
  Blips siehst du an der WMI-Zeile, nicht zwingend an einer `+/-`-Zeile.
- Reines Windows-Tool, keine Kernel-/Bus-Ebene. Was der USB-Stack nicht meldet,
  sieht das Tool nicht.
