# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`q6a-mac-flash`: a single bash script (`q6a-flash.sh`) plus docs that update the SPI-NOR boot firmware of a Radxa Dragon Q6A (QCS6490) from macOS over EDL using `edl-ng`. User-facing docs are in `README.md`; evidence from a real flash is in `docs/flash-log.md`.

## Commands

- `./q6a-flash.sh fetch [VERSION]` — download + SHA-256-verify firmware and edl-ng into `cache/`.
- `./q6a-flash.sh check` — looks for the EDL USB device (`ioreg`).
- `./q6a-flash.sh flash [VERSION] [--yes]` — backs up SPI to `backups/`, then flashes. **Never run it (or `edl-ng rawprogram`/`erase-*`) without explicit user confirmation**; it overwrites hardware firmware and needs the user's sudo password (suggest `! ./q6a-flash.sh flash …`).
- Syntax check: `bash -n q6a-flash.sh`. No test suite. Must stay compatible with macOS's bash 3.2 (no associative arrays).

## Design notes

- Firmware versions and edl-ng are pinned by URL + SHA-256 inside `fw_info`/`edl_info` in the script. To add a release: download from the official index (https://dl.radxa.com/dragon/q6a/images/), compute `shasum -a 256`, add a `case` branch, update the README table.
- The flash sequence mirrors Radxa's Linux docs (`--memory spinor --loader prog_firehose_ddr.elf rawprogram rawprogram0.xml patch0.xml`, run from `flat_build/spinor/dragon-q6a`) with a `dump-rawprogram` backup first. Radxa's own docs: https://docs.radxa.com/en/dragon/q6a/low-level-dev/spi-fw
- Firmware `260120` is the default (documented release notes); `260916` is newer, has no release notes, adds a `LOGO` partition and a changed GPT.
- Tested on exactly one board; backup restore is untested.

## Do not commit

`cache/` (third-party binaries), `backups/` (device-specific SMBIOS/serial data), and anything with personal paths/hostnames. These are in `.gitignore`. Downloaded archives are untrusted: the script extracts each into its own directory and verifies checksums before extraction.
