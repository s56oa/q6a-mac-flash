#!/usr/bin/env bash
# q6a-flash: update the SPI-NOR boot firmware of a Radxa Dragon Q6A from macOS via EDL.
# Downloads pinned, checksum-verified firmware and edl-ng, backs up the current SPI
# contents, then flashes. See README.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CACHE="$ROOT/cache"
BACKUPS="$ROOT/backups"
DEFAULT_FW="260120"

EDL_VERSION="1.6.0"
EDL_BASE="https://github.com/strongtz/edl-ng/releases/download/v$EDL_VERSION"

die() { echo "error: $*" >&2; exit 1; }

# Scratch space for downloads; removed on any exit so failed runs leave nothing in cache/.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Pinned artifacts: name, URL, SHA-256 (computed from the official downloads).
fw_info() {
  case "$1" in
    260120)
      FW_URL="https://dl.radxa.com/q6a/images/dragon-q6a_flat_build_wp_260120.zip"
      FW_SHA="cf23a1742ae5d51c451947d82cb21fd3f1c10bbcd621d611f55520673e3f90ca" ;;
    260916)
      FW_URL="https://dl.radxa.com/dragon/q6a/images/dragon-q6a_flat_build_wp_260916.zip"
      FW_SHA="f736fdd6744cbbcce6d5b76feb813d6cd02593493b3a1213e8b3c7deb1f9d1fc" ;;
    *) die "unknown firmware '$1' (known: 260120, 260916)" ;;
  esac
}

edl_info() {
  case "$(uname -m)" in
    arm64)  EDL_ASSET="edl-ng-macos-arm64.zip"
            EDL_SHA="531f32420698b657e44939653a7c18c34d2196f0807f2e3ca38840c56b8449ce" ;;
    x86_64) EDL_ASSET="edl-ng-macos-x64.zip"
            EDL_SHA="e69d523ebb00a2ef5b7f775fca606654fb45fa21f6b4e53c74c5b5a3e237ed24" ;;
    *) die "unsupported CPU $(uname -m)" ;;
  esac
}

# download <url> <sha256> <dest-dir>: fetch, verify, unzip into a fresh directory.
fetch_zip() {
  local url="$1" sha="$2" dest="$3" tmp got
  [[ -d "$dest" ]] && { echo "have $dest"; return; }
  tmp="$WORK/$(basename "$dest")"
  rm -rf "$tmp"; mkdir -p "$tmp/x"
  echo "downloading $url"
  curl -fL# --proto '=https' --tlsv1.2 -o "$tmp/a.zip" "$url"
  got="$(shasum -a 256 "$tmp/a.zip" | cut -d' ' -f1)"
  [[ "$got" == "$sha" ]] || die "checksum mismatch for $url (got $got, expected $sha)"
  unzip -q "$tmp/a.zip" -d "$tmp/x"
  mv "$tmp/x" "$dest"   # only appears in the cache once fully verified and extracted
}

paths() {
  fw_info "$1"; edl_info
  FW_DIR="$CACHE/fw-$1/flat_build/spinor/dragon-q6a"
  EDL="$CACHE/edl-ng-$EDL_VERSION/edl-ng"
}

cmd_fetch() {
  local v="${1:-$DEFAULT_FW}"; paths "$v"
  mkdir -p "$CACHE"
  fetch_zip "$FW_URL" "$FW_SHA" "$CACHE/fw-$v"
  fetch_zip "$EDL_BASE/$EDL_ASSET" "$EDL_SHA" "$CACHE/edl-ng-$EDL_VERSION"
  [[ -f "$FW_DIR/prog_firehose_ddr.elf" && -f "$FW_DIR/rawprogram0.xml" && -f "$FW_DIR/patch0.xml" ]] \
    || die "unexpected firmware layout in $FW_DIR"
  [[ -f "$EDL" ]] || die "edl-ng not found at $EDL"
  chmod +x "$EDL"
  file "$EDL" | grep -q "Mach-O" || die "$EDL is not a macOS executable"
  # curl does not set it, but a browser-downloaded copy would be blocked by Gatekeeper.
  xattr -d com.apple.quarantine "$EDL" "$(dirname "$EDL")"/*.dylib 2>/dev/null || true
  echo "ok: firmware $v and edl-ng $EDL_VERSION ready in $CACHE"
}

edl_present() { ioreg -p IOUSB -w0 | grep -qiE "QUSB_BULK|QDL|9008"; }

cmd_check() {
  if edl_present; then echo "EDL device (Qualcomm 05c6:9008) found."
  else echo "No EDL device found. Enter EDL mode first (see README)."; return 1; fi
}

cmd_flash() {
  local v="$DEFAULT_FW" yes=0 a
  for a in "$@"; do case "$a" in --yes) yes=1;; *) v="$a";; esac; done
  cmd_fetch "$v"; paths "$v"
  edl_present || die "no EDL device found. Enter EDL mode first (see README)."
  local bk="$BACKUPS/spinor-$(date +%Y%m%d-%H%M%S)"
  cat <<PLAN
Plan (firmware $v):
  1. sudo edl-ng --memory spinor --loader prog_firehose_ddr.elf dump-rawprogram $bk --lun 0
  2. sudo edl-ng --memory spinor --loader prog_firehose_ddr.elf rawprogram rawprogram0.xml patch0.xml
PLAN
  if [[ $yes -ne 1 ]]; then
    read -r -p "Type FLASH to overwrite the board's SPI firmware: " a
    [[ "$a" == "FLASH" ]] || die "aborted"
  fi
  mkdir -p "$bk"
  cd "$FW_DIR"
  sudo "$EDL" --memory spinor --loader prog_firehose_ddr.elf dump-rawprogram "$bk" --lun 0
  sudo "$EDL" --memory spinor --loader prog_firehose_ddr.elf rawprogram rawprogram0.xml patch0.xml
  echo "Flashed. Power-cycle the board. Backup of the previous SPI contents: $bk"
}

case "${1:-}" in
  fetch) shift; cmd_fetch "$@" ;;
  check) cmd_check ;;
  flash) shift; cmd_flash "$@" ;;
  *) cat <<USAGE
usage: $0 <command>
  fetch [VERSION]          download + verify firmware and edl-ng (VERSION: 260120 [default], 260916)
  check                    is the board visible on USB in EDL mode?
  flash [VERSION] [--yes]  back up current SPI contents, then flash (asks for confirmation)
USAGE
     exit 2 ;;
esac
