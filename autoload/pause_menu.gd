extends Node
## 全局暂停菜单 —— 按 Esc 触发，UI 全部在代码里生成（不依赖 .tscn）。
##
## 想在某个场景禁掉暂停（比如主菜单里按 Esc 不该弹）：
##	 PauseMenu.enabled = false
##
## 这里故意不做得太漂亮：等你定了美术风格再换皮，现在能用就行。

var enabled: bool = true

var _layer: CanvasLayer
var _dim: ColorRect
var _is_open: bool = false


func _ready() -> void:
	# 暂停时整棵树都停了，这个菜单必须还能动，否则按 Esc 就再也出不来
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if not enabled and not _is_open:
		return
	get_viewport().set_input_as_handled()
	toggle()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_layer.visible = true
	get_tree().paused = true


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_layer.visible = false
	get_tree().paused = false


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	_layer.visible = false
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.65)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "已暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)

	_add_button(box, "继续", close)
	_add_button(box, "重开本场景", _on_restart)
	_add_button(box, "回主菜单", _on_main_menu)
	_add_button(box, "退出游戏", _on_quit)


func _add_button(parent: Node, text: String, handler: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 44)
	b.pressed.connect(handler)
	parent.add_child(b)


func _on_restart() -> void:
	close()
	SceneRouter.reload()


func _on_main_menu() -> void:
	close()
	SceneRouter.change_to(SceneRouter.MAIN_MENU)


func _on_quit() -> void:
	get_tree().quit()
