extends Control
## 故事播放器 —— 第一章。
##
## 铁律：原文 = 剧本，固定播出，是权威。AI = 只回应你的自由输入。
## 两者在视觉上必须分得开，你要永远知道哪句是马尔克斯写的。
##	 原文 → 暖白、大字号
##	 AI	 → 冷蓝、小字号、带说话人名字

const SCENES_PATH := "res://data/scenes_ch01.json"
const CHARS_PATH := "res://data/characters.json"

## 第一章你扮演谁。他在每一场都在场，是本章的主角。
const POV := "何塞·阿尔卡蒂奥·布恩迪亚"

const C_BG		  := Color("1a1512")
const C_NARRATION := Color("e8ddd0")
const C_DIM		  := Color("8a7f72")
const C_SPEAKER	  := Color("d9a441")
const C_AI		  := Color("9fc4d8")
const C_YOU		  := Color("b8b0a4")
const C_ERR		  := Color("d97a6c")

var _scenes: Array = []
var _chars: Dictionary = {}
var _rules: Array = []

var _index: int = 0
var _target: String = ""
var _history: Dictionary = {}	# 角色名 -> 本场对话历史（换场清空）
var _busy: bool = false

var _title: Label
var _place: Label
var _narration: RichTextLabel
var _log: RichTextLabel
var _cast_row: HBoxContainer
var _input: LineEdit
var _send_button: Button
var _next_button: Button
var _status: Label


func _ready() -> void:
	PauseMenu.enabled = true
	if not _load_data():
		return
	_build_ui()
	_show_scene(0)


# ---------- 数据 ----------

