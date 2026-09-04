# Eve V (2017) — Community Knowledge Base

Unofficial, community-maintained notes on the **original Eve V (2017)** 2-in-1:
known problems, what causes them, and how to fix them. Eve-Tech / Dough no longer
supports this device, so this exists to keep the useful information in one place.

> ⚠️ **Disclaimer.** Started from the full diagnosis of **one** i7-7Y75 unit plus
> public research (reviews, r/evev, ArchWiki, FCC filings). Items are tagged by how
> well they are established:
> - `[confirmed]` — reproduced/measured on a real unit
> - `[reported]` — multiple community/review reports, not verified here
> - `[theory]` — plausible mechanism, unverified
>
> Hardware work on this device is **not beginner-friendly** (glued display, LiPo
> directly under the screen, fine soldering). Read the safety notes. You do this at
> your own risk.

---

## Start here

| I want to… | Go to |
|---|---|
| Find out exactly which Eve V I have | [docs/01-identify-your-unit.md](docs/01-identify-your-unit.md) |
| Fix a specific problem | [docs/02-known-issues-and-fixes.md](docs/02-known-issues-and-fixes.md) |
| Deal with a dead detachable keyboard | [docs/03-keyboard-and-pogo-pins.md](docs/03-keyboard-and-pogo-pins.md) |
| Run Linux on it | [docs/04-linux.md](docs/04-linux.md) |
| Upgrade RAM / SSD / battery / Wi-Fi | [docs/05-upgrades-and-hardware.md](docs/05-upgrades-and-hardware.md) |
| Find drivers now that Eve is gone | [docs/06-drivers-and-bios.md](docs/06-drivers-and-bios.md) |
| Build my own replacement keyboard | [docs/07-diy-keyboard-replacement.md](docs/07-diy-keyboard-replacement.md) |
| See what the old Eve forum / r/evev worked out | [docs/08-community-findings.md](docs/08-community-findings.md) |

## Tools

| Tool | Purpose |
|---|---|
| [tools/eve-v-healthcheck.ps1](tools/eve-v-healthcheck.ps1) | One script: identifies the unit and checks every known software-fixable issue. Produces a Markdown report you can paste into an issue. |
| [tools/PogoWatch/](tools/PogoWatch/) | Live USB monitor with debug tools for diagnosing the pogo-pin keyboard without opening anything. |

## The 60-second summary

- **Only one Eve V ever shipped.** The "2021" relaunch = the same 2017 hardware
  resold. The Tiger Lake "V 2020" was cancelled.
- **Configs:** m3-7Y30 / 8 GB / 128 GB · i5-7Y54 / 8 GB / 256 GB · i7-7Y75 / 16 GB / 512 GB.
  RAM is soldered. One M.2 2280 NVMe slot. Fanless.
- **The famous failure:** the detachable keyboard's **ribbon cable snaps at the
  hinge fold**. Bluetooth in the keyboard is independent of that cable.
- **Biggest software win:** turn **Fast Startup off**. Many "USB stopped working",
  "won't wake", "sleep drains battery" reports trace back to hybrid-boot state on a
  machine that has not had a real cold boot in months.
- **Random wake from sleep** is the folded keyboard cover still sending keypresses.
  Fix in Device Manager (uncheck "allow this device to wake") - see
  [8.2](docs/08-community-findings.md#82-random-wake-from-sleep-accidental-keyboard-input).
- **Pen/touch dead after a Windows upgrade?** Uninstall the Wacom HID device and
  rescan - Windows binds a working generic driver.
  See [8.3](docs/08-community-findings.md#83-touchscreen--pen-dead-after-a-windows-10--11-upgrade-or-reinstall).
- The V has **five** separately-flashable firmware blobs (BIOS, battery EC,
  Thunderbolt NVM, keyboard/touchpad, touch panel) - and some old versions
  ("firmware 1.04") **bricked displays**. Flash only what's broken.
  See [8.1](docs/08-community-findings.md#81-the-v-has-five-separately-updatable-firmware-components).
- **Linux:** daily-driver viable on kernel 6.6+. Only the cameras need real work.
- **"The Thunderbolt controller is missing!"** — no, it's asleep. The Alpine Ridge
  chip powers fully off the PCI bus when nothing is plugged into either USB-C port
  (RTD3). Plug in a USB-C device and it comes back. Don't diagnose USB-C with
  nothing connected. ([issue 2.17](docs/02-known-issues-and-fixes.md#217-the-thunderbolt--alpine-ridge-controller-disappears))

## Contributing

PRs welcome — especially: confirmed pogo-pin **pinout**, teardown photos with
measurements, driver-package mirrors, per-config differences, Linux fixes.
See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Docs: CC BY 4.0. Scripts/tools: MIT. See [LICENSE](LICENSE).
