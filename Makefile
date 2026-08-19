# Godot Lab —— 常用命令。跑 `make` 看列表。
GODOT ?= godot

.PHONY: help run editor check smoke test scaffold input font clean

help:
	@echo "make run       启动游戏"
	@echo "make editor    打开 Godot 编辑器"
	@echo "make check     自检：autoload/输入/场景/音频/存档 是否完好"
	@echo "make smoke     冒烟：真跑 240 帧，有任何报错就失败"
	@echo "make test      check + smoke"
	@echo "make scaffold  重新生成 scenes/*.tscn（会覆盖你的手动改动！）"
	@echo "make input     重新生成输入映射到 project.godot"
	@echo "make font      重新把中文字体设为项目默认字体"
	@echo "make clean     清掉 .godot 导入缓存"

run:
	$(GODOT)

editor:
	$(GODOT) --editor

check:
	$(GODOT) --headless res://tools/verify.tscn

smoke:
	GODOT=$(GODOT) ./tools/smoke.sh

test: check smoke

scaffold:
	$(GODOT) --headless --script tools/make_tool_scenes.gd
	$(GODOT) --headless res://tools/scaffold.tscn

input:
	$(GODOT) --headless --script tools/setup_input.gd

font:
	$(GODOT) --headless --script tools/setup_font.gd

clean:
	rm -rf .godot
