# ISSUE-004：USB 串口抓不到输出（DTR 与重枚举）

- 日期：2026-09-06
- 状态：已解决（工具化）
- 影响阶段：全程调试

## 1. 现象

两个相关但不同的现象：

1. **`cat /dev/ttyACM0` 完全没有输出**，但 minicom 里有；
2. **烧录后立即读串口失败**：`/dev/ttyACM0` 时有时无，读一半报 `device disconnected`，设备号从 059 涨到 061。

## 2. 根因

### 2.1 DTR 门控

ESP32-P4 的 USB-Serial-JTAG 外设只有在**主机拉高 DTR** 时才把固件输出转发给主机；DTR 未拉高期间固件写入的数据直接丢弃。因此：

- `cat /dev/ttyACM0`（不控制 DTR）→ 永远无输出；
- 烧录完成后（esptool 已退出，DTR 释放）再打开端口 → **boot 阶段的输出已经丢掉了**。

### 2.2 复位引发重枚举

烧录结束的 hard-reset、以及后续任何复位都会让 USB-Serial-JTAG 重新枚举：

- 已打开的串口句柄失效（读报错、设备节点消失再现）；
- 设备号递增；
- 早期 boot 输出必然丢失（枚举完成前固件已经在打印）。

## 3. 解决方案

调试/验证统一使用带重连逻辑的脚本（项目内约定 `nsh_check` 类脚本），要点：

```python
port = serial.Serial("/dev/ttyACM0", 115200, timeout=0.5)
port.dtr = True      # 必须：USJ 输出门控
port.rts = False
# 读循环中捕获异常：设备消失时等待 /dev/ttyACM0 重新出现后重开，
# 持续采集跨多次枚举的输出；周期性发送 "\r\n"/"help" 探测 NSH 存活
```

工程约束：

- **设备定位按 VID/PID（`303a:1001`）而不是写死 ttyACM0**（设备号会漂移）；
- 需要抓 boot 日志时：先打开端口拉高 DTR，再触发复位（esptool `--after hard-reset` 或 RTS 脉冲），接受第一段输出丢失、以 ramlog 兜底——`dmesg`（CONFIG_RAMLOG_SYSLOG）能取回 boot 阶段的 syslog；
- 交互调试用 `minicom -D /dev/ttyACM0`（自带 DTR 控制）。

## 4. 预防

- 团队内统一使用带重连的采集脚本，禁止依赖 `cat`；
- 验证类脚本遵循 ADR-0005 的验证命令序列（uname → ps → mount procfs → free → dmesg）。
