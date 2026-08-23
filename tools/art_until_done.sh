#!/usr/bin/env bash
# 把 art_jobs.tsv 里的图全部补齐：等在跑的批次结束，再扫几轮把漏的补上，最后导入 Godot。
set -uo pipefail
P="$(cd "$(dirname "$0")/.." && pwd)"
cd "$P"
while pgrep -f "gen_art.sh" | grep -qv $$ && pgrep -f "tools/gen_art.sh" >/dev/null; do sleep 20; done
for round in 1 2 3; do
  missing=0
  while IFS=$'\t' read -r name _ <&3; do
    [[ -z "${name:-}" ]] && continue
    [[ -f "art/scenes/$name.png" ]] || missing=$((missing+1))
  done 3< tools/art_jobs.tsv
  echo "第 $round 轮：还差 $missing 张"
  [[ $missing -eq 0 ]] && break
  ./tools/gen_art.sh 5
done
godot --headless --import >/dev/null 2>&1
echo "补齐完成：$(ls art/scenes/*.png | wc -l | tr -d ' ') 张，已导入"
