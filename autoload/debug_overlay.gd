extends Node
## 调试浮层 —— F3 开关。
##
## 用来回答「卡了是谁的锅」：帧时间涨了看 draw call，内存涨了看节点数。
## 自定义信息：DebugOverlay.watch("敌人数", enemies.size())，每帧覆盖，不用清。

var _layer: CanvasLayer
var _label: Label
var _watches: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	set_process(false)


func _input(event: InputEvent) -> void:
	# 用 _input 而不是 _unhandled_input：debug 开关不该被 UI 吃掉
	if event.is_action_pressed("debug_toggle"):
		_layer.visible = not _layer.visible
		set_process(_layer.visible)
		get_viewport().set_input_as_handled()


func watch(key: String, value: Variant) -> void:
	_watches[key] = value


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	var lines := [
		"FPS		%d" % Performance.get_monitor(Performance.TIME_FPS),
		"帧耗时		%.2f ms" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0),
		"Draw Call	%d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"节点数		%d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"内存		%s" % String.humanize_size(int(Performance.get_monitor(Performance.MEMORY_STATIC))),
		"场景		%s" % (scene.scene_file_path if scene != null else "-"),
	]
	for key in _watches:
		lines.append("%-10s %s" % [key, _watches[key]])
	_label.text = "\n".join(lines)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 95
	_layer.visible = false
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_label = Label.new()
	_label.position = Vector2(14, 10)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_font_size_override("font_size", 15)
	_layer.add_child(_label)
