# SukiSU-Nova LKM 接入：官方 CI 的真实做法与本项目落地

> 来源全部是一手代码，不是推测：
> - `SukiSU-Nova/SukiSU-Nova` `.github/workflows/ddk-lkm.yml`（官方 kernelsu.ko 构建）
> - `SukiSU-Nova/SukiSU-Nova` `kernel/Makefile`、`kernel/Kbuild`
> - `OnePlusOSS/android_kernel_oneplus_sm7675` issue #2（一加树构建方式）

---

## 1. 官方 arm64 的 LKM 构建其实只有三行

`ddk-lkm.yml` 里 arm64 分支（和第 9 步无关的部分）核心就这点：

```bash
cd kernel
make CONFIG_KSU=m CONFIG_KPM=y CC=clang
```

`kernel/Makefile` 的 `KDIR := $(KDIR)` 是**完全依赖环境变量**的，也就是说 KDIR
在官方 ddk 镜像里是预先备好的（x86 分支能看到同样套路：`export KDIR=/opt/ddk/kdir-x64/${kmi}`）。

**结论：编 kernelsu.ko 的门槛不在 KSU 本身，在"给它一棵合格的 KDIR"。**

## 2. KDIR 到底需要什么

从 `kernel/Makefile` 与 `kernel/Kbuild` 反推，KDIR 必须具备：

| 需求 | 出处 | 缺了会怎样 |
|---|---|---|
| `vmlinux` | `all` 目标最后一步 `./check_symbol $ODIR/kernelsu.ko $KDIR/vmlinux` | check_symbol 直接失败 |
| `Module.symvers` | Kbuild 的 modpost 阶段 | 全部符号 undefined |
| `.config` | Kbuild | 拿不到 CONFIG_ARM64 等分支开关 |
| `usr/include/linux/unistd.h` | `KSU_UAPI_INC := $(objtree)/usr/include` | `preinit` 被禁用（只是 warning + `-DKSU_NO_PREINIT`，功能缺失） |
| `security/selinux` 生成头 | `-I$(objtree)/security/selinux` | 编译期找不到 selinux 头 |

## 3. KDIR 里的 modpost 补丁——那是 x86 专用，arm64 不需要

`ddk-lkm.yml` 的 x86 分支里有四条 sed：

```bash
MODPOST=scripts/mod/modpost.c
sed -i -E 's/^([[:space:]]*)check_exports\(mod\);/.../' "$MODPOST"
sed -i -E 's/^([[:space:]]*)s->module = exp->module;/.../' "$MODPOST"
sed -i 's/^static void check_exports(/static void __attribute__((unused)) check_exports(/' "$MODPOST"
sed -i 's/__version_ext_names\") =\n/.../' "$MODPOST"
```

注释原文写得很清楚：*"ddk-min images contain the source tarball, whose modpost patch is
not applied to the fresh x86 kdir"* —— 这是给 **x86 新建 kdir** 补的，因为那边没有现成的
完整符号表。

**arm64 分支没有这段。** 说明只要 KDIR 来自一次完整构建，就不需要动 modpost。
本项目也**不打这个补丁**（打补丁等于改一加上游源码，违反项目底线）。

## 4. 这就是 issue #2 里 `__stack_chk_guard` 的真正成因

一加 issue #2 的失败是：

```
ERROR: modpost: "__stack_chk_guard" [mm/zsmalloc.ko] undefined!
make[2]: *** [scripts/Makefile.modpost:186: Module.symvers] Error 1
```

现在可以精确解释了：`make gki_defconfig all` 的 `all` 会**连内核自带的几百个模块一起编**，
modpost 要校验每个 .ko 的未定义符号能否在 Module.symvers 里找到。
`__stack_chk_guard` 由 stack protector 生成、不是 `EXPORT_SYMBOL` 导出的，
于是 GKI 的模块化配置下必然批量报错。

**而 `kernelsu.ko` 只依赖 vmlinux 导出的符号，所以外部模块编译不会撞上这一批。**
两者不是同一回事。

## 5. 本项目的落地方式（build.yml 里的两步）

### 第一步：Kleaf 编内核

```bash
cd kernel_platform
tools/bazel build --config=fast //common:kernel_aarch64_dist
```

一加维护者明确要求这条路（issue #2），产物是 GKI 镜像。

### 第二步：拼一个 KDIR，然后编 kernelsu.ko

```bash
# 1) 用同一棵 common 源码树生成 objtree
make -C common O=$KDIR ARCH=arm64 LLVM=1 gki_defconfig
make -C common O=$KDIR ARCH=arm64 LLVM=1 modules_prepare -j$(nproc)
make -C common O=$KDIR ARCH=arm64 LLVM=1 security/selinux/built-in.a -j$(nproc)

# 2) 关键：vmlinux / Module.symvers 用 Kleaf 那份，
#    保证 kernelsu.ko 依赖的符号与最终刷进机器的内核完全一致
cp bazel-bin/common/kernel_aarch64/{vmlinux,Module.symvers,System.map} $KDIR/

# 3) 编模块
cd sukisu/kernel
make KDIR=$KDIR CONFIG_KSU=m CONFIG_KPM=y CC=clang
```

`make` 不带目标 = 走 `all` = 先编模块再跑 `check_symbol`，
它是官方自带的验收标准：`.ko` 的所有未定义符号必须在 `vmlinux` 里存在且为
GLOBAL/WEAK，且 `__versions` 段必须为 0。

## 6. 已知的不确定点（第一次跑必须看的地方）

这些我没有一手机器验证过，所以 workflow 里全部做成了**探测 + 显式报错**，不静默通过：

1. Kleaf 的 `bazel-bin/common/kernel_aarch64/` 里是否真有 `vmlinux` / `Module.symvers`。
   → `准备 KDIR` 步骤会 `ls` 出来并逐文件告警。
2. `//common:kernel_aarch64_dist` 的 Image 落在
   `kernel_aarch64_gki_artifacts` / `kernel_aarch64_dist` / `out/dist` 哪一个。
   → `定位内核产物` 步骤会把三个候选目录的存在性和内容写进 Step Summary。
3. 一加 manifest 的 bazel prebuilts（来自 codelinaro）在 Actions 上能否直接跑通。
   → 构建日志完整上传，失败按日志定位，不猜。
4. `modules_prepare` 是否生成 `usr/include`（决定 preinit 功能是否启用）。
   → 步骤里打印 `usr/include 存在：yes/no`。

## 7. 为什么不用 `kernel/setup.sh`

它做的是：软链到 `drivers/kernelsu`，向 `drivers/Makefile`、`drivers/Kconfig` 追加条目
——那是 **builtin**，会把 KSU 编进 Image，且**改动内核源码树**，违反项目底线；
它 clone 的源还是第三方镜像 `git.zako.shirkneko.top:20004/shirkneko/SukiSU`。

本项目只用 `kernel/Makefile` 这条纯 LKM 路径，源码树保持原封不动。