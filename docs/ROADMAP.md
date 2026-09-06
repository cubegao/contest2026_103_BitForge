# ROADMAP：ESP32-P4-Function-EV-Board openvela 适配

> 目标：在 ESP32-P4-Function-EV-Board（双核 RV32IMAC @400MHz，32MB PSRAM，16MB flash，MIPI-DSI 1024×600 屏）上完成 openvela 适配，先建立最小 NSH 系统，再打通屏幕显示。
>
> 本文档是适配路线图。每一步的设计决策记录在 [`adr/`](./adr/)，过程中遇到的问题与处理过程记录在 [`issues/`](./issues/)。

## 一、总体路线

| 阶段 | 内容 | 状态 | 设计记录 | 相关问题记录 |
|------|------|------|----------|--------------|
| M0 | 芯片层移植（arch 头文件 / 芯片层 / 共享 espressif 层 / 构建工具 / 内核修正） | ✅ 完成 | [ADR-0001](./adr/ADR-0001.md) | — |
| M1 | 板级层移植（common / function-ev-board / 链接脚本） | ✅ 完成 | [ADR-0002](./adr/ADR-0002.md) | — |
| M2 | esp-hal-3rdparty 依赖接入与 P4 适配 | ✅ 完成 | [ADR-0003](./adr/ADR-0003.md) | — |
| M3 | vendor 适配层 + 最小 NSH 配置 | ✅ 完成 | [ADR-0004](./adr/ADR-0004.md) | [ISSUE-001](./issues/ISSUE-001-固件静默挂死-链接脚本T选项丢失.md)、[ISSUE-003](./issues/ISSUE-003-defconfig修改不生效-需全量重建.md) |
| M4 | 构建、镜像与烧录流程固化 | ✅ 完成 | [ADR-0005](./adr/ADR-0005.md) | [ISSUE-004](./issues/ISSUE-004-USB串口抓取-DTR门控与重枚举.md) |
| M5 | MIPI-DSI 显示适配（/dev/fb0 + 上电自检） | ✅ 完成 | [ADR-0006](./adr/ADR-0006.md) | [ISSUE-002](./issues/ISSUE-002-fb0未注册-板级初始化路径错误.md) |
| M6 | 触摸（GT911）+ LVGL 图形栈 | 规划中 | — | — |
| M7 | 摄像头（MIPI-CSI）/ 以太网等外设扩展 | 规划中 | — | — |

## 二、当前已达成的验证基线

以下结果均在真实硬件上验证（芯片版本 v3.2）：

| 项目 | 结果 |
|------|------|
| 最小 NSH | `nsh>` 提示符正常，`uname` / `ps` 交互正常 |
| 内存 | `free` 显示 34,004,200 字节总堆（768KB SRAM + 32MB PSRAM @200MHz HEX） |
| 显示 | `/dev/fb0` 注册（1024×600 RGB565，双缓冲，fblen=2457600）；DSI PHY PLL 锁定；DMA 链表刷新运行；上电自检画面（红 / 红蓝交替） |
| 控制台 | 单根 USB 线完成烧录 + 终端（USB CDC，见 ADR-0004 defconfig） |

## 三、代码落位

| 仓库 | 分支 | 内容 |
|------|------|------|
| `nuttx`（fork） | `feat/openvela-esp32p4` | 芯片层、共享层、板级层、显示驱动、构建修复（commit 序列见各 ADR 的"产物"小节） |
| `esp-hal-3rdparty`（fork） | `feat/openvela-esp32p4` | P4 HAL 适配，版本 pin 于 `a498192b2c…` |
| 专属仓（本仓） | `dev-ai-contest-2026` | `board/esp32p4-function-ev-board/`（defconfig、Make.defs）、`build_esp32p4.sh`、`docs/` |

## 四、文档索引

- **架构决策记录（适配流程）**：[`adr/`](./adr/)
  - [ADR-0001](./adr/ADR-0001.md) ESP32-P4 芯片层移植
  - [ADR-0002](./adr/ADR-0002.md) 板级层移植
  - [ADR-0003](./adr/ADR-0003.md) esp-hal-3rdparty 依赖接入与适配
  - [ADR-0004](./adr/ADR-0004.md) vendor 适配层与最小 NSH 配置
  - [ADR-0005](./adr/ADR-0005.md) 构建、镜像与烧录流程
  - [ADR-0006](./adr/ADR-0006.md) MIPI-DSI 显示适配
- **问题处理记录**：[`issues/`](./issues/)
  - [ISSUE-001](./issues/ISSUE-001-固件静默挂死-链接脚本T选项丢失.md) 固件静默挂死——链接脚本 `-T` 选项丢失
  - [ISSUE-002](./issues/ISSUE-002-fb0未注册-板级初始化路径错误.md) /dev/fb0 不出现——板级初始化路径错误
  - [ISSUE-003](./issues/ISSUE-003-defconfig修改不生效-需全量重建.md) defconfig 修改不生效——需全量重建
  - [ISSUE-004](./issues/ISSUE-004-USB串口抓取-DTR门控与重枚举.md) USB 串口抓取——DTR 门控与重枚举

## 五、工程纪律（踩坑沉淀）

1. defconfig、HAL 头文件、链接脚本任何变更后**必须全量重建**（ISSUE-003）；
2. 链接器警告当错误对待，多链接脚本场景核对 `-T` 数量（ISSUE-001）；
3. 用 `nuttx.map` 验证关键调用链真的被链接（`--gc-sections` 会裁掉无人引用的段，ISSUE-002）；
4. 串口采集必须控制 DTR 并支持跨枚举重连（ISSUE-004）；
5. HAL 版本始终 pin 完整 SHA，禁止浮动分支（ADR-0003）。
