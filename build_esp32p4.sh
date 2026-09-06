#!/bin/bash
# ESP32-P4 Function EV Board build script (openvela port)
#
# Stage 1 target: minimal NSH with the USB CDC-ACM console.

set -e

# Proxy used by the build system when fetching esp-hal-3rdparty.
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=http://127.0.0.1:7890

# Toolchain
export PATH="/home/ekko/.espressif/tools/riscv32-esp-elf/esp-14.2.0_20260121/riscv32-esp-elf/bin:$PATH"

# esp-hal-3rdparty remote dependency (fork carrying the ESP32-P4 fixes)
export ESP_HAL_3RDPARTY_URL="https://github.com/cubegao/esp-hal-3rdparty.git"
export ESP_HAL_3RDPARTY_VERSION="a498192b2c15ad11c048a317c51d04389057bc74"

# Project root
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

# Vendor board configuration (linkfile mapped to
# contest2026_103_BitForge/board/esp32p4-function-ev-board)
CONFIG_PATH="vendor/espressif/boards/esp32p4/esp32p4-function-ev-board/configs/nsh/"

echo "=== Toolchain check ==="
riscv32-esp-elf-gcc --version | head -1

echo "=== Building ESP32-P4 (CMake) ==="
./build.sh "$CONFIG_PATH" --cmake -j$(nproc)
