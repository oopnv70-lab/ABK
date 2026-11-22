# ACK 6.1 分支与版本对照（2026-11-22 实测）

数据来源：`git ls-remote` + `curl .../Makefile?format=TEXT`（android.googlesource.com），非推测。

## kernel/common 分支 HEAD 的 SUBLEVEL

| 分支 | VERSION.PATCHLEVEL.SUBLEVEL | 备注 |
|---|---|---|
| `android14-6.1-lts` | **6.1.192** | 6.1 系列最新 LTS 头 |
| `android14-6.1` | **6.1.177** | 季度分支的汇总头 |
| `android14-6.1-2026-09` | **6.1.176** | |
| `android14-6.1-2026-06` | **6.1.172** | |
| `android14-6.1-2026-03` | **6.1.162** | |
| `android14-6.1-2025-12` | **6.1.157** | |
| `android14-6.1-2025-09` | **6.1.145** | ← **本项目选定基线** |
| 设备原厂内核 | **6.1.141** | `lightweight 6.1.141-android14-11-o-g984c12362a16` |

## 为什么选 `android14-6.1-2025-09`（6.1.145）

1. 设备原厂是 **6.1.141**，低于 2025-09 的 145，高于更早分支。取"设备基线之上最近的季度分支"，
   KMI 符号集与厂商 `vendor_dlkm` 模块的期望最接近。
2. 再往前（更旧的季度分支）会踩到 ASB 缺漏；再往后（2025-12 及以后）会引入设备从未见过的
   KMI 增量，虽然 ACK 保证同代 ABI 稳定，但没必要在第一次跑通前就引入变量。
3. 若后续要升级，只改 `scripts/00-env.sh` 里的 `KB_BRANCH`，不要手改 `.repo/manifest`。

## 对应的 manifest 分支

`kernel/manifest` 里对应分支名带 `common-` 前缀：

```
refs/heads/common-android14-6.1-2025-09   → 03f709c4e1458df41c45254138f05a34eaac8481
refs/heads/common-android14-6.1           → 044de8a1852fcf7cba788c633baf538e440f4f82
```

初始化命令（已执行成功）：

```bash
repo init -u https://android.googlesource.com/kernel/manifest \
          -b common-android14-6.1-2025-09 --depth=1
```

manifest 内共 **17 个 project**，关键项：

- `common` → `kernel/common` @ `android14-6.1-2025-09`
- `prebuilts/clang/host/linux-x86`（clone-depth=1，体积大头）
- `prebuilts/bazel/linux-x86_64`、`prebuilts/jdk/jdk11`（Kleaf 依赖）
- `tools/mkbootimg`（打包 boot.img 用）

## 遗留疑问（未查证完，不要当结论用）

- 原厂 localversion 中的 `android14-11` 段：**不是** AOSP 的 `kernel/common` 分支名
  （`refs/heads/*android14-11*` 在 kernel/common 中不存在），应为 OPPO 自有标记。**待查**。
- 设备 6.1.141 究竟对应哪个 ACK tag（`android14-6.1-2025-xx_rN`）：**待查**，需要时用
  `git log --grep` 在 common 树里比对 `Linux 6.1.141` 提交。