# Godot Lab —— 常用命令。跑 `make` 看列表。
GODOT ?= godot

.PHONY: help run editor import check smoke test playtest scaffold input font clean

help:
	echo "make run       启动游戏"
	echo "make editor    打开 Godot 编辑器"
	echo "make check     自检：autoload/输入/场景/音频/存档/字体 是否完好"
	echo "make smoke     冒烟：每个入口场景真跑 240 帧，有任何报错就失败"
	echo "make test      check + smoke"
	echo "make import    导入资源（新克隆仓库后的第一步，check/smoke 会自动调）"
	echo "make scaffold  重新生成 scenes/*.tscn（会覆盖你的手动改动！）"
	echo "make input     重新生成输入映射到 project.godot"
	echo "make font      重新把中文字体设为项目默认字体"
	echo "make clean     清掉 .godot 导入缓存"

# .godot 是导入缓存，不进版本库。缺了的话字体等资源加载不出来，
# 所以下面用 order-only 依赖（| .godot）保证它存在——已存在时不会重复跑。
.godot:
	$(GODOT) --headless --import

import:
	$(GODOT) --headless --import

run: | .godot
	$(GODOT)

editor:
	$(GODOT) --editor

check: | .godot
	$(GODOT) --headless res://tools/verify.tscn

smoke: | .godot
	GODOT=$(GODOT) ./tools/smoke.sh

test: check smoke

playtest: | .godot
	$(GODOT) --headless res://tools/playtest.tscn

scaffold: | .godot
	$(GODOT) --headless --script tools/make_tool_scenes.gd
	$(GODOT) --headless res://tools/scaffold.tscn

input:
	$(GODOT) --headless --script tools/setup_input.gd

font: | .godot
	$(GODOT) --headless --script tools/setup_font.gd

clean:
	rm -rf .godot
