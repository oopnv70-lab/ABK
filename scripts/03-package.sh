#!/usr/bin/env bash
# 03-package.sh — 把 dist/Image 打成可刷的 boot.img
# 状态：骨架，未完成。缺的两件事在下方 TODO 里写清楚了，不要凭记忆填。
set -u
source "$(dirname "$0")/00-env.sh"

LOG=$(kb_logname package)
{
  kb_stamp
  echo "== package start"
} | tee -a "$LOG"

IMAGE="$KB_DIST/Image"
[ -f "$IMAGE" ] || { echo "FATAL: 没有 $IMAGE，先跑 02-build.sh"; exit 1; }

# TODO(1) 需要原厂 boot.img 的头部参数：kernel offset / ramdisk offset / cmdline / header version
#         来源：artifacts/ 里的原厂 boot.img，用 tools/mkbootimg/unpack_bootimg.py 解出来，
#         把结果落到 configs/boot-header.json，脚本从这里读，不允许手抄。
# TODO(2) 需要确认本机是否存在 init_boot 分区（Android 13+ 通常 boot.img 不含 ramdisk，
#         ramdisk 在 init_boot.img）。用 `ls /dev/block/by-name/ | grep -i boot` 核对后再决定包结构。

echo "== 未完成：boot.img 打包需要原厂 boot header 参数与分区布局确认" | tee -a "$LOG"
echo "== 已完成可用产物："
ls -lh "$KB_DIST" 2>/dev/null | tee -a "$LOG"
exit 0