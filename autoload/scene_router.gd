extends Node
## 场景切换 —— 带淡入淡出，避免硬切的突兀感。
##
## 用法：SceneRouter.change_to(SceneRouter.MAIN_MENU)
##		SceneRouter.reload()		  # 重开当前场景
##
## 注意：切换是异步的（有淡出动画），所以它是 await 得起的：
##		await SceneRouter.change_to(...)

const BOOT := "res://scenes/boot.tscn"
const MAIN_MENU := "res://scenes/main_menu.tscn"
const SANDBOX := "res://scenes/sandbox.tscn"
const STORY := "res://scenes/story.tscn"

const FADE_TIME := 0.25

var _layer: CanvasLayer
var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_layer = CanvasLayer.new()
	_layer.layer = 100	# 盖在所有东西上面
	add_child(_layer)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.visible = false
	_layer.add_child(_fade)


func change_to(path: String) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_error("场景不存在: %s" % path)
		return

	_busy = true
	EventBus.scene_will_change.emit(path)

	await _fade_to(1.0)
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("切场景失败 %s: %s" % [path, error_string(err)])
	# 等一帧，让新场景的 _ready 跑完再淡入，否则会看到没初始化的画面
	await get_tree().process_frame
	await _fade_to(0.0)

	_busy = false
	EventBus.scene_changed.emit(path)


func reload() -> void:
	var current := get_tree().current_scene
	if current == null:
		return
	await change_to(current.scene_file_path)


func _fade_to(alpha: float) -> void:
	_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished
	_fade.visible = alpha > 0.0
