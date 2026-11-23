# 第三方组件与许可证声明

本仓库中由本项目编写的构建脚本与文档，按 **GPL-2.0** 发布，全文见 [LICENSE](LICENSE)。

构建产物（内核镜像与刷机包）内包含的第三方组件，各自许可证如下，分别适用：

| 组件 | 在本项目中的作用 | 许可证 | 上游仓库 |
| --- | --- | --- | --- |
| Linux 内核本体 | 内核镜像基础 | **GPL-2.0-only** | OnePlusOSS 内核源码 |
| SukiSU-Nova（builtin 分支） | root 管理器内核侧代码，内核内置 | **GPL-2.0** | SukiSU-Nova/SukiSU-Nova |
| KernelSU | SukiSU-Nova 的上游项目 | GPL-3.0（本项目未包含其 main 分支代码） | tiann/KernelSU |
| susfs4ksu | SUSFS 内核补丁 | 上游仓库未附 LICENSE 文件；补丁作用于 GPL-2.0-only 内核树 | simonpunk/susfs4ksu |
| KernelPatch | kpimg / kptools，KPM 运行时 | **GPL-2.0** | bmax121/KernelPatch |
| AnyKernel3 | 刷机包脚本与打包模板 | **BSD-3-Clause 风格**，全文见 [LICENSES/AnyKernel3-LICENSE.txt](LICENSES/AnyKernel3-LICENSE.txt) | Osm0sis/AnyKernel3 |

## 说明

1. 本项目内嵌的是 SukiSU-Nova 的 **builtin** 分支，该分支 LICENSE 为 **GPL-2.0**；其 **main** 分支为 GPL-3.0。两者不同，请勿混用。
2. 本仓库**不包含**内核源码镜像，构建时从 OnePlusOSS 源拉取；内核遵循 GPL-2.0-only，不可变更。
3. AnyKernel3 要求二进制再分发时随包保留其 LICENSE：每个刷机包 zip 内均已内含 `LICENSE` 文件。
4. susfs4ksu 上游未提供 LICENSE 文件，此处按其作用对象标注为内核 GPL-2.0-only 的一部分；若上游后续声明变更，以原文为准。
5. 若本文档与任一上游 LICENSE 原文冲突，以原文为准。
