#!/bin/bash
# Flash the openvela ESP32-P4 firmware to the ESP32-P4-Function-EV-Board.
#
# Usage:  ./flash_esp32p4.sh [serial-port] [baud]
#   e.g.  ./flash_esp32p4.sh /dev/ttyACM0
#         ./flash_esp32p4.sh /dev/ttyACM0 460800
#
# The firmware uses Espressif "Simple Boot": the application image is
# written directly at the ESP32-P4 ROM boot offset 0x2000 (unlike
# ESP32-C3/C6/H2, whose ROM boots from 0x0).
#
# Serial console (same USB cable, enumerates as /dev/ttyACM*):
#   - USB CDC-ACM via the chip's USB Serial/JTAG peripheral
#   - DTR must be asserted by the terminal (minicom, screen, etc.)
#   - Baud rate is ignored by USB CDC (always full speed)
#
# After flashing, attach with:
#   minicom -D /dev/ttyACM0
# or use a DTR-aware script (cat /dev/ttyACM0 won't work — see docs).

set -euo pipefail

PORT="${1:-/dev/ttyACM0}"
BAUD="${2:-921600}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Locate the openvela workspace root

find_root() {
  local d="$1"
  while [ "$d" != "/" ]; do
    if [ -x "$d/build.sh" ] && [ -d "$d/nuttx" ]; then
      echo "$d"
      return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}

ROOT="${OPENVELA_ROOT:-$(find_root "$SCRIPT_DIR")}" || {
  echo "error: openvela workspace root not found — set OPENVELA_ROOT" >&2
  exit 1
}

BIN="$ROOT/cmake_out/esp32p4-function-ev-board_nsh/nuttx.bin"

if [ ! -f "$BIN" ]; then
  echo "error: $BIN not found — build first:" >&2
  echo "  $SCRIPT_DIR/build_esp32p4.sh" >&2
  exit 1
fi

esptool -c esp32p4 -p "$PORT" -b "$BAUD" \
  --before default-reset --after hard-reset \
  write-flash 0x2000 "$BIN"

echo
echo "Done. Serial console: minicom -D $PORT   (DTR required, quit: Ctrl-A X)"
