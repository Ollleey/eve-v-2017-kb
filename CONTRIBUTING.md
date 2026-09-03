# Contributing

This is a community knowledge base for a discontinued device. Corrections and
additions are very welcome.

## Especially wanted

- **The pogo-pin connector pinout** — reverse-engineered from a dead keyboard, with
  photos. This does not exist publicly yet.
- **Teardown photos with measurements** — the tablet (no iFixit guide exists) and
  the keyboard connector block.
- **Per-config differences** — anything that differs between m3 / i5 / i7 or
  between digitizer batches.
- **Driver / BIOS mirrors** — links to community-hosted copies of the original Eve
  download bundle.
- **Linux fixes** — working configs for the speakers (TI amp), cameras (IPU3),
  accelerometer, standby.
- **Confirmations or corrections** of anything tagged `[reported]` or `[theory]`.

## How to submit

1. Open an issue or a PR.
2. Tag claims by evidence level:
   - `[confirmed]` — you measured/reproduced it; say on which config and how
   - `[reported]` — multiple independent reports; link them
   - `[theory]` — plausible mechanism, not verified
3. For a fix, include the exact commands / steps and what "success" looks like.
4. Run `tools/eve-v-healthcheck.ps1` and paste the report into hardware issues.

## Style

- Keep files ASCII where practical (PowerShell 5.1 mangles non-ASCII in scripts
  read without a BOM).
- One subsystem per section. Commands in fenced blocks. State the risk before any
  hardware step.

## Safety

Nothing in here should tell someone to do something dangerous without flagging it.
The battery sits under the glued screen; soldering near LiPos and prying glued
glass both carry real fire / injury risk. Say so, every time.
