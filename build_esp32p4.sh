#!/bin/bash
# Build the openvela ESP32-P4-Function-EV-Board firmware.
#
# Usage:  ./build_esp32p4.sh [menuconfig|distclean]
#
# Produces: <workspace>/cmake_out/esp32p4-function-ev-board_nsh/nuttx.bin
#
# Prerequisites (auto-installed by this script if missing):
#   - riscv32-esp-elf toolchain (esp-14.2.0 verified)
#
# The script pins the esp-hal-3rdparty fork and commit so the build is
# reproducible. See docs/adr/ADR-0003.md for the HAL dependency details.

set -euo pipefail

#-----------------------------------------------------------------------------
# Toolchain: check PATH, then common install locations, then auto-install
#-----------------------------------------------------------------------------

TOOLCHAIN_VERSION="esp-14.2.0_20260121"
TOOLCHAIN_ROOT="$HOME/.espressif/tools/riscv32-esp-elf/$TOOLCHAIN_VERSION/riscv32-esp-elf"

find_toolchain() {
  # Already in PATH?
  if command -v riscv32-esp-elf-gcc &>/dev/null; then
    return 0
  fi
  # Common espressif tools install locations
  for candidate in \
    "$TOOLCHAIN_ROOT/bin" \
    "$HOME/.espressif/tools/riscv32-esp-elf"/*/riscv32-esp-elf/bin \
    /opt/espressif/tools/riscv32-esp-elf/*/riscv32-esp-elf/bin; do
    if [ -x "$candidate/riscv32-esp-elf-gcc" ]; then
      export PATH="$candidate:$PATH"
      return 0
    fi
  done
  return 1
}

install_toolchain() {
  echo "=== riscv32-esp-elf toolchain not found, installing ==="

  # Use esp-idf-tools if available (it manages toolchain installs)
  if [ -x "$HOME/.espressif/python_env"/*/bin/python ] 2>/dev/null || \
     [ -d "$HOME/.espressif" ]; then
    echo "Detected existing ~/.espressif — using idf_tools.py to install"
    local idf_dir="$HOME/.espressif"

    # Find any esp-idf installation to borrow idf_tools.py from
    local idf_tools=""
    for candidate in \
      "$HOME/esp/esp-idf"*/tools/idf_tools.py \
      "$HOME/esp/esp-idf/tools/idf_tools.py" \
      "$HOME/esp-idf/tools/idf_tools.py"; do
      if [ -f "$candidate" ]; then
        idf_tools="$candidate"
        break
      fi
    done

    if [ -n "$idf_tools" ]; then
      python3 "$idf_tools" install riscv32-esp-elf
      python3 "$idf_tools" export --detection-timeout 10 > /dev/null
    fi
  fi

  # Re-check after install attempt
  if command -v riscv32-esp-elf-gcc &>/dev/null; then
    return 0
  fi

  # Fall back to scanning for the toolchain we just installed
  if find_toolchain; then
    return 0
  fi

  # Still not found: manual install instructions
  echo "error: riscv32-esp-elf toolchain installation failed" >&2
  echo "" >&2
  echo "Manual install:" >&2
  echo "  mkdir -p ~/.espressif/tools/riscv32-esp-elf" >&2
  echo "  # Download from:" >&2
  echo "  # https://github.com/espressif/crosstool-NG/releases" >&2
  echo "  # Or use esp-idf:" >&2
  echo "  #   git clone https://github.com/espressif/esp-idf.git" >&2
  echo "  #   ./esp-idf/install.sh esp32p4" >&2
  echo "  #   source ./esp-idf/export.sh" >&2
  exit 1
}

# Check and auto-install if needed
if ! find_toolchain; then
  install_toolchain
fi

echo "=== Toolchain: $(riscv32-esp-elf-gcc -dumpversion) ==="

#-----------------------------------------------------------------------------
# esp-hal-3rdparty remote dependency (pinned fork + commit).
# If GitHub is unreachable, configure your own proxy via the standard
# https_proxy / http_proxy environment variables before running.
#-----------------------------------------------------------------------------

export ESP_HAL_3RDPARTY_URL="https://github.com/cubegao/esp-hal-3rdparty.git"
export ESP_HAL_3RDPARTY_VERSION="a498192b2c15ad11c048a317c51d04389057bc74"

#-----------------------------------------------------------------------------
# Locate the openvela workspace root
#-----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

cd "$ROOT"

#-----------------------------------------------------------------------------
# Self-heal an upstream bug in nuttx/tools/build.sh
#
# build_board_cmake() computes the defconfig path with:
#   valid_defconfig_path=$(echo ${defconfig_path} | sed 's/^.\{3\}//')
# i.e. it blindly strips the first 3 characters, assuming the config path
# starts with "../". We pass the documented vendor-relative form
# "vendor/...", so "ven" is chopped off and grep fails with:
#   grep: dor/espressif/.../defconfig: No such file or directory
# It is harmless (only the GHS/Tasking toolchain probe is skipped) but noisy.
# Strip a leading "../" only when present. This is a no-op if the file is
# already fixed or if upstream changes, and lives here so the fix survives a
# `repo sync` (nuttx is a separate repo).
#-----------------------------------------------------------------------------

patch_build_sh() {
  local f="$ROOT/nuttx/tools/build.sh"
  [ -f "$f" ] || return 0
  command -v python3 >/dev/null 2>&1 || return 0

  python3 - "$f" <<'PY'
import sys

path = sys.argv[1]
buggy = "valid_defconfig_path=$(echo ${defconfig_path} | sed 's/^.\{3\}//')"
fixed = "valid_defconfig_path=${defconfig_path#../}"
try:
    with open(path, encoding="utf-8") as fp:
        src = fp.read()
except OSError:
    sys.exit(0)
if buggy in src:
    with open(path, "w", encoding="utf-8") as fp:
        fp.write(src.replace(buggy, fixed))
    print("=== fixed nuttx/tools/build.sh: strip leading '../' only ===")
PY
}

patch_build_sh

#-----------------------------------------------------------------------------
# Board configuration
#-----------------------------------------------------------------------------

CONFIG_PATH="vendor/espressif/boards/esp32p4/esp32p4-function-ev-board/configs/nsh"

echo "=== Building ESP32-P4 (CMake, NSH + display + touch) ==="
./build.sh "$CONFIG_PATH" --cmake -j$(nproc) "$@"

echo
echo "=== Build complete ==="
echo "  Firmware: $ROOT/cmake_out/esp32p4-function-ev-board_nsh/nuttx.bin"
echo "  Flash:    $SCRIPT_DIR/flash_esp32p4.sh [serial-port]"
