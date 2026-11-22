# 本机构建的风险清单（诚实版）

在手机上用 proot 编译 AArch64 GKI 内核，已知会撞到这些墙。先写下来，避免后面每次都用"再试一次"来消耗时间。

## R1 磁盘 32 G — 高

- ACK 全量 sync（即使 `--depth=1`）预计 8–12 G（clang prebuilt 单仓就有 ~1.5 G 以上）。
- Kleaf/Bazel 的 `out/` 轻松 15–25 G。
- **对策**：先 sync 看实际占用；构建用 `--jobs=4` 减少并行临时文件；`out/` 随时可删；
  必要时把 `out/` 指到 `/sdcard`（但 FUSE 上 bazel 会明显变慢且有权限坑，不作为首选）。

## R2 内存 4.6 G 可用 — 高

- 内核链接阶段（`ld.lld` 链 vmlinux）是内存峰值，`-j8` 大概率 OOM 被系统杀掉。
- **对策**：`KB_JOBS=4` 起步；已装 `ccache`，二次构建能省编译但不省链接内存。

## R3 Bazel 在 proot 下可能需要关 sandbox — 中

- Bazel 默认 sandbox 依赖 user namespace / mount，proot 里常报
  `sandboxing is not supported` 或 `Failed to create user namespace`。
- **对策**：构建失败时先看日志确认，再加 `--sandbox_debug --spawn_strategy=local`；
  这是 Kleaf 官方支持的降级路径，不是 hack。

## R4 通用 GKI 不含厂商私有补丁 — 中，且是已确认事实

- 一加 HMBIRD（私有 sched_ext 内联进 `fair.c` 的变体）不在 OnePlusOSS 开源树，ACK 里也没有。
- 结论：自编 GKI 可以开机、可以挂 LKM 模块，但**调度行为与原厂不同**。
  这不是 bug，不要在开机后拿"性能不如原厂"当故障排查。

## R5 KMI/vendor 模块匹配 — 中

- 刷入自编 GKI 后，`vendor_dlkm` / `vendor_boot` 里的厂商模块是否能加载，取决于 KMI 符号集。
- 校验手段（待做）：对比原厂 `boot.img` 的 `kernel` 与自编 `Image` 的
  `Module.symvers` / `__ksymtab` 导出符号。产物 `dist/` 里会带 `Module.symvers`。

## R6 不要用"查不到"当证据

- 设备侧 KSU 痕迹查不到属于隐藏机制的预期行为，与本机构建无关，别混为一谈。