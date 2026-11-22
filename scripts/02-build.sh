#!/usr/bin/env bash
# 02-build.sh — 用 Kleaf 构建 GKI aarch64 内核
# 产物：$KB_DIST/{Image, Image.lz4, System.map, Module.symvers, ...}
set -u
source "$(dirname "$0")/00-env.sh"

LOG=$(kb_logname build)
mkdir -p "$KB_DIST" "$KB_OUT" "$KB_LOGS"

# 额外参数透传：例如 bash 02-build.sh -- --sandbox_debug --spawn_strategy=local
EXTRA_ARGS=("$@")

cd "$KB_SRC" || exit 1
[ -d common ] || { echo "FATAL: $KB_SRC/common 不存在，先跑 01-sync.sh"; exit 1; }

{
  kb_stamp
  echo "== target: $KB_TARGET"
  echo "== extra bazel args: ${EXTRA_ARGS[*]:-<none>}"
  echo "== build start $(date -u +%FT%TZ)"
  echo
} | tee -a "$LOG"

# 内存是硬约束：显式传 --jobs，别依赖自动探测（proot 下 nproc 会报 8）
START=$(date +%s)
tools/bazel run "$KB_TARGET" -- \
    --jobs="$KB_JOBS" \
    --destdir="$KB_DIST" \
    ${EXTRA_ARGS[@]:-} 2>&1 | tee -a "$LOG"
rc=${PIPESTATUS[0]}
END=$(date +%s)

{
  echo
  echo "== build end rc=$rc elapsed=$((END-START))s"
  ls -lh "$KB_DIST" 2>/dev/null
  df -h / | tail -1
} | tee -a "$LOG"

echo "log: $LOG"
exit "$rc"