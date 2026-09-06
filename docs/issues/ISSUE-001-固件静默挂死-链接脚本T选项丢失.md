# ISSUE-001：固件静默挂死（串口无任何输出）

- 日期：2026-09-06
- 状态：已解决
- 影响阶段：最小 NSH 启动（第一阶段）

## 1. 现象

固件编译、生成镜像、烧录全部成功，但真机上电后：

- USB 枚举正常（`lsusb` 显示 `303a:1001 Espressif USB JTAG/serial debug unit`），且设备号**稳定不变**（无重启循环）；
- 串口（DTR 已拉高）**完全没有输出**，发送 `help` 无响应；
- 连 boot 早期的日志都没有。

## 2. 排查过程

1. **确认芯片存活**：`esptool chip-id` 能读到 MAC（`e8:f6:0a:e3:a6:89`），复位正常 → 芯片本身没坏；
2. **确认不是控制台问题**：检查 `.config`（`CONFIG_ESPRESSIF_USBSERIAL=y`、UART0 已关）与芯片层 `esp_lowputc.c` 的 USJ 输出路径，接线存在；
3. **隔离 PSRAM**：去掉 `CONFIG_ESPRESSIF_SPIRAM` 重新构建烧录，现象不变 → 排除 PSRAM 初始化崩溃；
4. **确认不是死循环重启**：连续观察 `lsusb` 设备号 12 秒无变化 → 芯片处于稳定状态（挂死而非崩溃循环）；
5. **检查链接产物**：ELF 程序头显示内存布局正确（0x40000000/0x4ff40000），一度排除链接问题；
6. **回到构建日志找线索**：注意到链接阶段有一条曾被忽略的警告——

   ```
   ld: warning: .../esp32p4_sections.rev3.ld.tmp contains output sections; did you forget -T?
   ```

7. **核对实际链接命令**（`build.ninja` 的 `LINK_FLAGS`）：13 个链接脚本前**只有 1 个 `-T`**，其余 12 个以裸路径出现——被 ld 当作普通输入文件；
8. **最小工程复现**：用仓库自带的 CMake 写了一个三行测试工程，确认 `target_link_options(t PRIVATE -T /a.ld -T /b.ld -T /c.ld)` 生成的 `LINK_FLAGS` 是 `-T /a.ld /b.ld /c.ld`——**CMake 会对重复的选项标志去重**（3.23 与 3.31 行为一致）。

## 3. 根因

ESP32-P4 链接需要一组链接脚本（ROM 函数表 ×8、peripherals、aliases、flat_memory、sections.rev3）。构建脚本把"选项 + 脚本路径"交给 CMake 的 `target_link_options()` 后，CMake 把重复的 `-T` 去重成一个，导致除第一个脚本外全部被 ld 当作输入文件；这些脚本的段布局没有被正确应用，ROM 加载后无法启动——而此时 ELF 看起来一切正常（内存布局由第一个 `-T` 脚本和 MEMORY 描述部分补救），极难察觉。

## 4. 解决

顶层 `CMakeLists.txt` 的多脚本组装处，为**每一个**预处理后的脚本显式拼接 `-T`（对齐上游写法，去掉可变选项标志）：

```cmake
list(APPEND ldscript_tmp_list -T ${LD_SCRIPT_TMP})
```

修复后固件正常启动到 NSH（`nsh>` 提示符、`uname`/`ps` 交互正常）。

## 5. 预防

- **链接器警告必须当错误对待**：`did you forget -T?` 是本问题唯一的显性线索；
- 涉及多链接脚本的构建变更，用 `grep -c -- '-T ' build.ninja` 核对脚本与选项数量是否匹配；
- nuttx 侧修复 commit：`fix(cmake): pass a -T option for every linker script`。
