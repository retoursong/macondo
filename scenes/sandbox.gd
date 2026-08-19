extends Node2D
## 沙盒 —— 游戏本体从这里开始长。
##
## 现在这里只有一段说明文字和一个能动的方块，用来证明输入/暂停/调试浮层都通了。
## 等定了题材，把 _spawn_probe() 删掉，换成真正的玩法。

const SPEED := 420.0

var _probe: ColorRect


func _ready() -> void:
	PauseMenu.enabled = true
	GameState.start_run()
	_spawn_probe()


func _process(delta: float) -> void:
	# Input.get_vector 自带死区和归一化，比自己写四个 if 稳
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_probe.position += dir * SPEED * delta

	if Input.is_action_just_pressed("action_primary"):
		GameState.score += 1

	DebugOverlay.watch("方块位置", _probe.position.round())


func _spawn_probe() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var hint := Label.new()
	hint.position = Vector2(40, 40)
	hint.add_theme_font_size_override("font_size", 18)
	hint.text = "沙盒场景 —— 游戏从这里开始长\n\n"
	hint.text += "WASD / 方向键 / 左摇杆：移动方块\n"
	hint.text += "空格 / 鼠标左键：加分\n"
	hint.text += "Esc：暂停菜单\n"
	hint.text += "F3：调试浮层"
	layer.add_child(hint)

	var score_label := Label.new()
	score_label.position = Vector2(40, 200)
	score_label.add_theme_font_size_override("font_size", 24)
	layer.add_child(score_label)
	score_label.text = "分数 0"
	EventBus.score_changed.connect(
		func(value: int) -> void: score_label.text = "分数 %d" % value
	)

	_probe = ColorRect.new()
	_probe.color = Color(0.35, 0.75, 1.0)
	_probe.size = Vector2(56, 56)
	_probe.position = Vector2(612, 332)
	layer.add_child(_probe)
