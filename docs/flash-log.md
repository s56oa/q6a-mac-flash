# Flash log

Single data point; your results may differ.

- **Host:** macOS (Darwin 25.6, Apple Silicon), edl-ng 1.6.0, USB-A↔A cable via USB-C adapter.
- **Board:** Radxa Dragon Q6A, Armbian (kernel 6.18.2-current-qcs6490), booting normally before the update.
- **Flashed:** `dragon-q6a_flat_build_wp_260916`, 2026-10-27, ~3.5 min, `'rawprogram' command finished successfully`.
- **First boot:** came up normally, login OK.

Written partitions: `cdt, ddr (zeros), SYSFW_VERSION, SMBIOS, PLAT, XBL, XBL_CONFIG, AOP, TZ, DEVCFG, HYP, QUP, TZAPPS, MULTIIMGOEM, CPUCP, SHRM, ImageFv, PILFv`, primary and backup GPT. Not written: `VarStore`.

## Checked after flashing

- `adsp` and `cdsp` remoteprocs `running`; `/dev/fastrpc-{adsp,cdsp,cdsp-secure}` present.
- Adreno 660: SQE and GMU (v3.1.10) firmware loaded, `msm` DRM initialised, `/dev/dri/card1` and `renderD128` present.
- Ethernet up; TrustZone UEFI-secure-app client set up (`qcom_qseecom`).

## `dmesg` messages seen (no pre-update baseline)

- `psci: [Firmware Bug]: failed to set PC mode: -3`: the kernel falls back; commonly seen on Qualcomm boards.
- `mmc0: Failed to initialize a non-removable card`: likely empty optional eMMC.
- `[drm] Cannot find any crtc or sizes`: no display attached.
- `aic_load_fw ... probe failed with error -1`: USB Wi-Fi/BT driver, unrelated to SPI firmware.

## Not verified

Vulkan/OpenCL compute on the GPU, an actual NPU workload, Wi-Fi.
