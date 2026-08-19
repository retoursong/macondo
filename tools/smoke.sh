#!/usr/bin/env bash
# 冒烟测试：把每个入口场景真跑若干帧，任何 ERROR / SCRIPT ERROR 都算失败。
# verify 检查「零件在不在」，smoke 检查「跑起来会不会炸」。
# 新增了游戏场景记得加进 SCENES。
set -uo pipefail

GODOT="${GODOT:-godot}"
FRAMES="${FRAMES:-240}"

# 空串 = 走 project.godot 里配的主场景（即完整 boot → 主菜单 流程）
SCENES=("" "res://scenes/sandbox.tscn")

fail=0
for scene in "${SCENES[@]}"; do
    label="${scene:-<主场景 boot 流程>}"
    log="$(mktemp)"

    if [[ -z "$scene" ]]; then
        "$GODOT" --headless --quit-after "$FRAMES" >"$log" 2>&1
    else
        "$GODOT" --headless --quit-after "$FRAMES" "$scene" >"$log" 2>&1
    fi
    code=$?

    # 无头模式退出时必然出现的资源清理噪音，不是真问题
    bad=$(grep -E '^(SCRIPT )?ERROR:' "$log" \
          | grep -viE 'leaked at exit|RID allocations of type' || true)

    if [[ -n "$bad" ]]; then
        echo "[smoke] $label 运行期报错 ✗"
        echo "$bad" | sed 's/^/         /'
        fail=1
    elif [[ $code -ne 0 ]]; then
        echo "[smoke] $label 退出码 $code ✗"
        tail -15 "$log" | sed 's/^/         /'
        fail=1
    else
        echo "[smoke] $label 跑满 $FRAMES 帧无报错 ✓"
    fi
    rm -f "$log"
done

exit $fail
