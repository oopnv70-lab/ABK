# 一加内核编译：真实问题与解决思路（查证记录）

> 来源全部为一手信息，不是推测：
> - OnePlusOSS/android_kernel_oneplus_sm7675 **issue #2**（仓库维护者 vvvbbbcz 的回复）
> - OnePlusOSS/android_kernel_oneplus_sm8650 **issue #49**（官方确认 16.0.9.400 源码已更新）
> 抓取时间：2026-11-22

---

## 0. 一个先确认的事实：我们用的源码是对的

issue #49 原文：

> 版本号：PKG110_16.0.9.400
> 内核版本：6.1.141

官方 `OnePlusOSSAdmin` 回复：**「已更新」**（2026-08-18）。

也就是说 `oneplus/sm8650_b_16.0.0_ace_5` 这条分支就是**你这台机器当前系统版本**对应的源码。
分支选择不是猜的。

---

## 1. 核心结论：不能按 AOSP 那套 make + defconfig 编

这是本项目的关键纠正。

**错误做法（会失败）**：
```bash
make LLVM=1 ARCH=arm64 O=out gki_defconfig all
```

**典型报错**（issue #2 原文，sm7675 但机制相同）：
```
ERROR: modpost: "__stack_chk_guard" [arch/arm64/geniezone/gzvm.ko] undefined!
ERROR: modpost: "__stack_chk_guard" [mm/zsmalloc.ko] undefined!
ERROR: modpost: "__stack_chk_guard" [drivers/block/zram/zram.ko] undefined!
... (共 45+ 个模块)
WARNING: modpost: suppressed 35 unresolved symbol warnings because there were too many
make[2]: *** [scripts/Makefile.modpost:186: Module.symvers] Error 1
```

原因不是符号真的缺，而是**一加这种 kernel_platform 布局（common + msm-kernel 分离）用传统 make 走 modpost 时，
模块与 vmlinux 的连接关系没建立对**。换 defconfig 也一样报（提问者已试过 gki_defconfig 和官方提取的 defconfig，都报）。

**同类第二个坑**：DTS 找不到文件
```
fatal error: 'oplus-chg-23814-silicon-1.dtsi' file not found
```
因为 vendor 的 dts 在 `msm-kernel` 树里，传统 make 在 `common` 里编 dtbo 时路径没对上。

---

## 2. 官方维护者给的解决思路（原话）

> 不要使用传统的 gcc 和 clang 编译，按照 Google 的官方文档，用 repo 克隆仓库，
> manifest.xml 从 kernel_manifest 获取，然后按照文档，**用 Bazel 构建**。

具体命令（issue #2 里另一位用成功的人给出）：

```bash
# 内存有限
tools/bazel build --config=fast //common:kernel_aarch64_dist
# 内存充足
tools/bazel build -c opt //common:kernel_aarch64_dist
```

产物位置：

```
kernel_platform/bazel-bin/common/kernel_aarch64_gki_artifacts/
```

里面是 `boot.img` 等 GKI 镜像（Kleaf 的 dist 目标）。

**另一条路（能用但慢，不推荐）**：
```bash
./kernel_platform/oplus/build/oplus_build_kernel.sh pineapple gki
```
原话：「官方脚本编译的不止内核，还有其他的比如 vendor 这些，初次编译特别慢的，没必要用这个」。

`pineapple` = sm8650 平台代号（在 manifest 的 `build.config.msm.pineapple` 里能看到）。

---

## 3. 刷机侧提醒（需实物验证，不要当定论）

issue #2 里成功者的原话：

> 先用 `fastboot boot boot.img` 测试，再刷入。不过，据说一加有限制，
> **要先双清后才能刷内核，不然刷完开机直接进 fastboot**。双清的我没试，一直是 fastboot boot。

**这条已被用户实测否证。** 用户原话：「我刷过 确实不需要双清」。

所以：**一加刷内核不需要双清**，这是本机的一手结论，不再列为待验证项，也不写进任何流程。

issue #2 里那句话本身就是转述「据说」，发言者本人从未做过双清，一直只用 `fastboot boot`。
典型的「一个人没做过、只是听说，被后面所有人当成规则转述」。

真正该核对的是具体机制，而不是双清：
- boot.img 的 header 参数（kernel offset / ramdisk offset / cmdline）是否与原厂一致
- 是否存在 `init_boot` 独立分区（Android 13+ 常见）
- vbmeta / AVB 校验状态、当前 slot 是否匹配
- `fastboot boot` 能起来 → 说明内核本身没问题，问题就在镜像封装或校验

在拿到这些实测数据之前，刷机侧不下任何结论。

---

## 4. 对本项目 workflow 的影响

**必须改**：
- 原来的 `make ... gki_defconfig all` → 改成 `tools/bazel build --config=fast //common:kernel_aarch64_dist`
- 产物路径从 `common/out/arch/arm64/boot/Image` → 改成 `bazel-bin/common/kernel_aarch64_gki_artifacts/`
- 这样编出来的直接就是 **boot.img**，连 mkbootimg 都不用手动做

**保持不变**：
- 用 `OnePlusOSS/kernel_manifest` + `oneplus_ace5_b.xml` 现场 repo sync
- 只编 GKI（`//common:...`），不碰 msm-kernel 的 vendor 部分

---

## 5. 已知会缺的东西（用户已确认接受）

- **风驰游戏内核 / HMBIRD**：一加私有补丁（sched_ext 内联进 `fair.c` 的变体），
  OnePlusOSS 开源树里没有，编出来的 GKI 不含它。
  用户原话：「风驰游戏内核没了就没了吧，反正我们以后再想办法，先弄好再说」。
- 所以产物在调度行为上会与原厂有差异，这属于**预期**，不是故障。