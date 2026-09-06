# ISSUE-002：/dev/fb0 不出现（板级初始化未执行）

- 日期：2026-09-06
- 状态：已解决
- 影响阶段：显示适配（第二阶段）

## 1. 现象

启用显示的固件编译烧录成功，NSH 正常启动，但：

- `ls /dev` 中**没有 `fb0`**（只有 console/kmsg/null/random/ttyACM0/zero）；
- `dmesg`（ramlog）完全为空——说明板级 bringup 的日志从未产生，DSI 初始化从未运行。

## 2. 排查过程

1. **核对配置**：`.config` 中 `CONFIG_ESP32P4_MIPI_DSI=y`、`CONFIG_DRIVERS_VIDEO=y`、`CONFIG_VIDEO_FB=y` 全部生效 → 配置层面没问题；
2. **核对编译产物**：构建目录中 `esp_mipi_dsi.c.o`、`esp32p4_fb0_stub.c.o` 都存在，`libboard.a` 里 `board_fb_initialize` 有定义 → 源码被编译了；
3. **核对最终链接**（关键步骤）：在 `nuttx.map` 中搜索符号，发现 `board_app_initialize` 被链接，但其调用的 `esp_bringup`、`esp_mipi_dsi_initialize`、`board_fb_initialize` **完全不在映射文件里** → `--gc-sections` 把整个调用树裁掉了，因为没人调用它们；
4. **顺藤摸瓜读源码**：
   - 树内板级的 `esp32p4_appinit.c` 中 `board_app_initialize()` 是**空实现**（`return OK`）——NSH 的 `BOARDIOC_INIT` 路径（`CONFIG_NSH_ARCHINIT`）走的就是这个空壳；
   - 真正的外设初始化在 `esp32p4_boot.c` 的 `board_late_initialize()` → `esp_bringup()`，而 `board_late_initialize()` 只有在 **`CONFIG_BOARD_LATE_INITIALIZE=y`** 时才会被内核调用——我们的 defconfig 恰好没有这一项。

## 3. 根因

板级初始化有两条路径：NSH 应用层的 `board_app_initialize()`（树内实现为空壳）与内核的 `board_late_initialize()`（真正的 bringup 入口）。缺少 `CONFIG_BOARD_LATE_INITIALIZE=y` 导致后者从未执行，显示（及所有板级外设）初始化全部被跳过。

## 4. 解决

defconfig 增加：

```
CONFIG_BOARD_LATE_INITIALIZE=y
```

保留 `CONFIG_NSH_ARCHINIT=y`（走空壳无副作用，与 openvela 其他 vendor 板配置习惯一致）。重建后链接图中 `esp_bringup` 正常出现，dmesg 打出完整 DSI 初始化日志，`/dev/fb0` 注册成功。

## 5. 预防

- 新板适配时，先确认板级初始化的真实入口（`board_late_initialize` vs `board_app_initialize`），再决定 defconfig 的初始化开关；
- **用 `nuttx.map` 验证关键调用链是否真的被链接**：编译进了 `.o` ≠ 链接进了固件（`--gc-sections` 会裁掉无人引用的段）；
- 空的 `dmesg` 本身就是信号：板级 bringup 若正常运行，至少应有初始化日志。
