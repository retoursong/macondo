extends SceneTree
## 输入映射生成器 —— 把按键配置写进 project.godot 的 [input] 段。
##
## 跑：godot --headless --script tools/setup_input.gd
##
## 为什么用脚本而不是手写 project.godot：InputEvent 在配置文件里是长长一串
## Object(InputEventKey,...) 序列化，字段随版本变，让引擎自己写才不会错。
## 生成之后正常在 项目设置 → 输入映射 里改就行。

const ACTIONS := {
	"move_left": [
		{"key": KEY_A}, {"key": KEY_LEFT},
		{"axis": JOY_AXIS_LEFT_X, "value": -1.0},
	],
	"move_right": [
		{"key": KEY_D}, {"key": KEY_RIGHT},
		{"axis": JOY_AXIS_LEFT_X, "value": 1.0},
	],
	"move_up": [
		{"key": KEY_W}, {"key": KEY_UP},
		{"axis": JOY_AXIS_LEFT_Y, "value": -1.0},
	],
	"move_down": [
		{"key": KEY_S}, {"key": KEY_DOWN},
		{"axis": JOY_AXIS_LEFT_Y, "value": 1.0},
	],
	"action_primary": [
		{"key": KEY_SPACE}, {"mouse": MOUSE_BUTTON_LEFT}, {"pad": JOY_BUTTON_A},
	],
	"action_secondary": [
		{"key": KEY_J}, {"mouse": MOUSE_BUTTON_RIGHT}, {"pad": JOY_BUTTON_X},
	],
	"pause": [
		{"key": KEY_ESCAPE}, {"pad": JOY_BUTTON_START},
	],
	"restart": [
		{"key": KEY_R}, {"pad": JOY_BUTTON_BACK},
	],
	"debug_toggle": [
		{"key": KEY_F3},
	],
}


func _init() -> void:
	for action_name in ACTIONS:
		var events: Array = []
		for spec in ACTIONS[action_name]:
			var ev := _make_event(spec)
			if ev != null:
				events.append(ev)
		ProjectSettings.set_setting("input/" + action_name, {
			"deadzone": 0.2,
			"events": events,
		})
		print("	 ✓ %s (%d 个绑定)" % [action_name, events.size()])

	var err := ProjectSettings.save()
	if err != OK:
		push_error("写 project.godot 失败: " + error_string(err))
	else:
		print("[input] 已写入 project.godot")
	quit()


func _make_event(spec: Dictionary) -> InputEvent:
	if spec.has("key"):
		var e := InputEventKey.new()
		# 用 physical_keycode：这样非 QWERTY 布局（比如法语 AZERTY）玩家的 WASD 还在原位
		e.physical_keycode = spec["key"]
		return e
	if spec.has("mouse"):
		var e := InputEventMouseButton.new()
		e.button_index = spec["mouse"]
		return e
	if spec.has("pad"):
		var e := InputEventJoypadButton.new()
		e.button_index = spec["pad"]
		return e
	if spec.has("axis"):
		var e := InputEventJoypadMotion.new()
		e.axis = spec["axis"]
		e.axis_value = spec["value"]
		return e
	push_warning("看不懂的绑定: %s" % spec)
	return null
