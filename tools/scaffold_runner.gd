extends Node
## 阶段2：用引擎自己的序列化器生成 .tscn，保证格式跟当前 Godot 版本严格一致。
##
## 跑：make scaffold
##
## 为什么不手写 .tscn：格式随版本变（4.7 给每个节点加了 unique_id），手写迟早对不上。
## 生成之后 .tscn 就是普通场景文件，正常在编辑器里改即可。
## 注意：重跑会覆盖你对这三个场景的手动修改。

func _ready() -> void:
	_build_boot()
	_build_main_menu()
	_build_sandbox()
	_build_story()
	_build_tool_scene("res://tools/verify_runner.gd", "res://tools/verify.tscn")
	_build_tool_scene("res://tools/playtest_runner.gd", "res://tools/playtest.tscn")
	print("[scaffold] 完成")
	get_tree().quit()


func _build_boot() -> void:
	var root := Node.new()
	root.name = "Boot"
	root.set_script(load("res://scenes/boot.gd"))
	_save(root, "res://scenes/boot.tscn")


func _build_main_menu() -> void:
	var root := Control.new()
	root.name = "MainMenu"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://scenes/main_menu.gd"))

	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.09, 0.10, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var box := VBoxContainer.new()
	box.name = "VBox"
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.name = "Title"
	title.text = "Godot Lab"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	box.add_child(title)

	var stats := Label.new()
	stats.name = "Stats"
	stats.text = "最高分 0   ·   已玩 0 局"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	box.add_child(stats)

	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.custom_minimum_size = Vector2(0, 24)
	box.add_child(spacer)

	var play := Button.new()
	play.name = "PlayButton"
	play.text = "开始"
	play.custom_minimum_size = Vector2(260, 48)
	box.add_child(play)

	var quit_button := Button.new()
	quit_button.name = "QuitButton"
	quit_button.text = "退出"
	quit_button.custom_minimum_size = Vector2(260, 48)
	box.add_child(quit_button)

	_save(root, "res://scenes/main_menu.tscn")


func _build_sandbox() -> void:
	var root := Node2D.new()
	root.name = "Sandbox"
	root.set_script(load("res://scenes/sandbox.gd"))
	_save(root, "res://scenes/sandbox.tscn")


func _build_story() -> void:
	var root := Control.new()
	root.name = "Story"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://scenes/story.gd"))
	_save(root, "res://scenes/story.tscn")


func _build_tool_scene(script_path: String, scene_path: String) -> void:
	## 给引用了 autoload 的工具脚本包壳 —— 只能在场景模式下做
	var root := Node.new()
	root.name = "ToolRunner"
	root.set_script(load(script_path))
	_save(root, scene_path)


func _save(root: Node, path: String) -> void:
	_claim(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack 失败 %s: %s" % [path, error_string(err)])
		root.free()
		return
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("save 失败 %s: %s" % [path, error_string(err)])
	else:
		print("  ✓ ", path)
	root.free()


func _claim(node: Node, scene_owner: Node) -> void:
	## 根之外每个节点都要认 owner，否则 pack 出来只剩根节点
	for child in node.get_children():
		child.owner = scene_owner
		_claim(child, scene_owner)
