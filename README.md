# ESP32-P4-Function-EV-Board openvela 适配

> 2026 首届 openvela AI 硬件开发者大赛 · 队伍 103 BitForge · **新硬件适配赛道**

## 一、作品简介

将大赛官方标注为"**待适配**"的 **ESP32-P4-Function-EV-Board** 从零适配到 openvela
（Apache NuttX RTOS），并完成三个核心外设的驱动与验证：

- **最小 NSH 系统**：双核 RV32IMAC @400MHz，32MB PSRAM（HEX 模式 @200MHz），单根
  USB 线完成烧录与终端交互
- **MIPI-DSI 显示**：7 寸 1024×600 屏（EK79007AD），DW-GDMA 硬件自动重载零中断
  刷帧，`/dev/fb0` 注册
- **GT911 触摸**：I2C 轮询模式（INT 线未接），`/dev/input0` 注册，有效坐标
  实时输出

全部在实体开发板（芯片 rev v3.2）上验证通过。

## 二、选题方向

**新硬件适配**：ESP32-P4 在 openvela 生态中无任何板级支持，芯片层（RISC-V
架构、espressif 共享层、板级代码）与外设驱动（MIPI-DSI 显示、GT911 触摸）均
从零移植。

## 三、目录结构

```text
board/esp32p4-function-ev-board/   # vendor 板级适配层
  └── configs/nsh/defconfig        # 内核配置（NSH + 显示 + 触摸）
build_esp32p4.sh                   # 一键构建（工具链 + HAL pin + CMake）
flash_esp32p4.sh                   # 一键烧录（Simple Boot @0x2000）
docs/                              # 适配文档
  ├── ROADMAP.md                   # 适配路线图（M0–M6 全部完成）
  ├── adr/                         # 架构决策记录（7 篇，英文）
  └── issues/                      # 问题处理记录（5 篇，中文）
```

芯片层与驱动改动不在本仓，按赛规以 PR 形式提交到公共仓
`open-vela/nuttx` 的 `dev-ai-contest-2026` 分支（分支 `feat/openvela-esp32p4`）：
- 芯片层（arch 头文件、芯片层、共享 espressif 层）
- 板级代码（function-ev-board、链接脚本）
- MIPI-DSI 显示驱动（含 DW-GDMA RELOAD 刷新）
- GT911 触摸驱动（轮询工作项 + 确认帧 + ioctl）

## 四、运行方式

### 4.1 环境准备

```bash
# 1. 拉取 openvela 全量工程
#    -u/-m 指向本队 fork：contest2026_103_BitForge 与 nuttx 均按 manifest
#    里的 <extend-project> 从 github.com/cubegao 拉取（nuttx 用
#    feat/openvela-esp32p4 分支，芯片层/板级/驱动改动都在该分支）。
repo init -u https://github.com/cubegao/contest2026_103_BitForge \
    -b dev-ai-contest-2026 -m contest2026_103_BitForge.xml
repo sync -c -j8

# 2. 安装 riscv32-esp-elf 工具链（esp-14.2.0）
#    https://docs.espressif.com/projects/esp-idf/en/latest/esp32p4/get-started/
```

> 待 nuttx 改动合入 `open-vela/nuttx` 的 `dev-ai-contest-2026` 后，删掉
> `contest2026_103_BitForge.xml` 里的 nuttx `<extend-project>` 即可切回上游。

### 4.2 构建

```bash
./build_esp32p4.sh
# 产物：cmake_out/esp32p4-function-ev-board_nsh/nuttx.bin
```

### 4.3 烧录

```bash
./flash_esp32p4.sh /dev/ttyACM0
# ESP32-P4 ROM boot offset 为 0x2000（区别于 C3/C6/H2 的 0x0）
```

### 4.4 串口终端

```bash
minicom -D /dev/ttyACM0
# USB CDC 需要 DTR；cat /dev/ttyACM0 不可用
```

### 4.5 验证命令

```
nsh> uname -a          # NuttX ... risc-v esp32p4-function-ev-board
nsh> mount -t procfs /proc
nsh> free              # 34MB 堆（768KB SRAM + 32MB PSRAM）
nsh> ls /dev           # console fb0 input0 ttyACM0 ...
nsh> dmesg             # 启动日志（DSI PLL、framebuffer、触摸）
```

## 五、验证结果

以下均在实体开发板（芯片 rev v3.2）上验证：

| 项目 | 结果 |
|------|------|
| 最小 NSH | `nsh>` 提示符正常，`uname` / `ps` 交互正常 |
| 内存 | 34,004,200 字节总堆（768KB SRAM + 32MB PSRAM @200MHz HEX） |
| 显示 | `/dev/fb0`（1024×600 RGB565 单缓冲，DMA RELOAD 硬件自动重载连续刷新） |
| 触摸 | `/dev/input0` 有效样本（npoints=1，flags=TOUCH_DOWN，坐标实时变化） |
| 控制台 | 单根 USB 线完成烧录 + 终端 |

## 六、文档索引

- **适配路线图**：[docs/ROADMAP.md](docs/ROADMAP.md)（M0–M6 全部完成）
- **架构决策记录**：[docs/adr/](docs/adr/)（7 篇，英文）
  - ADR-0001 芯片层移植 → ADR-0007 GT911 触摸驱动
- **问题处理记录**：[docs/issues/](docs/issues/)（5 篇，中文）
  - ISSUE-001 链接脚本 `-T` 丢失 → ISSUE-005 触摸确认帧与轮询架构
