#!/usr/bin/env bash
# 把插画从 PNG 转成 JPG（铜版画是高频排线，PNG 存它极浪费）。
# 新出的图默认还是 PNG，出完跑一次这个就行。风格锚点 art/_anchors 不动。
set -uo pipefail
P="$(cd "$(dirname "$0")/.." && pwd)"
Q=${Q:-90}
n=0
for d in scenes branch endings; do
  [[ -d "$P/art/$d" ]] || continue
  for f in "$P/art/$d"/*.png; do
    [[ -e "$f" ]] || continue
    out="${f%.png}.jpg"
    sips -s format jpeg -s formatOptions "$Q" "$f" --out "$out" >/dev/null 2>&1 || { echo "✗ $f"; continue; }
    rm -f "$f" "$f.import"
    n=$((n+1))
  done
done
echo "转了 $n 张，art 现在 $(du -sh "$P/art" | cut -f1)"
