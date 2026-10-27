# q6a-mac-flash

Update the SPI boot firmware (XBL / UEFI) of a **Radxa Dragon Q6A** (Qualcomm QCS6490) from a **Mac**, using Qualcomm EDL mode and [edl-ng](https://github.com/strongtz/edl-ng).

Radxa documents this only for Linux and Windows. This repo wraps the same procedure for macOS: it downloads pinned, SHA-256-verified firmware and `edl-ng`, **backs up the current SPI contents**, and then flashes.

> **Use at your own risk.** This overwrites the board's boot firmware. It has been tested on **one** board (Armbian, macOS on Apple Silicon). Radxa says the board ships with working firmware and only needs reflashing if it fails to boot. Keep a way to re-enter EDL mode and read the warnings below first. Not affiliated with Radxa, Qualcomm or the edl-ng author.

## Requirements

- Mac (Apple Silicon or Intel), `curl`, `unzip`, `shasum` (all built in)
- USB-A to USB-A data cable (plus a USB-C to USB-A adapter if your Mac has only USB-C)
- 12 V USB-C PD power supply for the board
- `sudo` (raw USB access)

edl-ng ships its own `libusb`; nothing needs to be installed.

## Usage

```sh
./q6a-flash.sh fetch 260120     # download + verify firmware and edl-ng (optional; `flash` does it too)
./q6a-flash.sh check            # is the board visible in EDL mode?
./q6a-flash.sh flash 260120     # back up, confirm, flash
```

Firmware versions (pinned in the script):

| Version | Notes |
|---|---|
| `260120` (default) | Documented release: UEFI HDMI, PXE/HTTP boot, persistent UEFI variables (needs kernel ≥ 6.18). [Release notes](https://forum.radxa.com/t/radxa-dragon-q6a-firmware-snapshot/28886) |
| `260916` | Newest in Radxa's [download index](https://dl.radxa.com/dragon/q6a/images/). Built from [edk2-qualcomm PR #26](https://github.com/radxa-pkg/edk2-qualcomm/pull/26); no release notes found. Adds a `LOGO` partition and a changed GPT. Worked on the author's board. |

Do **not** use `250929`; it left some boards unbootable.

### Entering EDL mode

1. Power the board off.
2. Hold the **EDL** button.
3. Connect the 12 V PD supply to the USB-C power port, then release the button.
4. Connect the USB-A cable from the board's **USB 3.1 Type-A port** to the Mac.
5. `./q6a-flash.sh check` should report the device (USB `05c6:9008`, shows as `QUSB_BULK` in `ioreg`).

### What `flash` does

1. Downloads and verifies the firmware and `edl-ng` (aborts on checksum mismatch).
2. Dumps all SPI-NOR partitions plus `rawprogram0.xml`/`patch0.xml` to `backups/spinor-<timestamp>/`.
3. Runs `edl-ng rawprogram rawprogram0.xml patch0.xml` for the `spinor` memory.

It asks you to type `FLASH` unless you pass `--yes`. Afterwards power-cycle the board. The `ddr` partition is overwritten with zeros, so DDR training re-runs and the **first boot can take longer**; don't interrupt it. `VarStore` (UEFI variables) is not written.

Expected end of a successful run: `'rawprogram' command finished successfully.` Harmless: `libusb: warning ... transfer error: timed out`, `fat12test.bin not found`.

## Recovery

If the board does not boot, enter EDL mode again and re-flash a known-good release (`./q6a-flash.sh flash 260120`). Backups in `backups/` hold the previous partitions and a `rawprogram0.xml` describing them; restoring from them is **untested**. Backups contain device-specific data (SMBIOS, serial numbers); they are git-ignored, don't publish them.

A serial console (`ttyMSM0`) shows DDR-training errors if boot fails early. A board with failing DDR hardware cannot be fixed by reflashing.

## Notes on firmware vs. OS

The SPI firmware contains XBL, TZ, hypervisor, AOP, CPUCP and UEFI. GPU (Adreno) and DSP/NPU firmware are loaded by the OS (`linux-firmware`, `remoteproc`), so most GPU/NPU problems are fixed in the OS, not here. See [docs/flash-log.md](docs/flash-log.md) for what was checked after flashing.

## Verified checksums

SHA-256 values in the script were computed from the official downloads (Radxa does not publish checksums), so they detect corruption and later tampering, not a malicious original.

## License

MIT, see [LICENSE](LICENSE). Firmware and edl-ng are third-party and not included in this repository.
