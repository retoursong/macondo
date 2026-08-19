extends Node
## 自检 —— 以完整运行时（autoload 全在）跑一遍基建，任何一项不过就返回非 0。
##
## 跑：make check
##
## 这不是单元测试，是「地基有没有塌」的冒烟检查。改完基建先跑它。

var _failures: Array[String] = []


func _ready() -> void:
	_check_autoloads()
	_check_input_map()
	_check_scenes()
	_check_audio_buses()
	_check_save_roundtrip()
	_check_font()

	print("")
	if _failures.is_empty():
		print("[check] 全部通过 ✓")
		get_tree().quit(0)
	else:
		print("[check] %d 项失败 ✗" % _failures.size())
		for f in _failures:
			print("        - ", f)
		get_tree().quit(1)


func _ok(label: String) -> void:
	print("  ✓ ", label)


func _fail(label: String) -> void:
	print("  ✗ ", label)
	_failures.append(label)


func _expect(condition: bool, label: String) -> void:
	if condition:
		_ok(label)
	else:
		_fail(label)


# --- 各项检查 ---

func _check_autoloads() -> void:
	print("[autoload]")
	for name in ["EventBus", "GameState", "SaveSystem", "AudioMan",
			"SceneRouter", "PauseMenu", "DebugOverlay"]:
		_expect(get_tree().root.has_node(name), "%s 已注册" % name)


func _check_input_map() -> void:
	print("[输入映射]")
	# 光有 action 不够，要确认按键事件真的能匹配上（device 字段写错就会静默失效）
	var probes := {
		"move_left": KEY_A,
		"move_right": KEY_D,
		"move_up": KEY_W,
		"move_down": KEY_S,
		"action_primary": KEY_SPACE,
		"action_secondary": KEY_J,
		"pause": KEY_ESCAPE,
		"restart": KEY_R,
		"debug_toggle": KEY_F3,
	}
	for action in probes:
		if not InputMap.has_action(action):
			_fail("action 缺失: %s" % action)
			continue
		var ev := InputEventKey.new()
		ev.physical_keycode = probes[action]
		ev.pressed = true
		_expect(InputMap.event_is_action(ev, action),
				"%s 能被键盘事件触发" % action)


func _check_scenes() -> void:
	print("[场景]")
	var expected := {
		"res://scenes/boot.tscn": "res://scenes/boot.gd",
		"res://scenes/main_menu.tscn": "res://scenes/main_menu.gd",
		"res://scenes/sandbox.tscn": "res://scenes/sandbox.gd",
	}
	for scene_path in expected:
		if not ResourceLoader.exists(scene_path):
			_fail("场景不存在: %s" % scene_path)
			continue
		var packed: PackedScene = load(scene_path)
		if packed == null:
			_fail("场景加载失败: %s" % scene_path)
			continue
		var attached := _root_script_path(packed)
		_expect(attached == expected[scene_path],
				"%s 挂着 %s" % [scene_path.get_file(), expected[scene_path].get_file()])


func _root_script_path(packed: PackedScene) -> String:
	## 不实例化，直接读 PackedScene 里根节点的 script 属性
	var state := packed.get_state()
	if state.get_node_count() == 0:
		return ""
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) != "script":
			continue
		var value: Variant = state.get_node_property_value(0, i)
		return value.resource_path if value != null else ""
	return ""


func _check_audio_buses() -> void:
	print("[音频]")
	for bus_name in ["Master", "BGM", "SFX"]:
		_expect(AudioServer.get_bus_index(bus_name) != -1, "音频总线 %s 存在" % bus_name)


func _check_save_roundtrip() -> void:
	print("[存档]")
	var original: float = SaveSystem.settings.get("volume_sfx", 1.0)
	var probe_value := 0.4242
	SaveSystem.settings["volume_sfx"] = probe_value
	SaveSystem.save_settings()
	SaveSystem.load_settings()
	var read_back: float = SaveSystem.settings.get("volume_sfx", -1.0)
	_expect(is_equal_approx(read_back, probe_value), "设置写入后能读回")
	# 还原，别把自检的脏值留在用户设置里
	SaveSystem.settings["volume_sfx"] = original
	SaveSystem.save_settings()


func _check_font() -> void:
	print("[字体]")
	# Godot 内置字体一个汉字都没有，不挂中文字体的话 UI 全是豆腐块。
	# 这里量的是 Control 实际会用到的那个字体，不是配置项写了什么。
	var probe := Label.new()
	add_child(probe)
	var font: Font = probe.get_theme_font("font")
	var missing := ""
	for s in ["已", "暂", "停", "开", "始", "分", "数", "沙", "盒", "调", "试", "最", "高"]:
		if font == null or not font.has_char(s.unicode_at(0)):
			missing += s
	probe.queue_free()
	if missing.is_empty():
		_ok("UI 字体含中文字形")
	else:
		_fail("UI 字体缺中文字形: %s" % missing)