func _load_data() -> bool:
	var s: Variant = _read_json(SCENES_PATH)
	var c: Variant = _read_json(CHARS_PATH)
	if s == null or c == null:
		return false
	_scenes = s.get("scenes", [])
	_chars = c.get("characters", {})
	_rules = c.get("_shared_rules", [])
	if _scenes.is_empty():
		push_error("scenes_ch01.json 里没有场景")
		return false
	return true


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("找不到 %s（先跑 tools/cut_scenes.py）" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("%s 不是合法 JSON" % path)
		return null
	return parsed


# ---------- 放场景 ----------

func _show_scene(index: int) -> void:
	_index = clampi(index, 0, _scenes.size() - 1)
	var scene: Dictionary = _scenes[_index]

	_history.clear()
	_target = ""
	_log.clear()

	_title.text = "%d / %d	 %s" % [_index + 1, _scenes.size(), scene.get("title", "")]
	_place.text = String(scene.get("place", ""))

	# 原文原样播出，一字不改
	_narration.clear()
	_narration.push_color(C_NARRATION)
	_narration.push_font_size(19)
	for para in scene.get("narration", []):
		_narration.append_text(String(para) + "\n\n")
	_narration.pop()
	_narration.pop()
	_narration.scroll_to_line(0)

	_build_cast_buttons(scene)
	_refresh_input_state()

	var last := _index >= _scenes.size() - 1
	_next_button.text = "第一章完" if last else "继续 →"
	_next_button.disabled = last


func _build_cast_buttons(scene: Dictionary) -> void:
	for child in _cast_row.get_children():
		child.queue_free()

	var others: Array = []
	for name in scene.get("cast", []):
		if String(name) != POV and _chars.has(name):
			others.append(String(name))

	if others.is_empty():
		var hint := Label.new()
		hint.text = "（这一段只有你自己）"
		hint.add_theme_color_override("font_color", C_DIM)
		_cast_row.add_child(hint)
		return

	var label := Label.new()
	label.text = "对谁说："
	label.add_theme_color_override("font_color", C_DIM)
	_cast_row.add_child(label)

	for name in others:
		var b := Button.new()
		b.text = "%s（%s）" % [name, _chars[name].get("short", "")]
		b.toggle_mode = true
		b.pressed.connect(_on_cast_selected.bind(name))
		_cast_row.add_child(b)

	_target = others[0]
	(_cast_row.get_child(1) as Button).button_pressed = true


func _on_cast_selected(name: String) -> void:
	_target = name
	for child in _cast_row.get_children():
		if child is Button:
			(child as Button).button_pressed = (child as Button).text.begins_with(name)
	_refresh_input_state()


# ---------- 说话 ----------

func _on_send() -> void:
	var said := _input.text.strip_edges()
	if said.is_empty() or _target.is_empty() or _busy:
		return
	_input.text = ""
	_busy = true
	_refresh_input_state()

	_log.push_color(C_YOU)
	_log.append_text("\n你（%s）：%s\n" % [POV, said])
	_log.pop()

	_status.text = "……%s在想" % _target
	_status.add_theme_color_override("font_color", C_DIM)

	var msgs := _build_messages(_target, said)
	var res: Dictionary = await LLM.chat(msgs)

	if res["ok"]:
		var reply: String = res["text"]
		_remember(_target, said, reply)
		_log.push_color(C_SPEAKER)
		_log.append_text("\n%s：" % _target)
		_log.pop()
		_log.push_color(C_AI)
		_log.append_text(reply + "\n")
		_log.pop()
		_status.text = ""
	else:
		_log.push_color(C_ERR)
		_log.append_text("\n[ 说不出话：%s ]\n" % res["error"])
		_log.pop()
		_status.text = ""

	_busy = false
	_refresh_input_state()
	_input.grab_focus()


func _build_messages(who: String, said: String) -> Array:
	var card: Dictionary = _chars[who]
	var scene: Dictionary = _scenes[_index]

	# 把本场原文整段喂进去 —— 模型不用靠记忆，就不会半记半编
	var sys := "你在扮演《百年孤独》里的%s。\n\n【你是谁】\n%s\n\n【你怎么说话】\n%s\n\n" % [
		who,
		"\n".join(PackedStringArray(card.get("brief", []))),
		String(card.get("voice", "")),
	]
	sys += "【此刻】\n地点：%s。下面是描写此刻情形的原文，一切以它为准，不要脑补原文里没有的事：\n\n%s\n\n" % [
		String(scene.get("place", "")),
		"\n".join(PackedStringArray(scene.get("narration", []))),
	]
	sys += "【硬规则】\n"
	for i in _rules.size():
		sys += "%d. %s\n" % [i + 1, String(_rules[i])]
	sys += "\n跟你说话的是%s。" % POV

	var msgs: Array = [{"role": "system", "content": sys}]
	for turn in _history.get(who, []):
		msgs.append({"role": "user", "content": "（%s说）%s" % [POV, turn["said"]]})
		msgs.append({"role": "assistant", "content": turn["reply"]})
	msgs.append({"role": "user", "content": "（%s说）%s" % [POV, said]})
	return msgs


func _remember(who: String, said: String, reply: String) -> void:
	if not _history.has(who):
		_history[who] = []
	_history[who].append({"said": said, "reply": reply})


# ---------- UI ----------

func _refresh_input_state() -> void:
	var can := not _busy and not _target.is_empty() and LLM.has_key()
	_input.editable = can
	_send_button.disabled = not can
	if not LLM.has_key():
		_input.placeholder_text = "没配 ARK_API_KEY —— 设环境变量，或在项目根建 .ark_key 文件"
	elif _target.is_empty():
		_input.placeholder_text = "这一段没有人可以说话，直接继续"
	else:
		_input.placeholder_text = "对%s说点什么……（说什么都不会改变故事的走向）" % _target


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	_title = Label.new()
	_title.add_theme_color_override("font_color", C_SPEAKER)
	_title.add_theme_font_size_override("font_size", 17)
	head.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_place = Label.new()
	_place.add_theme_color_override("font_color", C_DIM)
	head.add_child(_place)

	col.add_child(HSeparator.new())

	# 原文
	_narration = RichTextLabel.new()
	_narration.bbcode_enabled = true
	_narration.fit_content = false
	_narration.scroll_active = true
	_narration.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_narration.add_theme_constant_override("line_separation", 7)
	col.add_child(_narration)

	# AI 对话记录
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_active = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(0, 190)
	_log.add_theme_font_size_override("normal_font_size", 15)
	_log.add_theme_constant_override("line_separation", 4)
	col.add_child(_log)

	_cast_row = HBoxContainer.new()
	_cast_row.add_theme_constant_override("separation", 8)
	col.add_child(_cast_row)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_input = LineEdit.new()
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(func(_t: String) -> void: _on_send())
	row.add_child(_input)
	_send_button = Button.new()
	_send_button.text = "说"
	_send_button.custom_minimum_size = Vector2(80, 0)
	_send_button.pressed.connect(_on_send)
	row.add_child(_send_button)

	var foot := HBoxContainer.new()
	col.add_child(foot)
	_status = Label.new()
	_status.add_theme_color_override("font_color", C_DIM)
	foot.add_child(_status)
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer2)
	_next_button = Button.new()
	_next_button.custom_minimum_size = Vector2(140, 40)
	_next_button.pressed.connect(func() -> void: _show_scene(_index + 1))
	foot.add_child(_next_button)
