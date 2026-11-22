#!/usr/bin/env bash
# 01-sync.sh — 拉取 / 更新 ACK 源码树
# 幂等：可重复执行；已初始化则只做 repo sync
set -u
source "$(dirname "$0")/00-env.sh"

LOG=$(kb_logname sync)
mkdir -p "$KB_SRC" "$KB_LOGS"

{
  kb_stamp
  echo "== repo sync start"
} | tee -a "$LOG"

cd "$KB_SRC" || exit 1

if [ ! -d .repo ]; then
  echo "[init] manifest=$KB_MANIFEST_URL branch=$KB_MANIFEST_BRANCH" | tee -a "$LOG"
  REPO_URL="$KB_REPO_URL" repo init \
      -u "$KB_MANIFEST_URL" \
      -b "$KB_MANIFEST_BRANCH" \
      --depth=1 \
      --repo-url="$KB_REPO_URL" 2>&1 | tee -a "$LOG"
  [ -d .repo ] || { echo "FATAL: repo init failed" | tee -a "$LOG"; exit 1; }
else
  echo "[init] .repo already exists, skipping init" | tee -a "$LOG"
fi

# 三个重试：网络抖动在手机上很常见，不要因为一次超时就重头开始
rc=1
for attempt in 1 2 3; do
  echo "[sync] attempt $attempt $(date -u +%FT%TZ)" | tee -a "$LOG"
  repo sync -c --no-tags -j4 --optimized-fetch 2>&1 | tee -a "$LOG"
  rc=${PIPESTATUS[0]}
  [ "$rc" -eq 0 ] && break
  echo "[sync] attempt $attempt failed rc=$rc, retry in 30s" | tee -a "$LOG"
  sleep 30
done

{
  echo
  echo "== repo sync done rc=$rc"
  du -sh "$KB_SRC" 2>/dev/null
  df -h / | tail -1
  echo "== common HEAD: $(git -C "$KB_SRC/common" rev-parse HEAD 2>/dev/null)"
  echo "== kernel version:"
  sed -n '2,4p' "$KB_SRC/common/Makefile" 2>/dev/null
} | tee -a "$LOG"

echo "log: $LOG"
exit "$rc"