# ESP32-P4-Function-EV-Board openvela port

Vendor board adaptation layer for the ESP32-P4-Function-EV-Board on
openvela (NuttX based).

## Hardware

| Item   | Description                                   |
|--------|-----------------------------------------------|
| SoC    | ESP32-P4, dual-core RISC-V @ 400MHz           |
| SRAM   | 768KB on-chip                                 |
| PSRAM  | 32MB (hex mode, 200MHz)                       |
| Flash  | 16MB SPI flash                                |
| Console| USB CDC-ACM (native USB peripheral)           |
| Display| MIPI-DSI 1024x600 panel (stage 2 of the port) |

## Directory layout

```
esp32p4-function-ev-board/
├── configs/nsh/defconfig   # minimal NSH configuration
├── scripts/Make.defs       # toolchain / linker script setup for Make builds
└── README.md
```

The board sources (board.h, boot/bringup/reset code, linker scripts)
live in the nuttx repository under `boards/risc-v/esp32p4/`; this
vendor layer carries the build configuration and selects that board
directory through the standard `CONFIG_ARCH_BOARD_CUSTOM` mechanism,
so the stock NuttX board directory stays untouched.

## Build

From the openvela workspace root:

```bash
./build_esp32p4.sh
# or manually:
./build.sh vendor/espressif/boards/esp32p4/esp32p4-function-ev-board/configs/nsh --cmake -j8
```

## Flash and run

```bash
esptool.py --chip esp32p4 elf2image -fs 16MB -fm dio -ff 80m \
    --ram-only-header -o nuttx.bin cmake_out/esp32p4-function-ev-board_nsh/nuttx
esptool.py -c esp32p4 -p /dev/ttyACM0 -b 921600 write-flash 0x2000 nuttx.bin
```

Then open a DTR-capable terminal on `/dev/ttyACM0` (for example
`minicom -D /dev/ttyACM0`); the `nsh>` prompt appears on boot.
