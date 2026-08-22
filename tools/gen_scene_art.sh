#!/usr/bin/env bash
# 批量出场景插画。每张都带 style_anchor.png 做参考，保证画风一致。
# codex 干完活之后有时会挂住不退出，所以每张都设了硬超时——
# 图落盘了就算成功，进程卡住不影响。
set -uo pipefail
P="$(cd "$(dirname "$0")/.." && pwd)"
CODEX=/Applications/ChatGPT.app/Contents/Resources/codex
ANCHOR="$P/art/_anchors/style_anchor.png"
PER_IMAGE_TIMEOUT=${PER_IMAGE_TIMEOUT:-420}

STYLE='严格复制锚点图的画风：十九世纪铜版雕刻插图，密集交叉排线(crosshatching)，暖褐色单色调(sepia)，明暗全靠排线密度，线条精确，古籍插图质感。不要彩色，不要照片写实，不要数字光滑感，无文字，无水印。横构图 landscape 16:9。'

gen() {  # $1=输出名  $2=画面描述
  local out="$P/art/scenes/$1.png"
  if [[ -f "$out" ]]; then echo "  跳过（已存在） $1"; return 0; fi
  echo "  ▸ 生成 $1 ..."
  "$CODEX" exec --skip-git-repo-check -s workspace-write -C "$P" \
    "调用内置 image_gen 工具生成一张图。referenced_image_paths 传入这个绝对路径作为风格锚点：$ANCHOR

画面内容：$2

画风：$STYLE

生成后用 shell 把图复制到 $out。不要问我任何问题。" >/dev/null 2>&1 &
  local pid=$!
  local waited=0
  while kill -0 $pid 2>/dev/null && [[ $waited -lt $PER_IMAGE_TIMEOUT ]]; do
    if [[ -f "$out" ]]; then break; fi
    sleep 5; waited=$((waited+5))
  done
  # 图到手就把 codex 干掉，它经常干完不退
  sleep 3
  kill -9 $pid 2>/dev/null
  wait $pid 2>/dev/null
  [[ -f "$out" ]] && echo "     ✓ $1 ($(du -h "$out" | cut -f1))" || echo "     ✗ $1 超时未生成"
}

gen ch01_s02_astrolabe "一八四〇年代哥伦比亚村庄里一间简陋小屋。一个高大结实、胡须凌乱的中年男人站在木桌前，桌上摊满星盘、六分仪、罗盘和航海图，墙上钉着潦草的天文草图。他神情狂喜地举起一张图纸对着窗光。门口站着一个身材娇小、神色严厉的女人，双手叉腰盯着他。窗外是泥巴屋和河岸。人物在中右，左侧留出窗和光。"
gen ch01_s03_melquiades "一八四〇年代一间昏暗的炼金实验室内部。一个身形肥大、胡须蓬乱、戴黑色大礼帽的吉卜赛老人坐在木凳上，面容枯槁、牙齿掉光、裹在破旧斗篷里，神情疲惫而深不可测。一个高大的中年男人俯身倾听他说话。四周是蒸馏瓶、陶罐、坩埚和木架。一束斜光从高窗射入，光柱里浮着尘埃。"
gen ch01_s04_gold "一八四〇年代一间炼金实验室。一口架在炭炉上的大锅正在熬煮，浓烟翻滚。一个高大的中年男人俯身盯着锅底，神情懊丧；锅底是一坨焦黑碳化的残渣。旁边站着一个娇小严厉的女人，双臂抱在胸前看着他。四周散落坩埚、风箱、陶罐。"
