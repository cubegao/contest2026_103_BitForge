# ISSUE-003：defconfig 修改不生效（构建 3 秒结束）

- 日期：2026-09-06
- 状态：已解决（流程规避）
- 影响阶段：全程

## 1. 现象

向 defconfig 增加 `CONFIG_NSH_ARCHINIT=y` 后重新执行 `./build_esp32p4.sh`：

- 构建仅 **3 秒**结束，产物几乎没有变化；
- 烧录后行为与修改前完全一致（`/dev/fb0` 依然缺失）；
- 检查 `cmake_out/.../.config`，发现新选项**根本不在里面**。

## 2. 排查过程

1. 对比构建耗时：正常全量构建约 80–120 秒，本次仅 3 秒 → 大部分目标被跳过；
2. 检查 `cmake_out/.../build.ninja` 的时间戳与规则：配置未重新生成；
3. 确认 CMake 构建的特点：`.config` 在 **cmake configure 阶段**由 defconfig 展开生成；Ninja 只比较源文件与产物的时间戳，**不知道 defconfig 变了**，因此不会主动触发重新 configure。

## 3. 根因

CMake 增量构建不会感知 defconfig 变化。Make 路径有 `configure.sh -e` 的"配置变更即 distclean"逻辑，CMake 路径的等价保护没有覆盖到这个场景。

## 4. 解决（流程性）

凡是修改了以下任何一项，**必须删除构建目录后全量重建**：

```bash
rm -rf cmake_out/esp32p4-function-ev-board_nsh
./build_esp32p4.sh
```

适用范围：

- defconfig（板级配置）；
- esp-hal-3rdparty 的头文件（尤其 `nuttx/esp32p4/include/sdkconfig.h`——HAL 头会被大量源文件预编译缓存引用）；
- 链接脚本与构建接线（Kconfig / Make.defs / CMakeLists）。

## 5. 预防

- 把"改配置 = 全量重建"写入团队构建纪律（README 的构建章节）；
- 快速自检方法：构建后 `grep <新选项> cmake_out/.../.config` 确认生效，构建耗时异常短（秒级）即说明没有真正重新配置；
- 全量重建代价可控（约 1.5 分钟，ccache 命中后更快），不要为省这点时间引入"改了配置但没生效"的排查成本。
