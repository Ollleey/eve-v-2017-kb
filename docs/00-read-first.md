# 0 — Read this first: accuracy, safety, how to use this

## This is community notes, not a manual

Most of this knowledge base was built from **one Eve V unit** (i7-7Y75, ELAN
digitizer) plus public sources: reviews, the archived `eve.community` forum,
r/evev, the ArchWiki, iFixit, and FCC filings. Eve-Tech / Dough is gone and there
is no official documentation to check against.

**So assume some of it is wrong, incomplete, or specific to one batch.**

- Values, pin counts, version numbers, part numbers and driver names are
  best-effort. **Verify against your own unit** before acting (`lspci`, Device
  Manager, a multimeter, your own eyes).
- Tags: `[confirmed]` = reproduced/measured on a real unit · `[reported]` =
  multiple community reports, not verified here · `[theory]` = plausible, unverified.
  Even `[confirmed]` means "on the one unit we checked".
- The Eve V shipped in several batches with **different digitizers, keyboards, and
  possibly other parts**. Something true for one unit can be false for yours.
- If you find something wrong, please open an issue or PR — see
  [CONTRIBUTING](../CONTRIBUTING.md).

## Safety — read before any hardware work

Opening this device is genuinely risky. Nothing here is written by a professional
repair technician.

- **The LiPo battery sits directly under the glued display.** A slipped metal
  tool, a puncture, a sharp bend, or a short can make a lithium-polymer cell vent
  or catch fire. If a cell is **swollen / puffed, do not charge it, do not press
  it, do not puncture it** — see iFixit's guide:
  <https://www.ifixit.com/Wiki/What_to_do_with_a_swollen_battery>
- **Prying a glued screen** cracks glass and tears display/digitizer ribbons
  routinely. There is **no iFixit guide for the Eve V tablet** — people improvise
  from Microsoft Surface Pro 4/5 teardowns.
- **Soldering** near a battery, near flex cables, and on fine pitch pads needs the
  right iron, flux, and steady hands. Practice on scrap first.
- **Firmware flashing** can permanently brick a component. Some old Eve V firmware
  versions ("1.04") **bricked displays** — see [8.1](08-community-findings.md#81-the-v-has-five-separately-updatable-firmware-components).
- Work on a **powered-off, unplugged** device for anything electrical except the
  few live-voltage checks that explicitly say "device on".
- **You do all of this at your own risk.** If the device still half-works and you
  depend on it, think hard before opening it.

## iFixit resources

| Resource | Link |
|---|---|
| EVE V Keyboard — device page | <https://www.ifixit.com/Device/EVE_V_keyboard> |
| EVE V Keyboard — disassembly guide | <https://www.ifixit.com/Guide/EVE+V+Keyboard+Disassembly/126817> |
| Swollen battery — what to do | <https://www.ifixit.com/Wiki/What_to_do_with_a_swollen_battery> |
| Soldering skills | <https://www.ifixit.com/Guide/Soldering+Skills/25432> |
| Prying / opening technique | <https://www.ifixit.com/Guide/How+to+Use+a+Spudger/25401> |
| Microsoft Surface Pro 5 teardown (closest analog for the tablet internals) | <https://www.ifixit.com/Teardown/Microsoft+Surface+Pro+5+Teardown/89600> |
| linux-surface project (IPU3 cameras, same hardware) | <https://github.com/linux-surface/linux-surface> |

There is **no iFixit teardown or battery guide for the Eve V tablet itself** — only
the keyboard. An iFixit "Answers" question asking how to replace the tablet battery
has zero answers.

## How to use this knowledge base

1. [01 — Identify your unit](01-identify-your-unit.md). Config and digitizer batch
   change the advice.
2. Run [`tools/eve-v-healthcheck.ps1`](../tools/eve-v-healthcheck.ps1). It checks
   every software-fixable issue and points each finding at a section number.
3. Go to the relevant section of [02 — Known issues and fixes](02-known-issues-and-fixes.md).
4. For the detachable keyboard, [03](03-keyboard-and-pogo-pins.md) and
   [07](07-diy-keyboard-replacement.md).
5. [08 — Community findings](08-community-findings.md) for the stuff the old forum
   worked out (firmware, wake bugs, ghost touches, EFI-shell recovery).
