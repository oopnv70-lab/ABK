# PKG110-Kernel — 本地构建工作区

OnePlus Ace5 (PKG110 / sm8650) 自编 GKI 内核工作区。
**唯一原则：目录各司其职，产物与源码分离，任何构建都能从日志回溯到源码 commit。**

## 目录职责（不要跨用）

| 目录 | 放什么 | 不放什么 |
|---|---|---|
| `src/ack/` | `repo` 检出的 ACK 源码树（kernel/common + prebuilts） | 手改源码、产物 |
| `ksu/` | SukiSU-Nova 克隆（用于产出 `kernelsu.ko` LKM） | 打进 ACK 树的东西 |
| `patches/` | 待施加的补丁（SUSFS 等），保持上游原样 | 已施加后的副本 |
| `configs/` | defconfig fragment、KMI symbol 快照、设备基线配置 | 构建临时 .config |
| `scripts/` | 唯一入口脚本，编号即执行顺序 | 一次性临时命令 |
| `out/` | Kleaf/Bazel 中间产物（可随时删） | 任何需要长期保留的东西 |
| `dist/` | 最终产物（Image / boot.img / kernelsu.ko） | 中间文件 |
| `logs/build/` | 每次构建的完整日志，文件名带时间戳 | — |
| `artifacts/` | 原厂镜像备份、可开机旧产物（**只进不出**） | 临时文件 |
| `env/` | 环境快照（工具版本、磁盘/内存实况） | 安装脚本 |
| `docs/` | 查证记录：分支矩阵、设备基线、结论与出处 | 猜测 |

## 三条硬规则

1. **不改上游源码。** 需要改动一律走 `patches/`，且补丁必须能独立 `git apply` 验证。
2. **每个产物必须能回答"哪棵树、哪个 commit、哪些补丁"。** 构建脚本会把 commit 写进日志头。
3. **`out/` 可以删，`artifacts/` 不能删。** 唯一验证过能开机的产物是 `artifacts/art6_Image`（md5 `7e1f6069a47b8ac8e9a252957b0cdd74`）。

## 标准流程

```bash
source /root/pkg110-kernel/scripts/00-env.sh   # 载入路径与参数
bash    /root/pkg110-kernel/scripts/01-sync.sh  # 拉/更新源码（可重复执行）
bash    /root/pkg110-kernel/scripts/02-build.sh # Kleaf 构建 → dist/
bash    /root/pkg110-kernel/scripts/03-package.sh # 打包 boot.img（待补全）
```

## 环境实况（2026-11-22 实测，详见 env/）

- Ubuntu 24.04.5 LTS **aarch64**，proot 环境，8 核，MemTotal 15.5 GB / 可用约 4.6 GB
- 磁盘 `/` 219 G，已用 188 G，**可用 32 G** ← 最大风险点，见 `docs/03-risks.md`
- 已装：git 2.43、repo 2.36、bison、flex、bc、cpio、lz4、rsync、zip、pahole 1.25、ccache 4.9
- clang **不预装**，由 ACK 的 `prebuilts/clang/host/linux-x86` 提供（Kleaf 自动使用）