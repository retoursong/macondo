#!/usr/bin/env bash
# 按 tools/art_jobs.tsv 批量出插画，多条流水线并行。
# 每张都带 style_anchor.png 做风格锚点。codex 干完常挂住不退，所以图落盘就杀掉。
# 跑：./tools/gen_art.sh [并行数]
set -uo pipefail
P="$(cd "$(dirname "$0")/.." && pwd)"
CODEX=/Applications/ChatGPT.app/Contents/Resources/codex
ANCHOR="$P/art/_anchors/style_anchor.png"
JOBS="${JOBS:-$P/tools/art_jobs.tsv}"
LANES=${1:-6}
PER_IMAGE_TIMEOUT=${PER_IMAGE_TIMEOUT:-900}

STYLE='严格复制锚点图的画风：十九世纪铜版雕刻插图，密集交叉排线(crosshatching)，暖褐色单色调(sepia)，明暗全靠排线密度，线条精确，古籍插图质感。不要彩色，不要照片写实，不要数字光滑感，无文字，无水印。横构图 landscape 16:9。'

one() {  # $1=图名 $2=画面描述
  local out="$P/art/scenes/$1.png"
  [[ -f "$out" ]] && { echo "  跳过 $1"; return 0; }
  echo "  ▸ $1"
  "$CODEX" exec --skip-git-repo-check -s workspace-write -C "$P" \
    "调用内置 image_gen 工具生成一张图。referenced_image_paths 传入这个绝对路径作为风格锚点：$ANCHOR

画面内容：$2

画风：$STYLE

生成后用 shell 把图复制到 ${out} 这个路径。不要问我任何问题。" </dev/null >/dev/null 2>&1 &
  local pid=$!
  local waited=0
  while kill -0 $pid 2>/dev/null && [[ $waited -lt $PER_IMAGE_TIMEOUT ]]; do
    [[ -f "$out" ]] && break
    sleep 5; waited=$((waited+5))
  done
  sleep 3
  kill -9 $pid 2>/dev/null
  wait $pid 2>/dev/null
  [[ -f "$out" ]] && echo "     ✓ $1" || echo "     ✗ $1 超时"
}

n=0
while IFS=$'\t' read -r name prompt <&3; do
  [[ -z "${name:-}" ]] && continue
  one "$name" "$prompt" &
  n=$((n+1))
  if (( n % LANES == 0 )); then wait; fi
done 3< "$JOBS"
wait
echo "全部完成：$(ls "$P/art/scenes"/*.png | wc -l | tr -d ' ') 张"
