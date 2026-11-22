# 可开机基线（GKI + KSU 内置 + SUSFS）

首个**开机正常 + WiFi 正常**的自编译内置内核基线。

- 提交：`6ba34fd`
- Run：`45071825039`（success）
- 产物：`PKG110-builtin-AnyKernel3-9.zip`
- 设备验证：GKI 模式，能开机，WiFi 恢复（用户实测）

## 本次修复的三个真实根因

### 1. 无限重启：`test_task_ux` 重复导出
一加 6.1.141 的 `block/blk-mq.c` 多一行 `EXPORT_SYMBOL_GPL(test_task_ux)`，
vendor 模块自带同名导出 → `__ksymtab` 撞名 → 模块被拒 → 卡第一屏。
只删导出行，不动函数本体。校验：`nm vmlinux | grep __ksymtab_test_task_ux` 必须为空。

### 2. WiFi/蓝牙全挂：GKI 模块签名保护
`kernel/module/main.c:1281` 对「未签名模块导出受保护符号」直接 `return -EACCES`，
受保护列表来自 `android/abi_gki_protected_exports_aarch64`（第 246 行 `rfkill_alloc`）。
自编译内核拿不到官方签名私钥 → stock 的 `rfkill.ko` `sig_ok=0` → 被拒
→ `cfg80211.ko` → `qca_cld3_kiwi_v2.ko` 依赖链断裂 → 能开机但没有 `wlan0`。

**修法**：构建前把该列表改名禁用（`*.disabled`）。
`gen_gki_modules_headers.sh` 有 `-z` 分支，生成空数组后
`NR_PROTECTED_EXPORTS_SYMBOLS=0`，检查恒为 `false`。不改任何源码内容。
校验：`out/include/generated/gki_module_protected_exports.h` 条目数必须为 0。

### 3. release 门禁过度严格（自造障碍）
实测：vendor 模块 vermagic = `6.1.141-android14-11-o-g9005f72316d1`，
内核 UTS_RELEASE = `6.1.141-android14-11-o-g984c12362a16`，**两者不同但模块正常加载**。
说明 Android KMI 只比对到 `6.1.141-android14-11`，git sha 段不参与。
原「逐字节等于 stock」的门禁白拦了两轮构建，已改为 KMI 前缀比对。

## 已撤回的错误结论（别再重犯）
- HMBIRD / 风驰内核缺失（sm8650 树里 code search 为 0，跨型号类推无效）
- `CONFIG_KALLSYMS_ALL`（我自己加的，无依据，已删）
- vermagic sha 必须一致（实测反证）

## 仍存在的已知隐患
1. `.config` 的 `CONFIG_LOCALVERSION` 与 `setlocalversion` 双写同一后缀，属维护地雷。
2. 未用 bazel + 厂商配置层（裸 `gki_defconfig`），除 WiFi 外其它功能未逐一验证。
3. 未打厂商 ABI 符号白名单，`TRIM_UNUSED_KSYMS` 语义与官方不同（当前未开启裁剪，暂无影响）。
4. `STOCK_LOCALVERSION` 仍为硬编码常量，系统升级后需同步。
