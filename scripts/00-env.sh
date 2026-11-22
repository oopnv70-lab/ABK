#!/usr/bin/env bash
# 载入方式：source /root/pkg110-kernel/scripts/00-env.sh
# 所有路径与可调参数集中在这里，其它脚本不允许硬编码路径。

export KB_ROOT="/root/pkg110-kernel"
export KB_SRC="$KB_ROOT/src/ack"
export KB_OUT="$KB_ROOT/out"
export KB_DIST="$KB_ROOT/dist"
export KB_LOGS="$KB_ROOT/logs/build"
export KB_ART="$KB_ROOT/artifacts"

# —— 构建目标参数 ——
# 分支改动只改这一行；manifest 分支名带 common- 前缀，由脚本自动补
export KB_ACK_BRANCH="android14-6.1-2025-09"     # 对应 6.1.145
export KB_MANIFEST_URL="https://android.googlesource.com/kernel/manifest"
export KB_REPO_URL="https://github.com/GerritCodeReview/git-repo"
export KB_TARGET="//common:kernel_aarch64_dist"  # GKI aarch64 dist
export KB_JOBS="4"                               # 内存受限，勿贪高
export KB_MANIFEST_BRANCH="common-${KB_ACK_BRANCH}"

# ccache：二次构建省时间
export CCACHE_DIR="$KB_ROOT/.ccache"
export CCACHE_MAXSIZE="6G"
export USE_CCACHE=1

# 让 Kleaf 找到本地 bazel（repo sync 后由 prebuilts 提供）
export PATH="$KB_ROOT/src/ack/prebuilts/bazel/linux-x86_64:$PATH"

ulimit -n 8192 2>/dev/null

kb_logname() {
  # 用法：kb_logname build  →  build-20261122-090000.log
  local tag="${1:-build}"
  echo "$KB_LOGS/${tag}-$(date +%Y%m%d-%H%M%S).log"
}

kb_stamp() {
  # 把源码状态写进日志头，保证任何产物可回溯
  echo "== workspace: $KB_ROOT"
  echo "== ack branch: $KB_ACK_BRANCH"
  echo "== date: $(date -u +%FT%TZ)"
  if [ -d "$KB_SRC/common/.git" ]; then
    echo "== common HEAD: $(git -C "$KB_SRC/common" rev-parse HEAD 2>/dev/null)"
    echo "== common describe: $(git -C "$KB_SRC/common" describe --always --dirty 2>/dev/null)"
  else
    echo "== common HEAD: (not synced)"
  fi
  echo "== disk: $(df -h / | tail -1)"
  echo "== jobs: $KB_JOBS"
  echo
}