**SukiSU Nova · Built-in** ｜ **OnePlus Ace5 (PKG110)** ｜ **ColorOS 16.0.9.400(CN01) · Android 16** ｜ **GKI 6.1.141-android14-11**

> **AI 声明**：本仓库的构建流程、脚本、文档与验证工作均由 AI（Operit）参与完成，关键结论均经真机实测；刷机存在风险，请自行判断并自负后果。

---

面向 **一加 Ace5 (PKG110)** 的自编译 GKI 内核。内核内置 SukiSU Nova（Built-in，非 LKM 外挂），集成 SUSFS 与 KernelPatch KPM 运行时，全部产物由 GitHub Actions 从 OnePlusOSS 开源源码构建。

## 下载

| 版本 | 包含 | 说明 |
| --- | --- | --- |
| **[v1.1](../../releases/tag/v1.1)** | Nova + SUSFS + KPM | 需要 KPM 模块选这个 |
| [v1.0](../../releases/tag/v1.0) | Nova + SUSFS | 稳定基线，不含 KPM |

Release 附件就是可刷入的 AnyKernel3 包本体：**不需要解压，也不要去 Actions 下载 artifact**（artifact 是外层再套一层 zip）。

## 特性

| 项目 | 状态 |
| --- | --- |
| SukiSU Nova | ✅ 内核内置 |
| SUSFS | ✅ v2.4.0 |
| KPM | ✅ KernelPatch 已注入（仅 v1.1） |
| BBG 防格机（Baseband-guard） | 🔄 已集成，待实机验证 |
| ZRAM 增强 | ❌ 未启用 |

## 版本怎么选

- 只要 root + 隐藏，选 **v1.0**（不开 KPM，更少变数）
- 要用 `.kpm` 模块，选 **v1.1**

## 刷入

1. 只用 **SukiSU Nova 管理器** 刷入本 zip（AnyKernel3，自动选 slot，不改 ramdisk）
2. **TWRP 不可用**（本机实测），不要尝试
3. 刷前备份一份 boot；异常时回刷 v1.0 或原厂 boot

## 风险

- **仅适配一加 Ace5**，其它机型勿刷
- 主要风险是无限重启 / 卡第一屏
- KPM 有已知内核态崩溃案例（SukiSU-Nova issue #362，`__sock_create` Oops），本机未复现但**未排除**
- 第三方 `.kpm` 模块能任意修改内核，只装可信来源
- 相机 / 指纹 / NFC / 音频 / 充电 / 5G 未逐一验证（裸 `gki_defconfig`，未叠厂商配置层）

## 构建

workflow：`.github/workflows/build-builtin.yml`，仅 `workflow_dispatch` 手动触发（push 不消耗额度）。

| input | 默认 | 作用 |
| --- | --- | --- |
| `ksu_ref` | builtin | SukiSU Nova 分支 |
| `enable_susfs` | true | 打 SUSFS 补丁 |
| `enable_kpm` | false | 开 CONFIG_KPM 并注入 KernelPatch |
| `enable_bbg` | true | 集成 Baseband-guard 防格机 LSM（源码构建时按 pin 拉取，不入库） |

单轮耗时 18–60 分钟，主要取决于 `repo sync`。

## 文档

- `docs/BASELINE.md` — 当前稳定基线与验证项
- `docs/KPM.md` — KPM 实现机制与踩坑记录

## 许可证

本仓库脚本与文档：**GPL-2.0**（见 [LICENSE](LICENSE)）。

内核本体 GPL-2.0-only；SukiSU-Nova（builtin 分支）GPL-2.0；KernelPatch GPL-2.0；Baseband-guard GPL-2.0；susfs4ksu 仓库未附 LICENSE；AnyKernel3 为 BSD-3-Clause 风格。

逐项说明见 **[NOTICE.md](NOTICE.md)**。

> **许可声明随产物分发**：每个刷机包 zip 内都带 `THIRD-PARTY-NOTICES.md`、`LICENSES/`（含 Baseband-guard 许可原文）与 `SOURCE.md`（逐项 pin 的对应源码指引）。GPL 的义务跟着二进制走，不能只挂在仓库里。

## 致谢

SukiSU-Nova / KernelSU、susfs4ksu（simonpunk）、AnyKernel3（osm0sis）、KernelPatch（bmax121）、Baseband-guard（vc-teahouse / 秋刀鱼）、OnePlusOSS 内核源码。
