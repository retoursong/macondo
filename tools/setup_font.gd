extends SceneTree
## 把中文字体设为项目默认字体。
##
## 跑：godot --headless --script tools/setup_font.gd
##
## 为什么必须做：Godot 内置字体只有拉丁/希腊/西里尔字形，一个汉字都没有。
## 不设这个，所有中文 UI 全是豆腐块 □□□。

const FONT_PATH := "res://assets/fonts/NotoSansSC-VF.ttf"

func _init() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		push_error("字体不存在: " + FONT_PATH)
		quit(1)
		return
	ProjectSettings.set_setting("gui/theme/custom_font", FONT_PATH)
	var err := ProjectSettings.save()
	if err != OK:
		push_error("写 project.godot 失败: " + error_string(err))
		quit(1)
		return
	print("[font] 默认字体已设为 ", FONT_PATH)
	quit(0)
