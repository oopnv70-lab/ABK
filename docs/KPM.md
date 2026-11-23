# KPM 实现要点与踩坑记录

> 对应版本：v1.1（run 45097251325，产物 PKG110-builtin-kpm-AnyKernel3-13.zip）

## 一、核心结论：CONFIG_KPM=y ≠ KPM 可用

Nova 的 `kernel/extension/kpm.c`：

```c
int ksu_extension_kpm_get(u32 id, u64 *value)
{
#ifdef CONFIG_KPM
    *value = sukisu_kpm_bridge(SUKISU_KPM_PROBE, 0, 0, 0, 0) == SUKISU_KPM_ABI_VERSION;
#else
    *value = 0;
#endif
}
```

而 `kernel/extension/kpm/kpm.c` 的 `sukisu_kpm_bridge()`：

```c
fn = find_kernel_symbol_exact("__arm64_sys_truncate");
...
regs.regs[0] = SUKISU_KPM_SUPERCALL_MAGIC;
regs.regs[8] = SUKISU_KPM_ABI_VERSION;   /* ABI v2 */
if (fn(&regs) != SUKISU_KPM_ABI_VERSION) return -EOPNOTSUPP;
```

`bridge.h` 注释：`ABI v2, mirrored in KernelPatch patch/sukisu/supercall.h`。

⇒ **KSU 只提供通道，执行体是 KernelPatch。** 没有 KP 时 `__arm64_sys_truncate` 只是一次普通系统调用，返回不了 ABI 版本 → `-EOPNOTSUPP` → 管理器显示「不支持 KPM」（issue #758 官方回复同样是 "you didn't patch the kernel manually"）。

## 二、必须做的一步：kptools 注入 kpimg

官方 `SukiSU-Nova/SukiSU_patch/kpm/` 提供预编译 `kptools-linux` + `kpimg`（另有 android 版）。

```
./kptools-linux -p -i Image -k kpimg -o Image.kp -s <random-hex>
```

- `-p` 不接受原地 patch，**必须显式给 `-o`**；不给会报 `patch.c:995/patch_update_img(); empty out image path`，且这个参数没写在 `-h` 用法里。
- `-s` 是 superkey，随机生成即可；KSU 的 KPM 走 magic 分派，一般用不到它。
- 注入后 Image 增大（本机 +296,048 B）。

## 三、校验判据（踩过两个坑）

| 判据 | 是否可用 | 原因 |
|---|---|---|
| `out/.../extension/kpm/kpm.o` 存在 | ❌ | builtin 是 unity build，`ksu_main.c` 直接 `#include` 那些 `.c`，根本没有独立 `.o` |
| `sukisu_compact_find_symbol` 符号 | ❌ | `KSU_CAN_USE_KPM` 按 `LINUX_VERSION_CODE>=4.4` 定义，与 `CONFIG_KPM` 无关，开关两边都在 |
| `KPM is built in` / `KPM is *not* built in` 互斥字符串 | ✅ | 由 `#ifdef CONFIG_KPM` 直接决定，双向可验 |
| kpimg 魔数 `KP1158` 出现在 Image | ✅ | 证明 kpimg 真被追加 |
| `kptools -l -i` 列出 patch 信息 / `patched=true` | ✅ | 证明启动入口已改 |

## 四、其他事实

- `config KPM` 依赖 `KSU && 64BIT`，并 `select KALLSYMS` + `select KALLSYMS_ALL`；**本机 stock config 本来就 `KALLSYMS_ALL=y`**，所以这项与 stock 同侧，不是新增风险。
- kCFI：`sukisu_kpm_bridge` 用 `__nocfi`，并按 `__arm64_sys_truncate.cfi_jt` → `.cfi` 依次回退取符号，GKI 的 `CONFIG_CFI_CLANG=y` 已被考虑。
- `kptools-linux` 是 x86-64 静态二进制，用了较高指令集，本地 arm64 proot 跑会 `Illegal instruction`；只能在 CI runner 上跑。

## 五、已知风险（未排除）

SukiSU-Nova issue #362：GKI 6.1 设备 patch 后出现

```
KP: Oops: Fatal exception: comm:socket_server
PC: __sock_create+0x178/0x328
```

多机复现（Pixel 6 / Android 14 GKI、三星、realme 5.10 等），至今未见明确修复。本机 Ace5 / 6.1.141 暂未出现。若出现异常，回刷 v1.0（无 KPM）或原厂 boot。

## 六、刷入方式更正

**TWRP 不可用**（用户实测），只能通过 SukiSU Nova 管理器刷 AnyKernel3 zip。
